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

# Recovery ueventd rules
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/recovery/root/vendor/etc/ueventd.rc:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/etc/ueventd.rc

# HyperOS 3 Android 16 compatibility libraries for stock qseecomd
PRODUCT_PACKAGES += \
    piano_qsee_compat_libbinder \
    piano_qsee_compat_libbinder_ndk \
    piano_qsee_compat_libapexsupport \
    piano_qsee_compat_libvndksupport \
    piano_qsee_compat_liblog

# Stock HyperOS 3 qseecomd, installed as /vendor/bin/piano-qseecomd
PRODUCT_PACKAGES += \
    piano_qseecomd
