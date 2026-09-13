LOCAL_PATH := $(call my-dir)

# HyperOS 3 Android 16 compatibility island for the stock Qualcomm qseecomd.
#
# These modules intentionally keep unique build module names while preserving
# their original SONAME filenames in the recovery ramdisk.
#
# ELF dependency checking is disabled per-module because these are foreign
# Android 16 prebuilts loaded against the separately mounted stock vendor
# runtime. Their complete runtime closure is verified separately with linker64.

PIANO_QSEE_COMPAT_OUT := $(TARGET_RECOVERY_ROOT_OUT)/vendor/piano-stock-qsee-system/lib64

include $(CLEAR_VARS)
LOCAL_MODULE := piano_qsee_compat_libbinder
LOCAL_MODULE_CLASS := SHARED_LIBRARIES
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_STEM := libbinder.so
LOCAL_SRC_FILES := recovery/root/vendor/piano-stock-qsee-system/lib64/libbinder.so
LOCAL_MODULE_PATH := $(PIANO_QSEE_COMPAT_OUT)
LOCAL_MULTILIB := 64
LOCAL_STRIP_MODULE := false
LOCAL_CHECK_ELF_FILES := false
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE := piano_qsee_compat_libbinder_ndk
LOCAL_MODULE_CLASS := SHARED_LIBRARIES
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_STEM := libbinder_ndk.so
LOCAL_SRC_FILES := recovery/root/vendor/piano-stock-qsee-system/lib64/libbinder_ndk.so
LOCAL_MODULE_PATH := $(PIANO_QSEE_COMPAT_OUT)
LOCAL_MULTILIB := 64
LOCAL_STRIP_MODULE := false
LOCAL_CHECK_ELF_FILES := false
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE := piano_qsee_compat_libapexsupport
LOCAL_MODULE_CLASS := SHARED_LIBRARIES
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_STEM := libapexsupport.so
LOCAL_SRC_FILES := recovery/root/vendor/piano-stock-qsee-system/lib64/libapexsupport.so
LOCAL_MODULE_PATH := $(PIANO_QSEE_COMPAT_OUT)
LOCAL_MULTILIB := 64
LOCAL_STRIP_MODULE := false
LOCAL_CHECK_ELF_FILES := false
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE := piano_qsee_compat_libvndksupport
LOCAL_MODULE_CLASS := SHARED_LIBRARIES
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_STEM := libvndksupport.so
LOCAL_SRC_FILES := recovery/root/vendor/piano-stock-qsee-system/lib64/libvndksupport.so
LOCAL_MODULE_PATH := $(PIANO_QSEE_COMPAT_OUT)
LOCAL_MULTILIB := 64
LOCAL_STRIP_MODULE := false
LOCAL_CHECK_ELF_FILES := false
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE := piano_qsee_compat_liblog
LOCAL_MODULE_CLASS := SHARED_LIBRARIES
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_STEM := liblog.so
LOCAL_SRC_FILES := recovery/root/vendor/piano-stock-qsee-system/lib64/liblog.so
LOCAL_MODULE_PATH := $(PIANO_QSEE_COMPAT_OUT)
LOCAL_MULTILIB := 64
LOCAL_STRIP_MODULE := false
LOCAL_CHECK_ELF_FILES := false
include $(BUILD_PREBUILT)

PIANO_QSEE_COMPAT_OUT :=

# Untouched stock HyperOS 3 Android 16 qseecomd.
PIANO_QSEE_BIN_OUT := $(TARGET_RECOVERY_ROOT_OUT)/vendor/bin

include $(CLEAR_VARS)
LOCAL_MODULE := piano_qseecomd
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_STEM := piano-qseecomd
LOCAL_SRC_FILES := prebuilt/qseecomd
LOCAL_MODULE_PATH := $(PIANO_QSEE_BIN_OUT)
LOCAL_MULTILIB := 64
LOCAL_STRIP_MODULE := false
LOCAL_CHECK_ELF_FILES := false
include $(BUILD_PREBUILT)

PIANO_QSEE_BIN_OUT :=

