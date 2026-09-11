# AGENTS.md — Xiaomi Pad 8 Pro (`piano`) TWRP Bring-up

This file is the operating contract and hands-on guide for AI/coding agents working in this repository.

This project is hardware bring-up. Preserve proven behavior, collect evidence from the real device, change one meaningful variable at a time, and only then advance the baseline.

## Project identity

- Device: Xiaomi Pad 8 Pro
- Codename: `piano`
- Researched model: `25091RP04C`
- SoC: Qualcomm SM8750 / Snapdragon 8 Elite
- Platform: `sun`
- Connectivity: Wi-Fi only
- Recovery target: TWRP 14 / AP2A
- Branch: `twrp-14`
- Device-tree path: `device/xiaomi/piano`
- Lunch target: `twrp_piano-ap2a-eng`

The device is A/B with a dedicated recovery partition. Stock recovery uses Android boot header v4 and is ramdisk-only (`kernel_size = 0`); the active boot slot supplies the kernel environment.

Do not introduce a separate recovery kernel unless real-device evidence proves the architecture changed.

## Current hardware-validated baseline

Current validated milestone: **Build #19**.

```text
3fd2897 piano: fix misc path for reboot handling
```

Confirmed on real hardware:

- TWRP boots from `recovery_a`.
- Qualcomm recovery USB and ADB work.
- Landscape framebuffer/UI works.
- Touchscreen driver/userspace stack works.
- Touch coordinate mapping is correct.
- Touch has survived suspend/resume testing in the validated baseline.
- Touch has worked while SELinux was Enforcing.
- `TWRP -> Reboot -> System` works.
- Android `adb reboot recovery` reaches normal TWRP.
- `TWRP -> Reboot -> Bootloader` reaches bootloader fastboot.
- Bootloader `fastboot reboot recovery` reaches normal TWRP.
- `TWRP -> Reboot -> Fastboot` reaches TWRP fastbootd.
- In fastbootd, `fastboot getvar is-userspace` returns `yes`.
- `/misc` works at `/dev/block/by-name/misc`; BCB/reboot handling is functional.

Future changes must not regress these features.

## Frozen known-good configuration

Treat this as known-good and do not casually refactor it while working on unrelated areas:

```make
TW_EXCLUDE_DEFAULT_USB_INIT := true
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
TW_THEME := landscape_hdpi
RECOVERY_TOUCHSCREEN_SWAP_XY := true
RECOVERY_TOUCHSCREEN_FLIP_Y := true
```

There must be no `TW_ROTATION` workaround in the validated landscape configuration.

The recovery image intentionally uses:

```make
TARGET_NO_KERNEL_OVERRIDE := true
BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true
BOARD_RECOVERY_MKBOOTIMG_ARGS += --header_version 4
TARGET_COPY_OUT_VENDOR := vendor
TW_INCLUDE_FASTBOOTD := true
```

The current minimal source also requires:

```make
BUILD_BROKEN_PLUGIN_VALIDATION := \
    soong-libaosprecovery_defaults \
    soong-libguitwrp_defaults \
    soong-libminuitwrp_defaults \
    soong-vold_defaults
```

Do not add broad escape hatches such as `BUILD_BROKEN_PHONY_TARGETS := true` just to suppress unrelated failures.

## Touch stack is solved — preserve it

Required packaged assets include:

```text
recovery/root/odm/bin/touch_report
recovery/root/odm/etc/init/touch_report.rc
recovery/root/odm/firmware/film_model.tflite
recovery/root/odm/firmware/MP_Setting_Criteria_59B0.csv
recovery/root/odm/firmware/MP_Setting_Criteria_59BB.csv
recovery/root/odm/firmware/o8/novatek_nt36532_piano_fw_boe.bin
recovery/root/odm/firmware/o8/novatek_nt36532_piano_fw_csot.bin
recovery/root/odm/firmware/palm_check.tflite
recovery/root/odm/firmware/piano_nova_boe_thp_config.ini
recovery/root/odm/firmware/piano_nova_csot_thp_config.ini
recovery/root/odm/lib64/libtensorflowlite_touch_c.so
recovery/root/odm/lib64/libtouchreport_alg.so
recovery/root/odm/lib64/libtouchreport_hal.so
recovery/root/odm/lib64/libtouchreport_sensor.so
recovery/root/odm/lib64/libtouchreport.so
recovery/root/odm/lib64/sensors.touch.detect.so
recovery/root/vendor/lib/modules/nt36532_touch.ko
recovery/root/vendor/lib/modules/xiaomi_touch.ko
```

Keep Novatek firmware under `/odm/firmware/o8`.

Do not override `firmware_class.path` without evidence.

The working touch modules were observed with vermagic:

```text
6.6.57-4k-g52a6ca9a4df0 SMP preempt mod_unload modversions aarch64
```

while the tested stock kernel reported a newer Android 6.6 kernel. Their working behavior shows compatibility; it does not prove an exact kernel build match.

## USB/ADB is solved — preserve it

The device uses piano-specific Qualcomm ConfigFS recovery USB initialization.

Do not replace the custom recovery USB init with TWRP's default USB init while working on unrelated features.

## Mandatory hardware safety rules

Unless the user explicitly decides otherwise after evidence is collected:

1. Experimental recovery flashes go to `recovery_a` only.
2. Keep `recovery_b` untouched as fallback.
3. Do not flash `boot`, `init_boot`, `vendor_boot`, `vbmeta`, `vbmeta_system`, `dtbo`, `super`, or firmware partitions merely to make TWRP work.
4. Do not disable AVB blindly.
5. Do not switch active slots as a troubleshooting shortcut.
6. Do not wipe, format, or resize `/data`, `/metadata`, `super`, or logical partitions during diagnostics.
7. Do not perform destructive fastbootd operations until the relevant partition layout is validated read-only.
8. Do not zero `/misc` before capturing evidence when debugging reboot behavior.
9. Donor trees are references, not sources of truth. Do not wholesale-copy one.
10. Keep CN and Global stock firmware/kernel/module combinations region-matched.
11. Preserve a known-good image/source checkpoint before risky experiments.
12. Do not call a feature fixed until it is validated on the real device.

Before flashing, distinguish bootloader fastboot from userspace fastbootd:

```sh
fastboot getvar is-userspace 2>&1
```

Interpretation:

```text
is-userspace: no   = bootloader fastboot
is-userspace: yes  = userspace fastbootd
```

Flash `recovery_a` only from bootloader fastboot unless there is a specific validated reason not to.

## `/misc` / BCB lesson

A previous fstab used:

```text
/dev/block/bootdevice/by-name/misc
```

but that path did not exist in recovery. The real device exposes:

```text
/dev/block/by-name/misc -> /dev/block/sda12
```

Because TWRP could not open the old path, it could not clear the bootloader control message, leaving `boot-recovery` persistent and causing reboot targets to return to recovery.

Build #19 fixed the fstab entry to:

```text
/dev/block/by-name/misc /misc emmc defaults defaults
```

This is hardware-validated. Do not revert it.

General rule: every hard-coded `/dev/block/...` path must be verified against the live recovery environment.

## How an agent should work

Use evidence-driven, one-variable-at-a-time bring-up.

For each bug/feature:

1. Start from the latest hardware-validated commit.
2. Check `git status` before changing anything.
3. Prefer read-only diagnostics first.
4. Capture relevant logs/state before applying a workaround.
5. Form one concrete hypothesis.
6. Make the smallest source change that tests the hypothesis.
7. Build incrementally.
8. Flash only `recovery_a` from bootloader fastboot.
9. Test the exact target behavior on-device.
10. Re-test established features if the change could affect them.
11. Commit/push only after hardware validation.
12. Update `README.md` and `AGENTS.md` when a milestone materially changes.

Do not combine unrelated fstab, FBE, UI, USB, touch, power, and boot-chain changes into one experimental build.

## Standard builder workflow

Builder root:

```text
~/android/twrp-14
```

Before work:

```sh
cd ~/android/twrp-14/device/xiaomi/piano

git status
git pull --ff-only origin twrp-14
git log -1 --oneline
```

Build:

```sh
cd ~/android/twrp-14
source build/envsetup.sh
export ALLOW_MISSING_DEPENDENCIES=true
lunch twrp_piano-ap2a-eng
m recoveryimage -j4
```

Expected artifact:

```text
~/android/twrp-14/out/target/product/piano/recovery.img
```

Do not commit the image or build output.

Optional builder hash:

```sh
sha256sum out/target/product/piano/recovery.img
```

## Copy a test image to the Mac workspace

Typical Mac project root:

```text
/Volumes/XiaomiPad8Pro/xiaomi-pad-8-pro
```

Example:

```sh
cd "/Volumes/XiaomiPad8Pro/xiaomi-pad-8-pro"

scp \
  lineage:~/android/twrp-14/out/target/product/piano/recovery.img \
  analysis/recovery/twrp/recovery-piano-buildXX-description.img

shasum -a 256 \
  analysis/recovery/twrp/recovery-piano-buildXX-description.img
```

Use a meaningful build number and description.

## Safe recovery flashing procedure

Confirm bootloader fastboot first:

```sh
fastboot devices
fastboot getvar is-userspace 2>&1
fastboot getvar current-slot 2>&1
```

Expected before flashing:

```text
is-userspace: no
```

Flash only `recovery_a`:

```sh
IMG="/path/to/test-recovery.img"
fastboot flash recovery_a "$IMG"
fastboot reboot recovery
```

Never add `recovery_b` to an experimental flash command.

## Known-good stock recovery rollback

Known Global stock recovery in the project workspace:

```text
/Volumes/XiaomiPad8Pro/xiaomi-pad-8-pro/stock/hyperos3/global/OS3.0.303.0.WPYMIXM/images/recovery.img
```

From bootloader fastboot (`is-userspace: no`) only:

```sh
STOCK="/Volumes/XiaomiPad8Pro/xiaomi-pad-8-pro/stock/hyperos3/global/OS3.0.303.0.WPYMIXM/images/recovery.img"
fastboot flash recovery_a "$STOCK"
fastboot reboot
```

Do not overwrite `recovery_b` during rollback.

## Standard runtime diagnostics

### ADB

```sh
adb devices
```

Expected TWRP mode:

```text
<serial>    recovery
```

### Recovery log

```sh
adb shell 'tail -200 /tmp/recovery.log'
```

Focused errors:

```sh
adb shell '
grep -iE "failed|error|unable|mount|misc|fastboot|reboot" \
/tmp/recovery.log | tail -200
'
```

### Properties

```sh
adb shell 'getprop | grep -iE "bootreason|boot.mode|fastboot|recovery|slot"'
```

### Block devices

```sh
adb shell '
ls -ld /dev/block/by-name /dev/block/bootdevice/by-name 2>&1
ls -l /dev/block/by-name 2>&1
ls -l /dev/block/bootdevice/by-name 2>&1
ls -l /dev/block/mapper 2>&1
'
```

### Mounts/filesystems

```sh
adb shell '
cat /proc/mounts
blkid 2>&1
df -h 2>&1
'
```

## Stage 7: fstab/storage audit procedure

First inspect live namespaces:

```sh
adb shell '
echo "===== BLOCK NAMESPACES ====="
ls -ld /dev/block/by-name /dev/block/bootdevice/by-name 2>&1

echo
echo "===== BY-NAME PARTITIONS ====="
ls -l /dev/block/by-name 2>&1

echo
echo "===== BOOTDEVICE BY-NAME ====="
ls -l /dev/block/bootdevice/by-name 2>&1

echo
echo "===== MAPPER ====="
ls -l /dev/block/mapper 2>&1

echo
echo "===== CURRENT MOUNTS ====="
cat /proc/mounts

echo
echo "===== FILESYSTEMS ====="
blkid 2>&1
'
```

Audit every physical block path in TWRP fstab without writing anything:

```sh
adb shell '
echo "===== FSTAB BLOCK DEVICE AUDIT ====="
while read -r dev rest; do
    case "$dev" in
        /dev/block/*)
            if [ -e "$dev" ]; then
                printf "OK      %-55s -> " "$dev"
                readlink -f "$dev"
            else
                printf "MISSING %s\n" "$dev"
            fi
            ;;
    esac
done < /etc/recovery.fstab
'
```

Inspect TWRP storage/partition errors:

```sh
adb shell '
grep -iE \
"failed to open|unable to mount|failed to mount|invalid|unknown filesystem|primary_block_device|size: 0mb" \
/tmp/recovery.log | tail -200
'
```

Do not mass-rewrite fstab paths. Correlate each entry with the live node, filesystem, mount behavior, and logs.

## Reboot / BCB diagnostics

If reboot behavior loops or reaches the wrong mode, capture `/misc` before clearing it.

```sh
adb exec-out \
'dd if=/dev/block/by-name/misc bs=2048 count=1 2>/dev/null' \
> /tmp/piano-misc.bin

hexdump -C /tmp/piano-misc.bin | head -32
/usr/bin/strings -a /tmp/piano-misc.bin | head -30
```

Useful log filter:

```sh
adb shell '
grep -iE "Startup Commands|boot-fastboot|misc|fastboot|reboot" \
/tmp/recovery.log | head -100
'
```

Only if evidence requires clearing the BCB, the previously tested operation was limited to its first 2 KiB:

```sh
adb shell '
dd if=/dev/zero of=/dev/block/by-name/misc \
bs=2048 count=1 conv=notrunc && sync
'
```

This is a diagnostic recovery action, not a routine step. Capture evidence first.

## Fastbootd validation

Enter through:

```text
TWRP -> Reboot -> Fastboot
```

Then:

```sh
fastboot devices
fastboot getvar is-userspace 2>&1
```

Expected:

```text
is-userspace: yes
```

Fastbootd entry is validated. Destructive logical-partition operations are not.

## Git workflow

GitHub `twrp-14` is canonical source.

Before editing:

```sh
cd ~/android/twrp-14/device/xiaomi/piano
git status
git pull --ff-only origin twrp-14
```

After a hardware-validated change:

```sh
git status --short
git diff

git add <changed-files>
git diff --cached --check
git diff --cached

git commit -m "piano: concise description"
git push origin twrp-14
```

On macOS, a custom authenticated wrapper such as `git-p` may be used where needed for push. Prefer normal `git` for local status/diff/add/commit if the wrapper prompts interfere.

Do not commit `.before-*` backups, test images, temporary logs, or unrelated analysis artifacts.

## Builder/source synchronization rule

Do not maintain an untracked hand-edited builder tree indefinitely.

Desired flow:

```text
GitHub twrp-14
      ↓
builder device/xiaomi/piano
      ↓
recovery.img
      ↓
real-device test
      ↓
validated commit + docs
```

If a builder-only experiment is necessary, sync only the intended source changes to the canonical repo, review them, validate on hardware, then return the builder to tracking GitHub.

## Known build-system failure patterns

The builder/source environment has shown occasional transient failures unrelated to device-tree correctness, including Kati/Soong crashes, module-path truncation, unrelated graphics errors, and stale recovery packaging.

Do not rewrite device code because of an obviously unrelated transient build crash.

If `.module_paths` is stale/truncated:

```sh
rm -rf out/.module_paths
m recoveryimage -j4
```

If recovery packaging fails because old directories conflict with new symlinks:

```sh
rm -rf \
  out/target/product/piano/recovery \
  out/target/product/piano/obj/PACKAGING/recovery_intermediates

m recoveryimage -j4
```

Avoid wiping all `out/soong` or doing a full clean unless evidence requires it.

## Storage/FBE rules

Android 16 / HyperOS 3 storage decryption is not yet validated.

The current fstab contains researched F2FS/FBE flags; their presence does not prove TWRP can decrypt or safely mount user data.

Until validated, do not claim support for:

- `/data` decryption
- PIN/password unlock
- `/data/media/0`
- internal-storage browsing
- encrypted backup/restore

For FBE work, inspect the real environment first, including:

- `/metadata/vold`
- `/data/misc/vold`
- CE/DE key material
- metadata-encryption state
- KeyMint
- Keystore
- Gatekeeper
- vendor services/libraries
- relevant properties
- SELinux denials

Do not spoof fake platform/security-patch values to force decryption.

## Current roadmap

Completed/validated:

1. Recovery boot
2. GUI/framebuffer
3. USB/ADB
4. Touch hardware stack
5. Landscape UI and exact touch mapping
6. Reboot/BCB handling and fastbootd entry

Next:

7. Partition/fstab/storage audit
8. Android 16 / HyperOS 3 FBE mapping
9. `/data` PIN/password decryption and `/data/media/0`
10. Dynamic-partition validation
11. Backup/restore
12. ADB sideload/flashing workflows
13. MTP
14. Screen/suspend/power behavior
15. Battery/charging
16. Hardware buttons
17. Remaining reboot/boot-chain behavior
18. Fastbootd partition operations
19. SELinux cleanup
20. Device-tree cleanup
21. Reproducible clean build
22. Full hardware test matrix
23. Stock-recovery/fallback safety validation
24. Documentation
25. Release maturity

Do not jump to FBE/decryption before physical/logical partition paths and storage fstab are trustworthy.

## How to guide the user

When operating interactively with the user:

- Give exact copy-paste commands.
- State whether commands run on macOS or on the Ubuntu builder when ambiguous.
- Explain expected output and what each result branch means.
- Ask for focused diagnostic output instead of giant logs when possible.
- Preserve known-good state during diagnosis.
- Clearly separate proven facts from hypotheses.
- Do not say something is fixed until the user validates it on hardware.
- Maintain build numbers/milestones for flashed experiments.
- Prefer one experimental variable per build.
- If a test unexpectedly proves another feature works, record it, but do not assume adjacent operations are safe.
- For risky tests, include the rollback path.

## Documentation maintenance

`README.md` is user-facing project/status documentation.

`AGENTS.md` is the operator/AI contract and hands-on procedure guide.

When a milestone changes:

- update the baseline build/commit;
- move validated features out of WIP;
- keep unvalidated features explicitly marked unvalidated;
- document important device-specific lessons;
- keep safety/rollback instructions current;
- do not overstate release readiness.

This remains an experimental recovery bring-up tree, not a general-release recovery.
