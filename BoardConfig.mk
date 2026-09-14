#
# TWRP 16 / Android 16 device configuration for the Xiaomi Pad 8 Pro (piano).
#
# Written for the native Android-16 base, not ported from the TWRP14 tree. The
# TWRP14 configuration stays frozen at device/xiaomi/piano in ~/android/twrp-14
# and is referenced only for hardware facts that were proven on the device.
#
# ALLOW_MISSING_DEPENDENCIES — enabled deliberately, with a compensating gate.
#
# The TWRP manifest is a reduced AOSP checkout: it ships projects whose Soong
# dependencies live in projects it omits, and Soong parses every Android.bp in
# the tree regardless of build target. Removing the unneeded consumers was
# tried first and diverged: 32 errors -> 20 -> 26, and removing
# packages/modules/Connectivity broke system/netd, which recovery links through
# libnetd_client. AOSP projects cross-reference too heavily for that approach
# to terminate.
#
# The risk this flag carries is real: a module our recovery actually needs
# could be silently skipped instead of failing the build. That risk is
# answered by a mandatory ELF closure audit of the produced ramdisk before any
# image is flashed - every binary and shared library is resolved and any
# unresolved DT_NEEDED fails the gate. See docs/twrp16-first-image-elf-audit.md.
#
# This flag does not affect this device tree's own dependencies, which resolve
# completely. BUILD_BROKEN_* is still NOT set.
ALLOW_MISSING_DEPENDENCIES := true

DEVICE_PATH := device/xiaomi/piano

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := generic

# Bootloader / platform
PRODUCT_PLATFORM := sun
TARGET_BOOTLOADER_BOARD_NAME := $(PRODUCT_PLATFORM)
TARGET_NO_BOOTLOADER := true
TARGET_BOARD_PLATFORM := sun

# Recovery image geometry.
#
# Stock piano recovery is ramdisk-only: kernel_size is 0 and the active boot
# slot supplies the kernel. Header v4, 4096-byte pages, legacy LZ4 ramdisk.
BOARD_BOOT_HEADER_VERSION := 4
BOARD_KERNEL_PAGESIZE := 4096
# Ramdisk compression: legacy LZ4. Do not change this.
#
# Tested on hardware 2026-09-14: a gzip ramdisk BOOTLOOPS at the splash screen.
# The device never enumerates USB in any mode and has to be forced into
# fastboot by hand.
#
# The kernel config is not sufficient evidence here. /proc/config.gz reports
# CONFIG_RD_GZIP=y, CONFIG_RD_LZ4=y and CONFIG_RD_ZSTD=y, so the kernel can
# decompress all three - but the bootloader hands the image to the kernel and
# evidently requires the legacy LZ4 format that stock recovery ships. Every
# image that has ever booted on this device uses it.
#
# This also rules out zstd, which would otherwise have been very attractive:
#
#   lz4 legacy -12  28,905,980 bytes    (boots)
#   gzip -9         24,931,569 bytes    (BOOTLOOPS)
#   zstd -19        17,107,486 bytes    (untested, same risk, not worth it)
#
# The size budget must therefore be met by content, not compression.
BOARD_RAMDISK_USE_LZ4 := true

BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 104857600
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE)

# The recovery uses the active-slot ROM kernel, so no kernel is built or
# packaged. No prebuilt kernel is carried, unlike the reference trees.
TARGET_NO_KERNEL_OVERRIDE := true

# RECOVERY RAMDISK SIZE BUDGET — hard constraint, see
# docs/twrp14-frozen-reference.md.
#
# The piano bootloader refuses to load a recovery whose compressed ramdisk
# exceeds a measured bound bracketed to 29,210,310 bytes (boots) and
# 29,228,841 bytes (fails). Over that, the device returns to fastboot and
# marks slot A unbootable without ever executing the ramdisk. Probable cause
# is a shared load region: stock vendor_boot declares a 25.556 MiB vendor
# ramdisk, and the Qualcomm loader checks the region against the sum of the
# recovery and vendor ramdisks.
#
# Budget every image against 29,000,000 bytes to keep margin. This is why no
# WLAN module, no prebuilt kernel and no stock HAL payload are packaged here.

# A/B
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS += \
    boot \
    dtbo \
    init_boot \
    odm \
    product \
    recovery \
    system \
    system_dlkm \
    system_ext \
    vbmeta \
    vbmeta_system \
    vendor \
    vendor_boot \
    vendor_dlkm

# Dynamic partitions
BOARD_SUPER_PARTITION_SIZE := 13958643712
BOARD_SUPER_PARTITION_GROUPS := qti_dynamic_partitions
BOARD_QTI_DYNAMIC_PARTITIONS_SIZE := 13948157952
BOARD_QTI_DYNAMIC_PARTITIONS_PARTITION_LIST := \
    odm \
    product \
    system \
    system_dlkm \
    system_ext \
    vendor \
    vendor_dlkm

# Verified boot. AVB stays enabled; it is never disabled to make an image boot.
BOARD_AVB_ENABLE := true

# Filesystems
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
BOARD_USES_METADATA_PARTITION := true

# Partition mount points
TARGET_COPY_OUT_VENDOR := vendor

# SELinux. Enforcing is a requirement, never relaxed to make a stage pass.
BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/vendor

# Recovery
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery.fstab
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888

# Display / input, proven on hardware in the TWRP14 tree.
TW_THEME := landscape_hdpi

# Backlight.
#
# This panel's range is 0-4095 (/sys/class/backlight/panel0-backlight/
# max_brightness). TWRP assumes a maximum of 255 when TW_MAX_BRIGHTNESS is
# unset, so its "full brightness" landed at 255/4095 - about 6% - and the
# screen was barely readable. Observed in recovery.log as
# "Set_Brightness: Setting brightness control to 255".
TW_BRIGHTNESS_PATH := /sys/class/backlight/panel0-backlight/brightness
TW_MAX_BRIGHTNESS := 4095
TW_DEFAULT_BRIGHTNESS := 2048
RECOVERY_TOUCHSCREEN_SWAP_XY := true
RECOVERY_TOUCHSCREEN_FLIP_Y := true

# Device-specific Qualcomm USB ConfigFS setup replaces TWRP's default.
TW_EXCLUDE_DEFAULT_USB_INIT := true

# Stock vendor fstab contains a duplicate unsupported mifs /data entry.
TW_SKIP_ADDITIONAL_FSTAB := true

# Dynamic partition / fastbootd support
TW_INCLUDE_FASTBOOTD := true

# Size discipline. Both public SM8750 reference trees set this; it removes the
# stock-APEX loading integration. It is not a blanket "remove all APEX"
# switch, so the ELF closure is verified separately.
TW_EXCLUDE_APEX := true

# Bring-up logging
TARGET_USES_LOGD := true
TWRP_INCLUDE_LOGCAT := true

# Crypto is intentionally OFF for the first image. Do not enable until the
# Phase 7S safety invariants have been ported and verified against this
# tree's system/vold revision, and until the image still fits the size budget
# above. See docs/twrp16-migration-progress.md.
