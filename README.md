# TWRP device tree for Xiaomi Pad 8 Pro

**Early bring-up — Build #23 baseline.** TWRP boots on **piano** with working Qualcomm USB/ADB, landscape UI, and correctly mapped touchscreen input. Reboot/BCB, fastbootd entry, logical EROFS read mounts, and APEX loop integration are validated. FBE is paused; backup/restore, partition writes, and release readiness remain pending. This milestone reflects reported device testing, not a complete TWRP release.

## Current context and next target

See [the complete Build #23 record](docs/bringup-build23.md) for Build #22/#23 image sizes and SHA-256 hashes, installed Global ROM/API/patch details, validated mappings, size experiments, source modifications, and the full roadmap. These are maintainer-reported hardware findings.

**Stage 10 is complete** within its documented read-only/integration scope. **Stages 8/9 remain paused. Next: Stage 12 — ADB sideload / flashing transport validation**, or Stage 7C if real USB OTG hardware is immediately available.

Build #23 requires the separate `bootable/recovery/twrpApex.cpp` fd/loop patch, saved on the builder as `~/piano-build23-apex-fd-fix.patch`. The builder also has unrelated local GUI/render changes; do not reset or commit them wholesale. A device-tree checkout alone is not a reproducible Build #23 source snapshot.

Only `recovery_a` is experimental. Never touch `recovery_b` or switch testing to slot B. Start with healthy slot A and keep stock recovery available. Prefer recovery_a flash → full HyperOS boot → `adb reboot recovery`. Never modify boot/vendor_boot/vbmeta merely for recovery, blindly disable AVB, or erase all of misc. Any justified BCB clear is limited to its first 2 KiB; see [operator guidance](AGENTS.md).

Image size matters below partition capacity: 27,844,608 bytes worked, while 29,401,088 bytes with incompressible padding failed. This supports an early-boot size-constraint hypothesis, not an official exact limit; 100 MiB capacity alone does not establish bootability.

## Device

| Item | Value |
| --- | --- |
| Device | Xiaomi Pad 8 Pro |
| Codename | `piano` |
| Researched model | `25091RP04C` |
| SoC | Qualcomm SM8750 / Snapdragon 8 Elite |
| Platform | `sun` |
| Connectivity | Wi-Fi only |
| Target | TWRP 14 |
| Branch | `twrp-14` |

## Recovery architecture

Stock recovery occupies a dedicated partition on an A/B device. Its header-v4 image is **ramdisk-only** (`kernel_size = 0`) and uses the active boot-slot kernel together with the stock boot/vendor_boot environment. This tree deliberately excludes a recovery kernel. It packages the validated Xiaomi/Novatek touch modules and their userspace, firmware, configuration, and model dependencies.

Current development/testing uses `recovery_a`; `recovery_b` has intentionally been left untouched. This baseline does not require introducing boot, vendor_boot, or vbmeta modifications.

The ramdisk uses legacy LZ4 compression. Stock uses compressed Virtual A/B and dynamic partitions; fastbootd entry is validated; fastbootd partition operations remain pending.

| Partition / image property | Value |
| --- | ---: |
| Recovery capacity | 100 MiB / 104857600 bytes |
| Boot header version | 4 |
| Page size | 4096 bytes |
| Recovery kernel size | 0 bytes |
| Super capacity | 13958643712 bytes |
| Dynamic group capacity | 13948157952 bytes |

The configured dynamic group contains `odm`, `product`, `system`, `system_dlkm`, `system_ext`, `vendor`, and `vendor_dlkm`. Both DLKM partitions are logical first-stage partitions. Stock userdata uses F2FS, FBE v2, and wrapped-key metadata encryption. These are researched stock characteristics, **not evidence of working TWRP decryption**.

## Repository structure

```text
AndroidProducts.mk                 Product and AP2A lunch selection
BoardConfig.mk                     Architecture and recovery image configuration
device.mk                          Product inheritance and recovery init installation
recovery.fstab                     Recovery fstab derived from stock layout
twrp_piano.mk                      Product identity
recovery/root/init.recovery.qcom.rc Qualcomm init and touch module/service startup
recovery/root/init.recovery.usb.rc  Device-specific Qualcomm USB initialization
recovery/root/odm/                 Touch service, libraries, firmware and models
recovery/root/vendor/lib/modules/  Xiaomi and Novatek touch drivers
```

## Build

Use a complete TWRP 14 source checkout with recovery `android-14` and build `android-14.1`. Place this repository at `device/xiaomi/piano`, on branch `twrp-14`. The device tree alone is not a build environment.

Run from the source checkout root:

```sh
export ALLOW_MISSING_DEPENDENCIES=true
source build/envsetup.sh
export ALLOW_MISSING_DEPENDENCIES=true
lunch twrp_piano-ap2a-eng
export ALLOW_MISSING_DEPENDENCIES=true
m recoveryimage -j4
```

These are the current bring-up commands. `ALLOW_MISSING_DEPENDENCIES` is part of the current builder invocation and does not establish dependency completeness. Review build errors and output before testing. The expected artifact is `out/target/product/piano/recovery.img`; do not commit it.

## Current baseline and frozen Build #18 display/input milestone

Build #23 is the current known-good functional baseline. Build #18 established the frozen display/input/USB configuration. Device testing confirms boot, Qualcomm recovery USB initialization and ADB, landscape GUI rendering, the touchscreen driver stack, and correct coordinate mapping. Touch has previously survived screen suspend/resume testing. Validated touch testing ran with **SELinux Enforcing**; this does not establish validation of every recovery operation.

### Display and input configuration

```make
TW_EXCLUDE_DEFAULT_USB_INIT := true
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
TW_THEME := landscape_hdpi
RECOVERY_TOUCHSCREEN_SWAP_XY := true
RECOVERY_TOUCHSCREEN_FLIP_Y := true
```

There is no `TW_ROTATION` setting. Preserve this configuration together with the device-specific USB init and touch stack when reproducing the milestone.

### Packaged touch stack

- `recovery/root/odm/bin/touch_report` and `odm/etc/init/touch_report.rc`.
- Xiaomi touch-report libraries under `recovery/root/odm/lib64`.
- `film_model.tflite`, `palm_check.tflite`, BOE/CSOT THP configurations, and MP criteria CSV files under `recovery/root/odm/firmware`.
- `novatek_nt36532_piano_fw_boe.bin` and `novatek_nt36532_piano_fw_csot.bin` under `recovery/root/odm/firmware/o8`.
- `xiaomi_touch.ko` and `nt36532_touch.ko` under `recovery/root/vendor/lib/modules`.

These are required runtime assets in the validated baseline, not disposable build output. Their presence does not establish cross-region kernel/module compatibility.

## Bring-up status

| Feature | Status |
| --- | --- |
| Device tree | Early bring-up — Build #23 baseline |
| Recovery build and boot | Working in validated milestone |
| Qualcomm USB initialization / ADB | Working |
| Display / landscape UI | Working |
| Touchscreen driver / coordinate mapping | Working |
| Touch screen suspend/resume | Previously tested successfully |
| SELinux | Enforcing during validated touch testing |
| `/data` mounting / internal storage / `/data/media/0` | WIP / unvalidated |
| Android 16 / HyperOS 3 FBE and PIN/password decryption | PAUSED — cannot mount/decrypt `/data` |
| Physical paths / OTG false-match correction | Validated — Builds #20/#21; real OTG pending |
| Logical mappings / EROFS read mounts | Validated — Stage 10 |
| Additional vendor fstab suppression | Validated — Build #22 |
| APEX loop integration | Validated — Build #23 TWRP source patch |
| Reboot / BCB / fastbootd entry | Validated — Build #19 |
| Fastbootd partition operations | Pending |
| Backup / restore | WIP / unvalidated |
| MTP | WIP / unvalidated |
| Charging / battery / brightness | WIP / unvalidated |
| Complete Android reboot / boot-chain testing | WIP / unvalidated |
| General release readiness | Not ready |

## Known limitations

Boot, USB/ADB, landscape display, and touch are established for the current milestone. Storage access and decryption are not established: do not assume `/data`, internal storage, or `/data/media/0` is accessible. Real USB OTG, destructive dynamic-partition operations, and backup/restore still require validation. Read-only logical mounts and fastbootd entry are established. Runtime behavior depends on the stock boot environment and matching drivers. No GitHub Actions builder is included.

CN and Global devices must retain region-matched stock firmware and kernel/module tuples. Global users must not flash CN firmware to use this tree. Cross-region compatibility has not been proven.

## Testing warning

This is an experimental recovery, not a general release. The working boot/input milestone does not validate storage operations, decryption, or the complete Android reboot/boot chain. Retain a known recovery path and keep `recovery_b` untouched as in current testing. No general flashing procedure is endorsed here.

## Binary provenance and redistribution

The tree includes touch executables, shared libraries, firmware, model data, and kernel modules from the working device stack. Review their provenance, redistribution permissions, license notices, and any applicable source obligations before public distribution. Existing source notices do not by themselves establish permission to redistribute every binary. These assets are retained to preserve the validated runtime baseline.

## Credits

- Project contributors for piano stock firmware analysis and device research.
- Team Win Recovery Project and AOSP for the recovery and build infrastructure.
- Xiaomi and Qualcomm for the underlying device platform. Existing source notices are retained.

## Disclaimer

Unofficial community bring-up, not endorsed by Xiaomi, Qualcomm, or Team Win. Provided without guarantees of functionality or fitness; device testing can cause data loss or leave the device unable to boot.
