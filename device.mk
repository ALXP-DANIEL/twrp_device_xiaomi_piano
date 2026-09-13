DEVICE_PATH := device/xiaomi/piano

$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/emulated_storage.mk)
$(call inherit-product, vendor/twrp/config/common.mk)

PRODUCT_USE_DYNAMIC_PARTITIONS := true


PRODUCT_SOONG_NAMESPACES += \
    $(DEVICE_PATH)

# Recovery init
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/recovery/root/init.recovery.qcom.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.qcom.rc


# Recovery USB
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/recovery/root/init.recovery.usb.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.usb.rc

# Task profiles. Without this logd aborts in libprocessgroup during
# startup and there is no logcat at all in recovery, which hides every
# userspace SELinux denial raised by servicemanager.
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/recovery/root/system/etc/task_profiles.json:$(TARGET_COPY_OUT_RECOVERY)/root/system/etc/task_profiles.json

# Recovery ueventd rules
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/recovery/root/vendor/etc/ueventd.rc:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/etc/ueventd.rc

# HyperOS 3 Android 16 compatibility libraries for stock qseecomd
PRODUCT_PACKAGES += \
    piano_qsee_compat_libapexsupport \
    piano_qsee_compat_libvndksupport \
    piano_qsee_compat_liblog

# Recovery device VINTF manifest declaring the secure AIDL HALs.
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/recovery/root/vendor/etc/vintf/manifest.xml:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/etc/vintf/manifest.xml

# Stock HyperOS 3 qseecomd, installed as /vendor/bin/piano-qseecomd
PRODUCT_PACKAGES += \
    piano_qseecomd

# Stock HyperOS 3 KeyMint HAL, installed as /vendor/bin/hw/piano-keymint
PRODUCT_PACKAGES += \
    piano_keymint
