#!/usr/bin/env bash
set -o pipefail

# Xiaomi Pad 8 Pro (piano) TWRP recovery auto-builder
# Handles ONLY the transient failures we've already observed:
#   1) stale recovery packaging / ODM symlink rsync code 23
#   2) malformed generated Ninja metadata
#   3) missing Soong temp directory (out/soong/.temp)
#   4) stale .module_paths
#
# The module-path cache is never deleted; it is moved aside with a timestamp so
# that a corrupt cache stays available for diagnosis.
#
# Unknown failures stop immediately so real source errors are not hidden.

TWRP_ROOT="${TWRP_ROOT:-$HOME/android/twrp-14}"
DEVICE_DIR="${DEVICE_DIR:-$TWRP_ROOT/device/xiaomi/piano}"
PRODUCT="${PRODUCT:-twrp_piano}"
LUNCH_TARGET="${LUNCH_TARGET:-twrp_piano-ap2a-eng}"
JOBS="${JOBS:-4}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-5}"
BUILD_ARCHIVE="${BUILD_ARCHIVE:-$HOME/android/piano-builds}"
PRE_CLEAN_RECOVERY="${PRE_CLEAN_RECOVERY:-1}"

OUT="$TWRP_ROOT/out"
PRODUCT_OUT="$OUT/target/product/piano"
RECOVERY_IMG="$PRODUCT_OUT/recovery.img"
LOG_DIR="$OUT/piano-build-logs"

mkdir -p "$LOG_DIR" "$BUILD_ARCHIVE"

say() {
    printf '\n\033[1;36m[piano-build]\033[0m %s\n' "$*"
}

warn() {
    printf '\n\033[1;33m[piano-build]\033[0m %s\n' "$*" >&2
}

die() {
    printf '\n\033[1;31m[piano-build]\033[0m %s\n' "$*" >&2
    exit 1
}

cleanup_recovery_packaging() {
    say "Cleaning stale recovery packaging output only..."
    rm -rf \
        "$PRODUCT_OUT/recovery" \
        "$PRODUCT_OUT/obj/PACKAGING/recovery_intermediates"
}

retire_module_paths() {
    if [[ -d "$OUT/.module_paths" ]]; then
        local retired="$OUT/.module_paths.bad-$(date +%Y%m%d-%H%M%S)"
        say "Retiring module-path cache for evidence: $retired"
        mv "$OUT/.module_paths" "$retired"
    fi
}

ensure_soong_temp_dir() {
    say "Recreating Soong temporary directory only: $OUT/soong/.temp"
    mkdir -p "$OUT/soong/.temp"
    chmod 0755 "$OUT/soong/.temp"
}

cleanup_light_ninja_metadata() {
    say "Cleaning lightweight generated Ninja metadata..."
    retire_module_paths
    rm -f \
        "$OUT/build-${PRODUCT}.ninja" \
        "$OUT/build-${PRODUCT}.ninja.d"
}

cleanup_soong_metadata() {
    warn "Repeated generated-Ninja corruption detected."
    warn "Removing out/soong and lightweight Ninja metadata; compiled target output is preserved."
    retire_module_paths
    rm -rf "$OUT/soong"
    rm -f \
        "$OUT/build-${PRODUCT}.ninja" \
        "$OUT/build-${PRODUCT}.ninja.d"
}

show_source_state() {
    say "Device-tree state"
    (
        cd "$DEVICE_DIR" || exit 1
        printf 'HEAD: '
        git rev-parse --short HEAD 2>/dev/null || true
        git status --short || true
        git diff --check || die "git diff --check failed"
    )
}

archive_success() {
    local stamp hash dest manifest
    stamp="$(date +%Y%m%d-%H%M%S)"
    dest="$BUILD_ARCHIVE/recovery-piano-${stamp}.img"
    manifest="$BUILD_ARCHIVE/recovery-piano-${stamp}.txt"

    cp -f "$RECOVERY_IMG" "$dest"
    hash="$(sha256sum "$dest" | awk '{print $1}')"

    {
        echo "device=piano"
        echo "product=$PRODUCT"
        echo "lunch_target=$LUNCH_TARGET"
        echo "timestamp=$stamp"
        echo "image=$dest"
        echo "sha256=$hash"
        echo
        echo "[git]"
        git -C "$DEVICE_DIR" rev-parse HEAD 2>/dev/null || true
        git -C "$DEVICE_DIR" status --short 2>/dev/null || true
    } > "$manifest"

    say "BUILD SUCCESS"
    echo "Image:    $RECOVERY_IMG"
    echo "Archived: $dest"
    echo "SHA-256:  $hash"
    echo "Manifest: $manifest"
}

[[ -d "$TWRP_ROOT/build" ]] || die "TWRP root not found: $TWRP_ROOT"
[[ -d "$DEVICE_DIR" ]] || die "Device tree not found: $DEVICE_DIR"

cd "$TWRP_ROOT" || die "Cannot cd to $TWRP_ROOT"

# envsetup/lunch expect some Android variables to be unset.
# Temporarily disable nounset while initializing the Android build environment.
set +u

# envsetup defines the Android 'm' shell function.
# shellcheck disable=SC1091
source build/envsetup.sh || die "Failed to source build/envsetup.sh"
export ALLOW_MISSING_DEPENDENCIES=true

show_source_state

# Module discovery runs inside lunch. A corrupt module-path cache makes it
# fail here, before the build retry loop is ever reached, so retry it too:
# retire the cache and try again. Each regeneration is a fresh walk.
lunch_attempt=1
# NOTE: must not pipe lunch into tee. A pipeline runs lunch in a subshell
# and every variable it exports (TARGET_PRODUCT, TARGET_RELEASE, ...) is
# then lost, which makes the build fail with "No release config set".
until lunch "$LUNCH_TARGET" > "$LOG_DIR/lunch-${lunch_attempt}.log" 2>&1; do
    cat "$LOG_DIR/lunch-${lunch_attempt}.log"
    # Module discovery fails in two shapes on an unhealthy host: a clean
    # "Could not create module-finder" lstat error, or a Go panic inside
    # soong/finder while walking or serializing the cache. Retry both.
    if ! grep -Eq "Could not create module-finder|soong/finder|finder\\.go:" \
            "$LOG_DIR/lunch-${lunch_attempt}.log"; then
        die "Lunch failed for a reason unrelated to module discovery"
    fi
    if (( lunch_attempt >= MAX_ATTEMPTS )); then
        die "Module discovery failed $MAX_ATTEMPTS times; the build host is not producing a usable module cache"
    fi
    warn "Module-finder failure during lunch (attempt $lunch_attempt); retiring cache and retrying."
    retire_module_paths
    lunch_attempt=$((lunch_attempt + 1))
done
say "Lunched $LUNCH_TARGET after $lunch_attempt attempt(s)"


# This cleanup is cheap and prevents the recurring ODM directory-vs-symlink
# packaging conflict without wiping compiled output.
if [[ "$PRE_CLEAN_RECOVERY" == "1" ]]; then
    cleanup_recovery_packaging
fi

attempt=1
ninja_corruptions=0

while (( attempt <= MAX_ATTEMPTS )); do
    log="$LOG_DIR/recovery-attempt-${attempt}-$(date +%Y%m%d-%H%M%S).log"

    say "Attempt $attempt/$MAX_ATTEMPTS: m recoveryimage -j$JOBS"
    say "Log: $log"

    set +e
    m recoveryimage "-j$JOBS" 2>&1 | tee "$log"
    rc=${PIPESTATUS[0]}

    if (( rc == 0 )); then
        [[ -s "$RECOVERY_IMG" ]] || die "Build returned success but recovery.img is missing/empty"
        archive_success
        exit 0
    fi

    # Known failure #1:
    # stale recovery packaging contains real ODM directories where the next
    # packaging pass expects symlinks.
    if grep -Eq \
        'could not make way for new symlink: root/odm/(bin|etc|firmware|lib64)|rsync error: .*code 23' \
        "$log"; then
        warn "Recognized stale recovery packaging failure."
        cleanup_recovery_packaging
        attempt=$((attempt + 1))
        continue
    fi

    # Known failure #2:
    # generated Ninja file contains malformed tokens / garbage bytes.
    if grep -Eq \
        'ninja: out/.*\.ninja:[0-9]+: expected (rule name|variable name)|expected (rule name|variable name)' \
        "$log"; then
        ninja_corruptions=$((ninja_corruptions + 1))
        warn "Recognized generated Ninja corruption (#$ninja_corruptions)."

        if (( ninja_corruptions == 1 )); then
            warn "First occurrence: retrying unchanged; these have cleared on rerun before."
        elif (( ninja_corruptions == 2 )); then
            cleanup_light_ninja_metadata
        else
            cleanup_soong_metadata
        fi

        attempt=$((attempt + 1))
        continue
    fi

    # Known failure #3:
    # Soong's temporary directory vanished underneath the build.
    # This is NOT .module_paths corruption: recreate out/soong/.temp only.
    if grep -Eq \
        'failed to open temporary raw file: open .*out/soong/\.temp/raw[^ ]*: no such file or directory' \
        "$log"; then
        warn "Recognized missing Soong temp directory."
        ensure_soong_temp_dir
        attempt=$((attempt + 1))
        continue
    fi

    # Known failure #4:
    # module path cache truncation/staleness.
    # "Could not create module-finder" is the lstat failure Finder raises when
    # a cached pathname is corrupt. It never mentions module_paths, so it must
    # be matched explicitly or the cache is never retired.
    if grep -Eq 'Could not create module-finder' "$log" ||
       (grep -Eq '\.module_paths|module_paths' "$log" &&
        grep -Eqi 'truncat|corrupt|unexpected|failed|error' "$log"); then
        warn "Recognized .module_paths failure."
        retire_module_paths
        attempt=$((attempt + 1))
        continue
    fi

    warn "Unknown build failure. Automatic recovery stopped."
    echo
    echo "Last log: $log"
    echo
    echo "Tail:"
    tail -80 "$log"
    exit "$rc"
done

die "Exceeded MAX_ATTEMPTS=$MAX_ATTEMPTS. Check logs in $LOG_DIR"
