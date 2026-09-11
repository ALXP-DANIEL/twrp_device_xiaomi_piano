# Piano Build #23 — validated context and operator record

> Historical Build #23 checkpoint. For the later completed Stage 12 safe-scope, Stage 14 suspend, Stage 15 charging runtime proof, and pending permanent ADSP integration, read [the 2026-09-11 update](suspend-charging-2026-09-11.md). The roadmap below is retained as history.

Build #23 is the current known-good functional baseline, including the Build #22 device-tree fix and a separate TWRP source patch. Early bring-up remains incomplete; FBE is paused.

## Evidence scope and locations

This record transcribes the maintainer-supplied hardware findings from the current handoff. Hardware tests were not rerun during this documentation sync. Image hashes and remote source state below are reported evidence, not newly verified remote artifacts.

- Builder: `~/android/twrp-14`; device tree: `~/android/twrp-14/device/xiaomi/piano`.
- Canonical Mac tree: `/Volumes/XiaomiPad8Pro/xiaomi-pad-8-pro/output/recovery/twrp/device/xiaomi/piano`.
- Mac project root: `/Volumes/XiaomiPad8Pro/xiaomi-pad-8-pro`.
- Public source: `https://github.com/ALXP-DANIEL/twrp_device_xiaomi_piano`, branch `twrp-14`.
- Read [AGENTS.md](../AGENTS.md) for operating rules and [README.md](../README.md) for current public status.

Commands below are reference procedures, not authorization to execute them. This synchronization does not build, flash, or change source/runtime configuration.

## Interpretation boundaries

- **Validated:** reported hardware results for Builds #18–23, including read-only logical mounts and the tested APEX payload.
- **Experimental failures:** padding/crypto images listed below; the old #22A test was contaminated and invalid.
- **Hypothesis:** an effective early-boot compressed-image/ramdisk size constraint. The working/failing pair is empirical, not an official universal byte limit. Stock padded partition images are not directly comparable to these custom-image trials.
- **Pending:** Stage 7C real OTG; Stage 12 transport validation next; Stages 8/9 explicitly paused. Stage 10 completion covers the listed read-only/integration checks, not arbitrary partition writes or all Android 16 APEX packages.
- Observed `dm-N` assignments are a runtime snapshot, not persistent identifiers. `mi_ext_a` was tested from stock super; do not add `mi_ext` to the generated seven-member dynamic group.

## Device / Platform

```text
Device:
Xiaomi Pad 8 Pro

Codename:
piano

Model researched:
25091RP04C

SoC:
Qualcomm SM8750 / Snapdragon 8 Elite

Platform:
sun

Device type:
Wi-Fi only

Installed stock ROM:
HyperOS 3 Global
OS3.0.303.0.WPYMIXM
piano_global

Android:
16

SDK:
36

System security patch:
2026-07-01

Vendor security patch:
2026-02-01

First API:
36

Board/Vendor API:
202404

Recovery:
Dedicated A/B recovery partitions
100 MiB each

Recovery image:
header v4
ramdisk-only
kernel_size=0
uses active-slot stock kernel environment

TWRP target:
Android 14 / AP2A

Current TWRP:
3.7.1_14-0

Lunch target:
twrp_piano-ap2a-eng
```

## Critical Safety Rules

```text
These rules MUST remain prominent in project context:

1. Only `recovery_a` is experimental.
2. NEVER touch `recovery_b` during bring-up.
3. NEVER flash/change vbmeta merely to make recovery work.
4. NEVER modify boot or vendor_boot merely to make recovery work.
5. NEVER switch testing to slot B.
6. NEVER blindly disable AVB.
7. NEVER erase all of misc.
8. If BCB needs clearing, only the first 2 KiB of misc is permitted.
9. Recovery hardware testing should start from healthy slot A.
10. Prefer the validated path:
      flash recovery_a
      -> boot HyperOS fully
      -> adb reboot recovery
   rather than relying on `fastboot reboot recovery`.
11. Keep stock recovery available for immediate fallback.

Known healthy slot-A state before testing:

current-slot: a
slot-successful:a: yes
slot-unbootable:a: no
slot-retry-count:a: 6
```

## Known-Good Baseline History

```text
Build #18:
Solved and freeze:
- GUI/framebuffer
- landscape
- touchscreen hardware
- exact touch coordinate mapping
- USB/ADB
- touch suspend/resume
- SELinux enforcing touch

Do NOT casually change display/touch/USB configuration.

Important flags:

TW_EXCLUDE_DEFAULT_USB_INIT := true
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
TW_THEME := landscape_hdpi
RECOVERY_TOUCHSCREEN_SWAP_XY := true
RECOVERY_TOUCHSCREEN_FLIP_Y := true

No TW_ROTATION.

Touch stack:
- xiaomi_touch.ko
- nt36532_touch.ko
- NVTCapacitiveTouchScreen
- BOE panel
- touch_report userspace service
- Xiaomi ODM firmware/config/assets

USB:
Custom donor-style init.recovery.usb.rc
Default TWRP USB init intentionally excluded.

Build #19:
Validated reboot / BCB / fastbootd behavior.

Correct misc:
  /dev/block/by-name/misc

Safe BCB inspect:
  dd if=/dev/block/by-name/misc bs=2048 count=1

Safe BCB clear:
  dd if=/dev/zero of=/dev/block/by-name/misc bs=2048 count=1 conv=notrunc

Build #20:
Fixed physical recovery.fstab paths:
  /dev/block/bootdevice/by-name/*
to:
  /dev/block/by-name/*

Commit:
5180bd9 piano: fix recovery block device paths

Build #21:
Fixed USB OTG false matching against internal UFS.

Old broad pattern:
  /devices/platform/soc/*.ssusb/*.dwc3/xhci-hcd.*.auto*

Current:
  /devices/platform/soc/a600000.ssusb/*.dwc3/xhci-hcd.*.auto*

Commit:
b600385 piano: restrict USB OTG sysfs matching

Real USB OTG device testing is still pending.
```

## Known-Good Recovery Images

```text
Archived Build #21:
Path:
analysis/recovery/twrp/recovery-piano-build21-usbotg-fix.img

Size:
27,119,616 bytes

SHA-256:
bd4ce03b409a12a5b150e6d50f734e49e657f88682f11618920cf005390536cf

Fresh Build #21 control:
Path:
analysis/recovery/twrp/recovery-piano-build21-fresh-control.img

Size:
27,844,608 bytes

SHA-256:
dde6ad75a8c232dbd51027a55e6f31b3c25a4525023dc9901e444cee969c4db4

Fresh Build #21 boots successfully using:
  fastboot flash recovery_a
  fastboot reboot
  boot HyperOS
  adb reboot recovery
```

## Recovery Image Size Investigation

```text
Important finding:

Fresh working Build #21:
27,844,608 B
✅ boots

Fresh Build21 + 1.5 MiB random incompressible padding:
29,401,088 B
❌ fails / returns fastboot

Fresh Build21 + 3 MiB padding:
30,986,240 B
❌ fails

Clean crypto #22A:
32,595,968 B
❌ fails

Build21 + ~5.3 MiB random padding:
33,357,824 B
❌ fails

Therefore there is strong evidence for an effective EARLY-BOOT compressed recovery image/ramdisk size constraint.

Do NOT document an exact official limit.
Current empirical boundary only:

27,844,608 B works
29,401,088 B fails

Partition capacity itself is 100 MiB and is NOT the relevant limit.
```

## Build Infrastructure

```text
Builder:
Ubuntu 24.04.5 VM
12 vCPU
~20 GB RAM
8 GB swap

Important build environment:

export ALLOW_MISSING_DEPENDENCIES=true

source build/envsetup.sh
export ALLOW_MISSING_DEPENDENCIES=true

lunch twrp_piano-ap2a-eng
export ALLOW_MISSING_DEPENDENCIES=true

m recoveryimage -j4

After targeted recovery cleanup, MUST recreate:

mkdir -p out/target/product/piano/recovery/root/system/etc

Known-good targeted cleanup:

rm -f out/target/product/piano/recovery.img

rm -rf \
  out/target/product/piano/root \
  out/target/product/piano/recovery \
  out/target/product/piano/obj/PACKAGING/recovery_intermediates

mkdir -p out/target/product/piano/recovery/root/system/etc

Do NOT routinely wipe the entire:
out/target/product/piano
```

## Stage 7 / Partition Status

```text
Physical recovery.fstab paths:
✅ validated

Dynamic logical partitions currently map correctly:

odm_a          -> /dev/block/dm-0
product_a      -> /dev/block/dm-1
system_a       -> /dev/block/dm-2
system_dlkm_a  -> /dev/block/dm-3
system_ext_a   -> /dev/block/dm-4
vendor_a       -> /dev/block/dm-5
vendor_dlkm_a  -> /dev/block/dm-6
mi_ext_a       -> /dev/block/dm-7

super:
  /dev/block/by-name/super
  -> /dev/block/sda33

All tested logical partitions successfully mount READ-ONLY as EROFS:
✅ odm_a
✅ product_a
✅ system_a
✅ system_dlkm_a
✅ system_ext_a
✅ vendor_a
✅ vendor_dlkm_a
✅ mi_ext_a

System is correctly mounted by TWRP at:
  /system_root

Do not confuse recovery `/system` with Android `/system_root`.
```

## Build #22 — Additional Fstab Fix

```text
TWRP was loading the stock vendor fstab as:
/system/etc/additional.fstab

Stock vendor fstab contains duplicate /data definitions:
- f2fs
- mifs

The unsupported `mifs` entry caused:
  E:Unknown File System: 'mifs'

The piano recovery.fstab already has the correct single F2FS /data entry:

/dev/block/by-name/userdata
/data
f2fs
...

Correct fix:

TW_SKIP_ADDITIONAL_FSTAB := true

Validated Build #22:

Image:
recovery-piano-build22-skip-additional-fstab.img

Size:
27,832,320 bytes

SHA-256:
ea7918ce6b32b6327543f0f1a3974563abcc06daac96c8c2456276b6b34b273f

Hardware validation:
✅ boots TWRP
✅ slot _a
✅ additional.fstab absent
✅ recovery log:
   I:Skipping Additional Fstab Processing
✅ no mifs error
✅ logical dm mappings intact
✅ system_a mounts as EROFS at /system_root

This device-tree change should remain part of the current baseline.
```

## Build #23 — Twrp Apex Loop Fix

```text
A TWRP source bug was identified in:

bootable/recovery/twrpApex.cpp

Original broken ordering:

close(fd);

...
off_t apex_size = lseek(fd, 0, SEEK_END);

This calls lseek() on an already-closed fd.

Observed runtime failure:

failed to mount loop:
Value too large for defined data type

Unable to create loop devices to mount apex files
Unable to load apex images

Manual investigation proved:
✅ loop kernel support exists
✅ /dev/block/loop0..loop15 exist
✅ extracted apex payload is valid
✅ payload is ext4
✅ manual loop ext4 mount works

Build #23 source fix:
- keep fd open during lseek()
- validate apex_size
- clear LOOP_SET_FD on failure
- close fd after LOOP_SET_STATUS64

Standalone patch saved as:

~/piano-build23-apex-fd-fix.patch

Build #23 image:

analysis/recovery/twrp/recovery-piano-build23-apex-fd-fix.img

Size:
27,832,320 bytes

SHA-256:
90bc6dc0b69af264262f0a793489997885e3418a7b21c2d99f7fdc47b03dd94f

Hardware validation:

TWRP=3.7.1_14-0
slot=_a

twrp.apex.loaded=true

Successful mount:

/dev/block/loop0
-> /apex/com.android.cts.shim
ext4
read-only

losetup:
sizelimit 274432

Therefore:
✅ APEX extraction works
✅ loop allocation works
✅ LOOP_SET_FD works
✅ LOOP_SET_STATUS64 works after fix
✅ ext4 APEX mount works
✅ EOVERFLOW error is fixed

Remaining log messages about these missing legacy files are NON-FATAL:

com.google.android.tzdata2.apex
com.android.tzdata.apex
com.android.art.release.apex
com.google.android.media.swcodec.apex
com.android.media.swcodec.apex

Do NOT blindly replace them with Android 16 `_compressed.apex` files.

Recovery currently already has its own tzdata.

TW_ADDITIONAL_APEX_FILES exists in TWRP but piano currently does not use it.

No `resyncapex.sh` exists in this tree.

The other APEX callsites only unmount APEX during:
- Format Data / virtual A/B handling
- Unmap Super

Do not apply unrelated community APEX changes unless hardware evidence shows they are needed.
```

## Current Bootable/Recovery Source State

```text
IMPORTANT:

bootable/recovery is NOT a clean source tree.

Before Build #23 these modifications already existed:

 M gui/gui.cpp
 M gui/pages.cpp
 M twrp-functions.cpp

Untracked debug backups:

?? gui/gui.cpp.before-piano-render-debug
?? gui/pages.cpp.before-piano-debug
?? gui/pages.cpp.before-piano-render-debug

Current new validated source modification:

 M twrpApex.cpp

Do NOT reset/revert the old GUI/render modifications automatically.

Do NOT accidentally commit all bootable/recovery changes together.

The Build #23 APEX fix is preserved separately as:
~/piano-build23-apex-fd-fix.patch
```

## Fbe / Data Status

```text
FBE is intentionally PAUSED.

Current /data:

/dev/block/by-name/userdata
-> /dev/block/sda34

Filesystem:
F2FS

Encryption:

fileencryption=
aes-256-xts:aes-256-cts:v2+inlinecrypt_optimized+wrappedkey_v0

keydirectory=
/metadata/vold/metadata_encryption

metadata_encryption=
aes-256-xts:wrappedkey_v0

TWRP currently cannot mount/decrypt /data.

Known log:
Unable to find partition for path '/data'

Previous crypto experiments:

Full #22:
❌ early boot failure

Old #22A:
INVALID TEST because stale QCOM decrypt artifacts remained in generated output

Clean #22A:
❌ hardware early failure

Do NOT re-enable crypto flags yet.

Do NOT add:
TW_INCLUDE_CRYPTO
TW_INCLUDE_CRYPTO_FBE
TW_INCLUDE_FBE_METADATA_DECRYPT
BOARD_USES_QCOM_FBE_DECRYPTION
qcom_decrypt
qcom_decrypt_fbe

until explicitly returning to Stage 8.
```

## Current Roadmap

```text
1  Recovery boot                         ✅
2  GUI/framebuffer                       ✅
3  USB/ADB                               ✅
4  Touch hardware stack                  ✅
5  Landscape + touch mapping             ✅
6  Reboot / BCB / fastbootd              ✅

7  Partition / fstab / storage
   7A Physical paths                     ✅
   7B USB-OTG false match                ✅
   7C Real USB OTG                       ⏳

8  Android 16 FBE                        ⏸ PAUSED
9  /data PIN/password decryption         ⏸ depends on Stage 8

10 Dynamic partitions                    ✅
   super detection                       ✅
   logical dm mappings                   ✅
   active slot selection                 ✅
   EROFS recognition                     ✅
   logical partition read mounts         ✅
   additional vendor fstab cleanup       ✅ Build #22
   APEX loop integration                 ✅ Build #23

11 Backup / restore                      ⏳
12 ADB sideload / flashing               ← NEXT PRACTICAL TARGET
13 MTP                                   ⏳
14 Screen / suspend / power              ⏳
15 Battery / charging                    ⏳
16 Hardware buttons                      ⏳
17 Remaining reboot / EDL                ⏳
18 Fastbootd partition operations        ⏳
19 SELinux cleanup                       ⏳
20 Device-tree cleanup                   ⏳
21 Reproducible clean build              ⏳
22 Full test matrix                      ⏳
23 Stock fallback safety                 ⏳
24 Documentation                         ⏳
25 Release                               ⏳
```

## Remaining evidence-location gaps

The Build #23 patch is reported at `~/piano-build23-apex-fd-fix.patch` on the builder, outside the device-tree repository. Its contents, source commit base, and unrelated GUI diffs have not been imported or independently reviewed in this sync. A reproducible source manifest and durable patch/log archive remain pending. Do not infer that cloning the device tree alone reproduces Build #23. SSH connection details are not required for this local documentation task; no remote files were modified.
