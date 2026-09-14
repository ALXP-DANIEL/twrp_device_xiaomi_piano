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

# Stock HyperOS 3 KeyMint HAL service, packaged unmodified as
# /vendor/bin/hw/piano-keymint. One process hosts IKeyMintDevice,
# IRemotelyProvisionedComponent, ISecureClock and ISharedSecret.
#
# SHA-256 bc3c6361a7d3e67385d1001f56891e1b49094ae9243530e05dc9a2c7c6acbd91
include $(CLEAR_VARS)
LOCAL_MODULE := piano_keymint
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_STEM := piano-keymint
LOCAL_SRC_FILES := prebuilt/keymint-service-qti
LOCAL_MODULE_PATH := $(TARGET_RECOVERY_ROOT_OUT)/vendor/bin/hw
LOCAL_MULTILIB := 64
LOCAL_STRIP_MODULE := false
LOCAL_CHECK_ELF_FILES := false
include $(BUILD_PREBUILT)

# Stock HyperOS 3 Gatekeeper HAL.
# SHA-256 c66d485ff028a8ca7185f302e11d9ee846ffcc71b3cf9ce3bd9b0f7cf868728b
include $(CLEAR_VARS)
LOCAL_MODULE := piano_gatekeeper
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_STEM := piano-gatekeeper
LOCAL_SRC_FILES := prebuilt/gatekeeper-service-qti
LOCAL_MODULE_PATH := $(TARGET_RECOVERY_ROOT_OUT)/vendor/bin/hw
LOCAL_MULTILIB := 64
LOCAL_STRIP_MODULE := false
LOCAL_CHECK_ELF_FILES := false
include $(BUILD_PREBUILT)

# Stock HyperOS 3 Xiaomi Weaver HAL (miweaver).
#
# Its only odm-private dependency is libmi_weaver.so, which resolves from the
# read-only odm view at /vendor/piano-stock-odm. The transport is not a
# separate GlobalPlatform driver: libmi_weaver -> libGPTEE_vendor dlopens
# libGPMTEEC_vendor (Qualcomm TZComWrap), which is the same smcinvoke/Mink
# path qseecomd and KeyMint use.
#
# SHA-256 7b8974bef8e944f3cfc52659924e8d9e9beef1ae29dc43c2780c83e410af659c
include $(CLEAR_VARS)
LOCAL_MODULE := piano_weaver
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_STEM := piano-weaver
LOCAL_SRC_FILES := prebuilt/weaver-service
LOCAL_MODULE_PATH := $(TARGET_RECOVERY_ROOT_OUT)/vendor/bin/hw
LOCAL_MULTILIB := 64
LOCAL_STRIP_MODULE := false
LOCAL_CHECK_ELF_FILES := false
include $(BUILD_PREBUILT)

# Stock HyperOS 3 Qualcomm GlobalPlatform trusted-application loader, packaged
# unmodified as /vendor/bin/piano-ssgtzd.
#
# SHA-256 d52f5ef5fd7dc40b9fa622f97b430552cb223771dd15f258be54bb871372ac1e
#
# Weaver is a GP TA rather than a QSEE listener, so qseecomd alone cannot reach
# it. This daemon loads the TA from the modem partition, which init mounts
# read-only at /vendor/firmware_mnt. Without it TEEC_OpenSession fails and TWRP
# never gets as far as checking the credential.
#
# It is packaged into the ramdisk rather than run from the stock vendor mount so
# that it carries a label this policy defines. Files on the mounted stock
# partition keep stock's own xattrs, including types such as vendor_ssgtzd_exec
# which do not exist here, and no domain transition would happen.
#
# ELF dependency checking is disabled for the same reason as the other four: it
# links the stock vendor runtime, resolved from /vendor/piano-stock/lib64.
include $(CLEAR_VARS)
LOCAL_MODULE := piano_ssgtzd
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_STEM := piano-ssgtzd
LOCAL_SRC_FILES := prebuilt/ssgtzd
LOCAL_MODULE_PATH := $(TARGET_RECOVERY_ROOT_OUT)/vendor/bin
LOCAL_MULTILIB := 64
LOCAL_STRIP_MODULE := false
LOCAL_CHECK_ELF_FILES := false
include $(BUILD_PREBUILT)
