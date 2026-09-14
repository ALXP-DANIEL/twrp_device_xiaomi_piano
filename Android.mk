LOCAL_PATH := $(call my-dir)

# Stock HyperOS 3 Qualcomm TEE daemon, packaged unmodified as
# /vendor/bin/piano-qseecomd.
#
# SHA-256 dc1ccdd0a32891f0f38048383499e8849e071840ef5bb210eefa1b0e3b2c369f
#
# ELF dependency checking is disabled for this module because it links against
# the stock vendor runtime, which is mounted read-only at /vendor/piano-stock
# at runtime rather than packaged into the ramdisk.
include $(CLEAR_VARS)
LOCAL_MODULE := piano_qseecomd
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_STEM := piano-qseecomd
LOCAL_SRC_FILES := prebuilt/qseecomd
LOCAL_MODULE_PATH := $(TARGET_RECOVERY_ROOT_OUT)/vendor/bin
LOCAL_MULTILIB := 64
LOCAL_STRIP_MODULE := false
LOCAL_CHECK_ELF_FILES := false
include $(BUILD_PREBUILT)
