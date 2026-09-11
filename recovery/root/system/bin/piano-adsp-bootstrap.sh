#!/system/bin/sh

TAG="[piano-adsp]"
MODEM_MNT="/tmp/piano-modem"
FW_DST="/odm/firmware/o8"

log()
{
    echo "$TAG $*" > /dev/kmsg
}

find_adsp_remoteproc()
{
    for r in /sys/class/remoteproc/remoteproc*; do
        [ -e "$r/name" ] || continue

        if [ "$(cat "$r/name" 2>/dev/null)" = "3000000.remoteproc-adsp" ]; then
            echo "$r"
            return 0
        fi
    done

    return 1
}

copy_firmware()
{
    src="$1"
    dst="$2"
    name="${src##*/}"

    # Do not overwrite firmware already supplied by recovery.
    [ -e "$dst" ] && return 0

    attempt=1

    while [ "$attempt" -le 5 ]; do
        rm -f "$dst"

        if cp "$src" "$dst" 2>/dev/null; then
            chmod 0644 "$dst"

            # Verify destination exists and has the same byte count.
            src_size="$(wc -c < "$src" 2>/dev/null)"
            dst_size="$(wc -c < "$dst" 2>/dev/null)"

            if [ -n "$src_size" ] &&
               [ "$src_size" = "$dst_size" ]; then
                return 0
            fi
        fi

        log "copy retry $attempt for $name"

        rm -f "$dst"
        attempt=$((attempt + 1))
        sleep 0.1
    done

    log "failed copying $name after retries"
    return 1
}

log "bootstrap starting"

#
# Find ADSP remoteproc.
#
RPROC=""
i=0

while [ "$i" -lt 50 ]; do
    RPROC="$(find_adsp_remoteproc)"

    [ -n "$RPROC" ] && break

    i=$((i + 1))
    sleep 0.1
done

if [ -z "$RPROC" ]; then
    log "ADSP remoteproc not found"
    exit 1
fi

STATE="$(cat "$RPROC/state" 2>/dev/null)"

log "remoteproc=$RPROC state=$STATE"

if [ "$STATE" = "running" ]; then
    log "ADSP already running"
    exit 0
fi

#
# Determine active slot.
#
SLOT_SUFFIX="$(getprop ro.boot.slot_suffix)"

case "$SLOT_SUFFIX" in
    _a|_b)
        ;;
    *)
        SLOT_SUFFIX="_a"
        ;;
esac

MODEM="/dev/block/by-name/modem${SLOT_SUFFIX}"

log "slot=$SLOT_SUFFIX modem=$MODEM"

#
# Wait for modem block device.
#
i=0

while [ "$i" -lt 50 ]; do
    [ -b "$MODEM" ] && break

    i=$((i + 1))
    sleep 0.1
done

if [ ! -b "$MODEM" ]; then
    log "modem partition not available"
    exit 1
fi

[ -d "$FW_DST" ] || {
    log "firmware destination missing: $FW_DST"
    exit 1
}

mkdir -p "$MODEM_MNT"
umount "$MODEM_MNT" 2>/dev/null

#
# Read-only: never write to modem partition.
#
if ! mount -t vfat -o ro "$MODEM" "$MODEM_MNT"; then
    log "failed to mount $MODEM"
    exit 1
fi

SRC="$MODEM_MNT/image"

if [ ! -f "$SRC/adsp.mdt" ]; then
    log "adsp.mdt missing from modem firmware"
    umount "$MODEM_MNT" 2>/dev/null
    exit 1
fi

log "copying ADSP firmware"

COPIED=0
FAILED=0

for f in \
    "$SRC"/adsp.mdt \
    "$SRC"/adsp.b* \
    "$SRC"/adsp_dtb.mdt \
    "$SRC"/adsp_dtb.b*
do
    [ -f "$f" ] || continue

    name="${f##*/}"

    if [ -e "$FW_DST/$name" ]; then
        continue
    fi

    if copy_firmware "$f" "$FW_DST/$name"; then
        COPIED=$((COPIED + 1))
    else
        FAILED=$((FAILED + 1))
    fi
done

log "copied $COPIED firmware files, failed $FAILED"

#
# Do not attempt to boot an incomplete firmware set.
#
if [ "$FAILED" -ne 0 ]; then
    log "firmware copy incomplete; refusing to start ADSP"
    umount "$MODEM_MNT" 2>/dev/null
    exit 1
fi

if [ ! -f "$FW_DST/adsp.mdt" ]; then
    log "adsp.mdt unavailable after copy"
    umount "$MODEM_MNT" 2>/dev/null
    exit 1
fi

log "starting ADSP"

if ! echo start > "$RPROC/state"; then
    log "failed to start ADSP"
    umount "$MODEM_MNT" 2>/dev/null
    exit 1
fi

#
# Wait up to ~5 seconds.
#
i=0

while [ "$i" -lt 50 ]; do
    STATE="$(cat "$RPROC/state" 2>/dev/null)"

    [ "$STATE" = "running" ] && break

    i=$((i + 1))
    sleep 0.1
done

umount "$MODEM_MNT" 2>/dev/null

if [ "$STATE" = "running" ]; then
    log "ADSP running successfully"
    exit 0
fi

log "ADSP failed to reach running state: $STATE"
exit 1
