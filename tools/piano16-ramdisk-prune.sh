#!/bin/bash
#
# Remove proven-dead payload from the recovery ramdisk staging directory.
#
# Invoked from BOARD_RECOVERY_IMAGE_PREPARE, which runs as the last step of the
# INTERNAL_RECOVERY_RAMDISK_FILES_TIMESTAMP recipe in build/make/core/Makefile
# — after every module has been installed into $(TARGET_RECOVERY_ROOT_OUT) and
# after ramdisk-files.txt / ramdisk-files.sha256sum have been generated. Both
# manifests are therefore regenerated here, using the same commands the build
# uses, so they continue to describe the ramdisk that is actually packed.
#
# Why this exists: piano's bootloader refuses any recovery whose compressed
# ramdisk exceeds a measured bound of ~29.21 MB (bracketed by seven controlled
# flashes: boots at 29,210,310 bytes, fails at 29,228,841). Enabling crypto
# needs roughly 3 MB that the image does not have. Compression cannot supply it
# — the bootloader accepts only legacy LZ4, proven by a gzip image that
# bootlooped at the splash screen.
#
# Removal criteria. A file is pruned only when all three hold:
#
#   1. No ELF in the ramdisk lists it in DT_NEEDED.
#   2. No file in the ramdisk contains its soname as a string, so it cannot be
#      reached by dlopen either.
#   3. No process had it mapped on a booted image (checked against /proc/*/maps
#      on hardware).
#
# The ELF closure gate (piano16-elf-closure-audit.py) runs after this script on
# the packed image and fails the build if a pruned file was in fact needed.

set -euo pipefail

ROOT="${1:?usage: piano16-ramdisk-prune.sh <TARGET_RECOVERY_ROOT_OUT>}"

# ICU.
#
# libandroidicu.so, libicui18n.so and libicuuc.so total 4,856,688 bytes
# uncompressed (~2.16 MB compressed) and nothing in the recovery uses them.
#
# They are installed because recovery, libxml2, libsqlite and libkeystoreinfo
# each depend on libandroidicu at build time — but on libandroidicu_static, the
# static shim. Verified with llvm-readelf: none of those four binaries has any
# ICU entry in DT_NEEDED. The only DT_NEEDED references to libicuuc.so and
# libicui18n.so in the entire ramdisk come from libandroidicu.so itself, and
# nothing references libandroidicu.so. The three libraries form a closed island.
#
# Confirmed on hardware against image p67: a scan of /proc/*/maps for every
# running process returned no match for libicuuc, libicui18n or libandroidicu,
# and a string scan of every file under /system/bin, /system/lib64,
# /vendor/lib64, /vendor/bin and /odm/lib64 matched only the three libraries
# themselves.
PRUNE=(
    system/lib64/libandroidicu.so
    system/lib64/libicui18n.so
    system/lib64/libicuuc.so
)

echo "----- Pruning dead payload from recovery ramdisk ------"

freed=0
for rel in "${PRUNE[@]}"; do
    f="$ROOT/$rel"
    if [ -f "$f" ]; then
        size=$(stat -c %s "$f")
        freed=$((freed + size))
        rm -f "$f"
        echo "  pruned $rel ($size bytes)"
    else
        # Not an error: the file may already be absent in a configuration that
        # does not install it. The closure gate is what enforces correctness.
        echo "  absent $rel"
    fi
done
echo "  freed $freed bytes uncompressed"

# Regenerate the two manifests, byte-for-byte the same commands as
# build/make/core/Makefile.
cd "$ROOT"
find . | sed "s/.\///" | sed "/lib\/modules\//d" > ramdisk-files.txt
find -type f \
    | sed "s/.\/ramdisk-files.sha256sum//" \
    | sed "/lib\/modules/d" \
    | sed "/prop.default/d" \
    | sed "/ld\.config\.txt/d" \
    | xargs sha256sum > ramdisk-files.sha256sum

echo "  manifests regenerated"
