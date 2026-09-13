# TWRP device tree for Xiaomi Pad 8 Pro

**Bring-up is complete through the QSEE / TrustZone bridge.** Boot, display, touch, USB/ADB, automatic charging, non-destructive fastbootd validation, and stock Qualcomm `qseecomd` listener registration all work with SELinux **Enforcing**. Encryption is intentionally still off: Android 16 FBE and PIN/password decryption are not implemented and `/data` is not mounted. Backup/restore, MTP storage access, destructive partition operations, and release readiness remain unvalidated.

## Current status

| Item | Validated baseline |
| --- | --- |
| Recovery | TWRP `3.7.1_14-0`, Android 14 / AP2A |
| Stock | HyperOS 3 Android 16, `OS3.0.303.0.WPYMIXM` / `piano_global` |
| Image size | 28,160,000 bytes |
| Branch | `twrp-14` |

Known-good recovery image SHA-256:

```text
0d7d0d6789f01aed5b12f2362b0a740825798966afe9c5ba5ed06139d5bfa935
```

Encryption is intentionally **off**. `/data` and `/metadata` are not mounted, no FBE build flag is enabled, and no key material is generated or replaced.

### Roadmap

| # | Stage | Status |
| --- | --- | --- |
| 1 | Basic TWRP bring-up | Done |
| 2 | Hardware / vendor recovery bring-up | Done |
| 3 | QSEE / TrustZone bridge | Done |
| 4 | KeyMint / Gatekeeper / Weaver / SecureClock / SharedSecret | Next |
| 5 | Metadata encryption key unwrap / `dm-default-key` | Pending |
| 6 | Mount existing F2FS `/data` | Pending |
| 7 | Existing DE storage unlock | Pending |
| 8 | PIN/password + Gatekeeper + Weaver + Synthetic Password | Pending |
| 9 | CE / user0 + `/data/media/0` | Pending |
| 10 | MTP / internal storage / backup / restore / sideload | Pending |
| 11 | Cleanup and full regression under SELinux Enforcing | Pending |
| 12 | TWRP 14 full FBE completion | Pending |

After TWRP 14: TWRP 14.1 -> OrangeFox 14.1 -> LineageOS -> Evolution X.

Real USB OTG remains an independent pending test.

### Safety constraints

Only `recovery_a` is experimental. Never touch `recovery_b` or switch testing to slot B. Start from a healthy slot A and keep stock recovery available. Prefer recovery_a flash -> full HyperOS boot -> `adb reboot recovery`. Never modify boot/vendor_boot/vbmeta merely for recovery, blindly disable AVB, or erase all of misc. Any justified BCB clear is limited to its first 2 KiB; see [operator guidance](AGENTS.md).

Image size matters below partition capacity: the 28,160,000-byte QSEE image and the earlier 27,906,048-byte and 27,844,608-byte images all boot, while 29,401,088 bytes with incompressible padding failed. This supports an early-boot size-constraint hypothesis, not an official exact limit; 100 MiB capacity alone does not establish bootability.

The [Build #23 record](docs/bringup-build23.md) and [screen/suspend/charging record](docs/suspend-charging-2026-09-11.md) preserve historical evidence; their earlier pending-stage descriptions are superseded by this status. Build #23's `bootable/recovery/twrpApex.cpp` fix remains required.

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

The ramdisk uses legacy LZ4 compression. Stock uses compressed Virtual A/B and dynamic partitions; fastbootd queries and Boot Control are validated; destructive partition operations remain untested.

| Partition / image property | Value |
| --- | ---: |
| Recovery capacity | 100 MiB / 104857600 bytes |
| Boot header version | 4 |
| Page size | 4096 bytes |
| Recovery kernel size | 0 bytes |
| Super capacity | 13958643712 bytes |
| Dynamic group capacity | 13948157952 bytes |

The configured dynamic group contains `odm`, `product`, `system`, `system_dlkm`, `system_ext`, `vendor`, and `vendor_dlkm`. Both DLKM partitions are logical first-stage partitions. Stock userdata uses F2FS, FBE v2, and wrapped-key metadata encryption. These are researched stock characteristics, **not evidence of working TWRP decryption**.

## QSEE / TrustZone bridge

The stock HyperOS 3 (Android 16) `qseecomd` is used **unmodified** and runs inside the Android 14 recovery as `u:r:tee:s0` with SELinux Enforcing.

| Item | Value |
| --- | --- |
| Recovery path | `/vendor/bin/piano-qseecomd` |
| Source blob | `prebuilt/qseecomd`, taken verbatim from stock vendor |
| SHA-256 | `dc1ccdd0a32891f0f38048383499e8849e071840ef5bb210eefa1b0e3b2c369f` |
| Service | `disabled`, `oneshot` — started manually with `setprop ctl.start vendor.qseecomd` |

### Android 16 compatibility island

The Android 16 daemon cannot link against the Android 14 recovery userspace directly. Five stock **system** libraries are packaged into a private directory used only by this daemon:

```text
/vendor/piano-stock-qsee-system/lib64/
    libbinder.so
    libbinder_ndk.so
    libapexsupport.so
    liblog.so
    libvndksupport.so
```

Search order:

```text
/vendor/piano-stock-qsee-system/lib64
/vendor/piano-stock/lib64
/vendor/piano-stock/lib64/hw
/system/lib64
```

Recovery `libc`, `libm`, `libdl`, and the linker are **not** copied or replaced. `libbinder_ndk.so` must be paired with the matching stock `libbinder.so`, which is why both are packaged rather than reusing the recovery copies.

### Automatic stock vendor mount

Recovery `/vendor` is left untouched. The active-slot stock vendor image is mounted read-only at an alternate path once TWRP has created the logical-partition mapper links:

```text
on property:twrp.super.symlinks_created=true && property:vendor.piano.qsee.mount_attempted=0
    setprop vendor.piano.qsee.mount_attempted 1
    mkdir /vendor/piano-stock 0755 root root
    wait /dev/block/mapper/vendor${ro.boot.slot_suffix} 5
    mount erofs /dev/block/mapper/vendor${ro.boot.slot_suffix} /vendor/piano-stock ro

    symlink /dev/block/platform/soc/1d84000.ufshc /dev/block/bootdevice
```

The guard property is set to `1` **before** the mount is attempted, because TWRP writes `twrp.super.symlinks_created` more than once; without the guard the trigger re-ran and produced repeated mount/lchown noise.

### Recovery-only bootdevice alias

Stock QSEE code resolves storage through `/dev/block/bootdevice`, which recovery does not create. The same trigger adds a symlink to `/dev/block/platform/soc/1d84000.ufshc`. This exists only inside the recovery `/dev` and changes no firmware path. No generic whole-UFS permissions are granted; only the dedicated SSD/SG/BSG/LUN4 nodes are labelled.

### SELinux

Everything runs Enforcing. The support consists of targeted labels and narrow rules only:

- ramdisk `/system` loader paths are `restorecon`'d in `on early-fs` so the existing Android `file_contexts` apply, instead of granting `tee` access to `rootfs`;
- `/dev/dma_heap/qcom,qseecom` is labelled `vendor_dmabuf_qseecom_heap_device`;
- narrow property policy for `vendor.piano.qsee.mount_attempted` and `vendor.sys.listeners.registered`.

Deliberately absent: `allow tee block_device:blk_file`, `allow tee device:chr_file`, `allow tee rootfs:file`. The `tee block_device:dir` and `tee device:dir` traversal rules are intentional and must not be removed on the mistaken grounds that they are broad file access.

### Verified runtime result

On a fresh boot the stock vendor is mounted exactly once, then a single manual start yields:

```text
state=running
vendor.sys.listeners.registered=true
process: u:r:tee:s0  piano-qseecomd  wchan=sigsuspend
```

No relevant new QSEE denials were observed and SELinux remained Enforcing.

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
recovery/root/system/bin/piano-adsp-bootstrap.sh  Automatic charging bootstrap
recovery/root/vendor/etc/ueventd.rc Recovery ueventd rules
recovery/root/vendor/piano-stock-qsee-system/lib64/  Android 16 QSEE compatibility libraries
Android.mk                         Prebuilt modules for the QSEE island and qseecomd
prebuilt/qseecomd                  Unmodified stock HyperOS 3 qseecomd
sepolicy/vendor/                   Targeted TEE, property and file-context policy
patches/system_core/              External fastbootd source patch
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

The current image baseline is identified above; Build #23 remains the historical APEX milestone. Build #18 established the frozen display/input/USB configuration. Device testing confirms boot, Qualcomm recovery USB initialization and ADB, landscape GUI rendering, the touchscreen driver stack, and correct coordinate mapping. Touch has previously survived screen suspend/resume testing. Validated touch testing ran with **SELinux Enforcing**; this does not establish validation of every recovery operation.

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
| Device tree | Early bring-up — latest image identity above |
| Recovery build and boot | Working in validated milestone |
| Qualcomm USB initialization / ADB | Working |
| Display / landscape UI | Working |
| Touchscreen driver / coordinate mapping | Working |
| Screen / panel / touch / ADB after wake / timeout | Validated — Stage 14 |
| Deep suspend / RTC wake | Validated with USB physically disconnected |
| SELinux | Enforcing, including QSEE listener registration |
| `/data` mounting / internal storage / `/data/media/0` | WIP / unvalidated |
| QSEE / TrustZone bridge, stock `qseecomd` listener registration | Validated under SELinux Enforcing |
| Read-only stock vendor mount at `/vendor/piano-stock` | Validated |
| Recovery-only `/dev/block/bootdevice` alias | Validated |
| Android 16 / HyperOS 3 FBE and PIN/password decryption | Intentionally off; not implemented |
| Physical paths / OTG false-match correction | Validated — Builds #20/#21; real OTG pending |
| Logical mappings / EROFS read mounts | Validated — Stage 10 |
| Additional vendor fstab suppression | Validated — Build #22 |
| APEX loop integration | Validated — Build #23 TWRP source patch |
| Reboot / BCB / fastbootd entry | Validated — Build #19 |
| Fastbootd Boot Control / queries / getvar all | Validated — Stage 18 safe side |
| Fastbootd logical flash / resize / create / delete | Not destructively tested |
| Backup / restore | WIP / unvalidated |
| MTP | WIP / unvalidated |
| Battery / charger detection / charging / hotplug / temperature / health | Validated runtime proof — Stage 15 |
| CDP / PD / PD-PPS / charging icon | Validated runtime proof |
| Automatic ADSP charging bootstrap | Validated |
| Brightness controls | Not separately established by this update |
| ADB sideload / flashing transport | Validated in reported safe scope — Stage 12 |
| Hardware buttons | Validated — Stage 16 |
| Reboot modes / BCB | Validated — Stage 17 |
| Full regression / stock fallback verification | Pending |
| General release readiness | Not ready |

## Suspend and charging findings

USB-disconnected deep suspend and RTC wake succeeded (`success=1`, `fail=0`). Connected USB/ADB can cause DWC3 prepare to return EBUSY; do not disable/reset DWC3 to force suspend.

Charging requires ADSP firmware access and ADSP startup so RPMSG/PMIC GLINK can initialize. The proven manual sequence mounts the active modem partition read-only, copies only ADSP firmware as real files into `/odm/firmware/o8`, and starts ADSP. The automatic bootstrap is validated: detect the active slot, mount its modem partition read-only, copy the ADSP files into recovery RAM, start ADSP, wait for running state, then unmount. CDP, PD, PD-PPS, unplug/replug, and the charging icon work. ADSP blobs must not be bundled into recovery.img. Preserve the Novatek firmware path, USB/touch configuration, and leave CDSP/SOCCP alone.

## Fastbootd — Stage 18

Two independent failures were resolved.

### Boot Control recovery implementation

`twrp_piano.mk` must package:

```make
PRODUCT_PACKAGES += \
    android.hardware.boot@1.2-impl.recovery
```

The `.recovery` variant installs `/system/lib64/hw/android.hardware.boot@1.0-impl-1.2.so`. The non-recovery variant did not. Without it, fastbootd reported zero slots and empty current-slot information, and logical queries hung. Do not replace it with `bootctrl.default`, hardcoded slots, or misc edits.

Validated: `is-userspace: yes`, `slot-count: 2`, `current-slot: a`, `has-slot:boot: yes`, `has-slot:system: yes`, and logical partition queries.

### Optional battery identity queries

The Health HAL supplies voltage and state of charge, but optional `getBatteryHealthData()` calls failed. The [stored system/core patch](patches/system_core/0001-fastbootd-tolerate-missing-battery-health-data.patch) changes `GetBatterySerialNumber()` and `GetBatteryPartStatus()` in `fastboot/device/variables.cpp` to report `unsupported` instead of failing the protocol.

This is an external source patch: apply it to `~/android/twrp-14/system/core` when reproducing the build. It is not compiled merely because the patch file exists in the device tree. The maintainer verified the tested source modification against the stored patch.

Validated results:

```text
battery-voltage: 4339
battery-soc: 100
battery-serial-number: unsupported
battery-part-status: unsupported
getvar all: successful (observed 0.548s)
max-fetch-size: 0x10000000
```

`getvar all` reports super/dynamic partition visibility and logical `system_a`, `vendor_a`, `product_a`, `odm_a`, `system_ext_a`, `system_dlkm_a`, `vendor_dlkm_a`, and stock `mi_ext_a`. This does not add `mi_ext` to the generated dynamic group.

`battery-soc-ok` still reports `Fastboot HAL not found`; this is a separate optional-interface issue. Do not introduce a fake/mock HAL solely to satisfy it. Investigate only if a required operation depends on it.

Fetching `system_dlkm_a` was rejected by the implementation whitelist, which permits only vendor_boot names. That is not proof of a broken transport or a successful fetch. Do not fetch or modify vendor_boot merely for testing. Logical flash, resize, create, and delete have not been destructively tested.

## Known limitations

Boot, USB/ADB, landscape display, touch, and the QSEE/TrustZone bridge are established for the current milestone. Storage access and decryption are not established: do not assume `/data`, internal storage, or `/data/media/0` is accessible. Real USB OTG, destructive dynamic-partition operations, and backup/restore still require validation. Read-only logical mounts and fastbootd entry are established. Runtime behavior depends on the stock boot environment and matching drivers. No GitHub Actions builder is included.

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
