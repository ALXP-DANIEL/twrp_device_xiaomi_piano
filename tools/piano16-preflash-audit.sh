#!/usr/bin/env bash
#
# Xiaomi Pad 8 Pro (piano) — TWRP16 offline recovery image audit.
#
# Runs on the image BEFORE it is ever written to the device. Verifies image
# identity and the boot-image invariants this device requires, and enforces the
# measured recovery ramdisk size ceiling.
#
# Usage:  piano16-preflash-audit.sh <recovery.img>
#
# Exit 0 only if every check passes. Nothing here touches the device.

set -u

IMG=${1:-}
[ -n "$IMG" ] && [ -f "$IMG" ] || { echo "usage: $0 <recovery.img>" >&2; exit 2; }

# Measured on hardware, see docs/twrp14-frozen-reference.md.
#   29,210,310 bytes boots (stock HOS3 Global ramdisk)
#   29,228,841 bytes fails
# Budget below the proven-good bound to keep margin.
CEILING=29210310
BUDGET=29000000
PART_SIZE=104857600

pass=0; fail=0
ok()   { printf '  \033[1;32mPASS\033[0m  %s\n' "$1"; pass=$((pass+1)); }
bad()  { printf '  \033[1;31mFAIL\033[0m  %s\n' "$1"; fail=$((fail+1)); }

echo "image: $IMG"
sha=$(shasum -a 256 "$IMG" 2>/dev/null | cut -d' ' -f1 || sha256sum "$IMG" | cut -d' ' -f1)
echo "sha256: $sha"

read -r MAGIC HV KS RS FMT FILESZ <<EOF
$(python3 - "$IMG" <<'PY'
import struct, sys
d = open(sys.argv[1], 'rb').read()
magic = d[:8].decode('latin1')
ks, rs = struct.unpack_from('<II', d, 8)
hv = struct.unpack_from('<I', d, 40)[0]
rd = d[4096:4096+rs]
if rd[:4] == bytes.fromhex('02214c18'):
    fmt = 'lz4-legacy'
elif rd[:4] == bytes.fromhex('04224d18'):
    fmt = 'lz4-modern'
elif rd[:2] == b'\x1f\x8b':
    fmt = 'gzip'
else:
    fmt = 'other-' + rd[:4].hex()
print(magic, hv, ks, rs, fmt, len(d))
PY
)
EOF

echo "header v$HV  kernel_size=$KS  ramdisk=$RS  format=$FMT  file=$FILESZ"
echo

[ "$MAGIC" = "ANDROID!" ] && ok "ANDROID! magic" || bad "bad magic: $MAGIC"
[ "$HV" = "4" ]           && ok "header version 4" || bad "header version $HV, expected 4"
[ "$KS" = "0" ]           && ok "kernel_size 0 (uses active-slot ROM kernel)" \
                          || bad "kernel_size $KS, expected 0"
[ "$RS" -gt 0 ]           && ok "ramdisk present" || bad "no ramdisk"
[ "$FMT" = "lz4-legacy" ] && ok "legacy LZ4 ramdisk" || bad "ramdisk format $FMT, expected lz4-legacy"
[ "$FILESZ" -le "$PART_SIZE" ] && ok "image fits 100 MiB partition" \
                               || bad "image $FILESZ exceeds $PART_SIZE"

# The decisive one.
if [ "$RS" -le "$BUDGET" ]; then
    ok "ramdisk $RS within budget $BUDGET (headroom $((BUDGET - RS)))"
elif [ "$RS" -le "$CEILING" ]; then
    printf '  \033[1;33mWARN\033[0m  ramdisk %s is over budget %s but under the proven bound %s\n' \
        "$RS" "$BUDGET" "$CEILING"
    printf '        margin is thin; the true ceiling lies within 18,531 bytes above it\n'
    pass=$((pass+1))
else
    bad "ramdisk $RS EXCEEDS the proven bound $CEILING by $((RS - CEILING)) — this image will NOT boot"
    printf '        the bootloader rejects it outright and marks slot A unbootable\n'
fi

echo
echo "PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
