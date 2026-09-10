DEVICE_PATH := device/xiaomi/piano

$(call inherit-product, $(DEVICE_PATH)/device.mk)

PRODUCT_DEVICE := piano
PRODUCT_NAME := twrp_piano
PRODUCT_BRAND := Xiaomi
PRODUCT_MODEL := Xiaomi Pad 8 Pro
PRODUCT_MANUFACTURER := Xiaomi

PRODUCT_RELEASE_NAME := piano
TARGET_OTA_ASSERT_DEVICE := piano
