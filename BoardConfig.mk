DEVICE_PATH := device/xiaomi/piano

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := generic

# Platform
TARGET_BOARD_PLATFORM := sun
TARGET_NO_BOOTLOADER := true

# Recovery image
BOARD_BOOT_HEADER_VERSION := 4
BOARD_KERNEL_PAGESIZE := 4096
BOARD_RAMDISK_USE_LZ4 := true

# Stock recovery.img is ramdisk-only.
# The active boot-slot supplies the kernel.
BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 104857600

# A/B
AB_OTA_UPDATER := true

AB_OTA_PARTITIONS := \
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

# Filesystems
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true

# Metadata
BOARD_USES_METADATA_PARTITION := true

# Recovery
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery.fstab

# Dynamic partition / fastbootd support
TW_INCLUDE_FASTBOOTD := true

# Debug during bring-up
TARGET_USES_LOGD := true
TWRP_INCLUDE_LOGCAT := true
