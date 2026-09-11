# Screen, suspend and charging — 2026-09-11

## Evidence and integration status

The maintainer-reported findings below supersede the Stage 12/14/15 status in the historical [Build #23 record](bringup-build23.md). No new image build number or hash was supplied for this milestone. Build #23 remains the last documented image identity, not proof of a clean-boot-tested permanent charging integration.

Stage 12 is complete only in the reported safe scope; the exact test payloads/operations were not supplied. Stage 14 is complete. Stage 15 has complete runtime proof, but the permanent bootstrap build and clean boot without manual ADB intervention remain pending. FBE stays paused.

Local inspection confirms the bootstrap script and init service are present. The script locates ADSP by name, mounts the selected modem partition read-only, copies missing ADSP files into recovery RAM, starts ADSP, waits for running state, and attempts to unmount. It leaves firmware_class.path unchanged and does not start CDSP/SOCCP.

Implementation details relevant to future review: an absent/unrecognized slot suffix currently falls back to `_a`; any non-running ADSP state reaches a start attempt (not only `offline`); individual copy failures are logged, with only the main `adsp.mdt` checked afterward; unmount errors are suppressed. These are observations of existing code, not changes or claims of failure. Validate the permanent integration before promoting it to an unattended known-good baseline. Slot-aware reads do not authorize slot-B testing.

No runtime files were changed and no build/device commands were executed during this documentation sync. The following is the supplied evidence record; its commands document prior tests and intended integration, not authorization to execute them.

---

# Xiaomi Pad 8 Pro (piano) TWRP Bring-up — Context Update
Date: 2026-09-11
Current target: TWRP 3.7.1_14-0 / Android 14 AP2A
Device: Xiaomi Pad 8 Pro (piano), Snapdragon 8 Elite / SM8750
Stock OS: HyperOS 3 Android 16, OS3.0.303.0.WPYMIXM

## IMPORTANT SAFETY RULES

- Experimental recovery partition: recovery_a ONLY.
- Do not touch recovery_b.
- Do not touch boot/vendor_boot/vbmeta for recovery bring-up.
- Do not switch to slot B.
- Do not blindly disable AVB.
- Do not erase whole misc.
- Preserve known-good touch/USB/display configuration.
- Firmware path `/odm/firmware/o8` is required by the working Novatek touch stack.
- Make one change at a time.

---

# STAGE 14 — SCREEN / SUSPEND / POWER

Stage 14 is now COMPLETE.

Validated:
- Screen off/on ✅
- Touch after wake ✅
- ADB after wake ✅
- Screen timeout ✅
- Panel suspend/resume ✅
- Touch suspend/resume ✅
- Full SoC deep suspend ✅
- RTC wake from deep suspend ✅

Kernel exposes:

    /sys/power/state:
    freeze mem disk

    /sys/power/mem_sleep:
    s2idle [deep]

`deep` is selected.

Previous deep-suspend failure while ADB/USB was connected:

    last_failed_dev=a600000.dwc3
    last_failed_errno=-16
    last_failed_step=prepare

-16 = EBUSY.

A clean USB-disconnected RTC test was performed.

Before:

    success=0
    fail=0

A delayed script:
1. armed rtc0 wakealarm for ~20 seconds,
2. USB was physically disconnected,
3. executed:

    echo mem > /sys/power/state

Result:

    Returned from suspend rc=0

After:

    success=1
    fail=0
    last_failed_dev=
    last_failed_errno=0
    last_failed_step=

Therefore:

    USB/ADB connected
        → DWC3 active
        → deep suspend prepare may return EBUSY

    USB physically disconnected
        → deep suspend succeeds
        → RTC successfully wakes tablet

Conclusion:
There is no demonstrated kernel/platform deep-suspend bug.
Do NOT disable or reset DWC3 just to force suspend while ADB is connected.
Stage 14 is finished.

---

# STAGE 15 — BATTERY / CHARGING

Stage 15 is now COMPLETE.

Validated:
- Battery percentage/reporting ✅
- Charger detection ✅
- Charging ✅
- Unplug transition ✅
- Replug transition ✅
- Temperature/health ✅
- Mac/USB host charging ✅
- CDP ✅
- PD ✅
- PD-PPS ✅
- Charging icon visible in TWRP ✅

## Original TWRP failure

Battery reporting worked, but charging did not.

Typical broken state:

    battery.status=Discharging
    usb.present=0
    usb.online=0
    real_type=Unknown

Relevant charger modules were already loaded, so this was NOT a missing-kernel-module problem.

TWRP also had working:
- DWC3 physical hotplug
- USB role switches

So USB-role theory was ruled out.

## Critical remoteproc discovery

TWRP initially had:

    remoteproc0 = SPSS
    remoteproc1 = ADSP
    remoteproc2 = CDSP
    remoteproc3 = SOCCP

ADSP/CDSP/SOCCP were offline.

Kernel log showed:

    Direct firmware load for adsp.mdt failed with error -2
    request_firmware failed: -2

and equivalent failures for cdsp.mdt and soccp.mbn.

`/sys/bus/rpmsg/devices` was empty.

PMIC GLINK DT children existed, but the actual child devices were missing.

This explained why charging never reached:

    pmic init done

and why qcom_subpmic continuously reported:

    Failed to read usb_online rc=-1

## Stock firmware layout

Stock `/vendor/etc/fstab.qcom` contains:

    /dev/block/bootdevice/by-name/modem
        /vendor/firmware_mnt
        vfat
        ro,...
        wait,slotselect

    /dev/block/bootdevice/by-name/dsp
        /vendor/dsp
        ext4
        ro,...
        wait,slotselect

On active slot A:

    modem_a = /dev/block/sde7
    dsp_a   = /dev/block/sde10

Manual read-only mounts proved:

    modem_a = VFAT
    dsp_a   = ext4

`modem_a/image` contains:

    adsp.mdt
    adsp.b00...
    adsp_dtb.mdt
    adsp_dtb.b00...
    cdsp.mdt
    cdsp.bXX
    cdsp_dtb.mdt
    soccp.mbn

## Important firmware-loader behavior

Kernel command line/current parameter:

    firmware_class.path=/odm/firmware/o8

This path MUST remain available because the working Novatek touch driver uses it.

Attempt 1:
Symlink ADSP files from mounted modem_a into `/odm/firmware/o8`.

Result:

    loading /odm/firmware/o8/adsp.mdt failed with error -13

-13 = EACCES.

The firmware loader did NOT accept the symlink setup.

Attempt 2:
Change `firmware_class.path` directly to mounted VFAT directory.

Result:

    loading /tmp/piano-modem/image/adsp.mdt failed with error -13

Also failed.

Attempt to mount modem_a using stock:

    context=u:object_r:firmware_file:s0

failed in TWRP with:

    Invalid argument

Therefore direct request_firmware access from the manually mounted VFAT path is not usable in the current recovery environment.

## PROVEN WORKING RUNTIME FIX

The working sequence is:

1. Mount active modem partition read-only.
2. Copy only ADSP firmware files into `/odm/firmware/o8` as REAL FILES.
3. Start ADSP remoteproc.
4. Firmware loader successfully loads ADSP.
5. Charging stack initializes.

Runtime proof:

Baseline:

    ADSP=offline
    battery=Discharging
    usb.online=0

Mount:

    mount -t vfat -o ro /dev/block/by-name/modem_a /tmp/piano-modem

Copy these from:

    /tmp/piano-modem/image/

into:

    /odm/firmware/o8/

Files copied:
- adsp.mdt
- adsp.b*
- adsp_dtb.mdt
- adsp_dtb.b*

~60 files total.

Then:

    echo start > /sys/class/remoteproc/remoteproc1/state

Result:

    ADSP=running

Kernel sequence:

    Booting fw image adsp.mdt, size 8364
    remote processor 3000000.remoteproc-adsp is now up
    mca_adsp_glink_probe: probe ok
    usb online: 1
    business_charger_process_pmic_init_done: pmic init done

Charging then became:

    battery.status=Charging
    usb.present=1
    usb.online=1

Examples observed:

Mac/data connection:

    real_type=CDP
    usb.voltage_now≈5.04V
    usb.current_now≈0.891A

Previously also validated:

    real_type=PD

and wall charger:

    real_type=PD_PPS

Hotplug transitions were validated:

    usb online 1
    → unplug
    usb online 0 / real_type 0
    → reconnect
    usb online 1 / PD or PD_PPS

The TWRP GUI also displays the charging symbol correctly.

## CONFIRMED ROOT CAUSE

The final causal chain is:

    modem firmware not exposed to request_firmware()
        ↓
    adsp.mdt unavailable
        ↓
    ADSP remoteproc remains offline
        ↓
    RPMSG ADSP endpoints absent
        ↓
    mca_adsp_glink cannot probe
        ↓
    PMIC GLINK initialization incomplete
        ↓
    no "pmic init done"
        ↓
    qcom_subpmic cannot obtain usb_online / charger type
        ↓
    no charging / PD / PPS in TWRP

Starting ADSP fixes the charging stack.

CDSP and SOCCP are NOT currently required for the charging fix.
Do not add/start them without evidence.

---

# PERMANENT CHARGING INTEGRATION CURRENTLY BEING ADDED

Do NOT package Qualcomm ADSP firmware blobs into recovery.img.

Reason:
- firmware already exists in modem_a
- recovery image has demonstrated size sensitivity
- unnecessary duplication

Permanent design:

    TWRP post-fs
        ↓
    tiny piano ADSP bootstrap script
        ↓
    detect active slot
        ↓
    mount modem_<slot> read-only
        ↓
    copy adsp* files into /odm/firmware/o8
        ↓
    start ADSP if offline
        ↓
    wait for ADSP running
        ↓
    unmount modem
        ↓
    mca_adsp_glink + charger stack initialize normally

Files currently added/modified:

    recovery/root/system/bin/piano-adsp-bootstrap.sh
    recovery/root/init.recovery.qcom.rc

Init addition:

    service piano_adsp_bootstrap /system/bin/sh /system/bin/piano-adsp-bootstrap.sh
        class core
        user root
        group root
        disabled
        oneshot
        seclabel u:r:recovery:s0

    on post-fs
        start piano_adsp_bootstrap

Existing touch post-fs block remains separately:

    on post-fs
        insmod /vendor/lib/modules/xiaomi_touch.ko
        insmod /vendor/lib/modules/nt36532_touch.ko
        start odm.touch_report

Multiple `on post-fs` blocks are acceptable.

The bootstrap script:
- finds the ADSP remoteproc dynamically
- exits if already running
- reads active slot suffix
- uses modem_a or modem_b accordingly
- mounts modem read-only
- never writes to modem partition
- copies only missing ADSP firmware files
- never overwrites existing recovery firmware
- starts ADSP
- waits for running state
- logs `[piano-adsp] ...` to /dev/kmsg
- unmounts the temporary modem mount

DO NOT:
- globally change firmware_class.path
- package the modem firmware into recovery.img
- add CDSP/SOCCP yet
- modify USB init
- modify touch init
- modify BoardConfig for this fix
- modify recovery_b/boot/vendor_boot/vbmeta

---

# CURRENT ROADMAP

1  Recovery boot                     ✅
2  GUI/framebuffer                   ✅
3  USB/ADB                           ✅
4  Touch hardware stack              ✅
5  Landscape + touch mapping         ✅
6  Reboot/BCB/fastbootd              ✅
7  Partition/fstab/storage
   physical paths                    ✅
   USB-OTG false match               ✅
   real USB-OTG test                 ⏳
8  Android 16 FBE                    ⏸ paused
9  /data PIN/password decryption     ⏸
10 Dynamic partitions                ✅
11 Backup/restore                    ⏳ /data limited
12 ADB sideload/flashing             ✅ safe scope
13 MTP                               ⏳ /data limited
14 Screen/suspend/power              ✅ COMPLETE
15 Battery/charging                  ✅ COMPLETE runtime proof
   permanent bootstrap integration   🔧 currently being integrated
16 Hardware buttons                  ⏳ next
17 Remaining reboot/EDL              ⏳
18 Fastbootd partition ops           ⏳
19 SELinux cleanup                   ⏳
20 Device-tree cleanup               ⏳
21 Reproducible clean build          ⏳
22 Full test matrix                  ⏳
23 Stock fallback safety             ⏳
24 Documentation                     ⏳
25 Release                           ⏳

Current priority:
1. Finish/verify permanent ADSP charging bootstrap build.
2. Test clean boot with no manual ADB intervention.
3. Confirm charging symbol + CDP/PD/PD-PPS still work.
4. Then proceed to Stage 16 hardware buttons.