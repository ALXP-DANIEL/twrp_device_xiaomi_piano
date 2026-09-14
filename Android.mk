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

# Stock HyperOS 3 HLOS Mink daemon, packaged unmodified as
# /vendor/bin/piano-minkdaemon.
#
# SHA-256 e8396f14435f7300847e74e05b326b3ebe4e328c33c9589573b602b5ec279efd
#
# This is the HLOS Mink opener. Xiaomi's Weaver reaches its trusted application
# through MiTEE, not through QSEE: libmi_weaver -> libGPTEE_vendor ->
# libGPMTEEC_vendor -> libminksocket_vendor. Without this daemon serving the
# HLOSMINKD interface, libGPMTEEC_vendor cannot open the TA session and Weaver
# fails with "openSession ret=11", so TWRP never reaches the credential.
#
# Found by way of MissMyTime/TWRP-Xiaomi, whose nezha notes record the same
# failure - metadata decryption succeeding, then "failed while querying Weaver
# key size" - and identify the HLOS Mink opener as the missing piece. Nothing in
# this device's own logs names it.
#
# ELF dependency checking is disabled for the same reason as the others: it
# links the stock vendor runtime, resolved from /vendor/piano-stock/lib64.
include $(CLEAR_VARS)
LOCAL_MODULE := piano_minkdaemon
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_STEM := piano-minkdaemon
LOCAL_SRC_FILES := prebuilt/hlosminkdaemon
LOCAL_MODULE_PATH := $(TARGET_RECOVERY_ROOT_OUT)/vendor/bin
LOCAL_MULTILIB := 64
LOCAL_STRIP_MODULE := false
LOCAL_CHECK_ELF_FILES := false
include $(BUILD_PREBUILT)

# Stock Qualcomm virtualization service, packaged unmodified as
# /vendor/bin/piano-qvirt-service.
#
# SHA-256 bcc03258a6d597695322e4c21f88aced910da15fac31c044ebb06c3feffbb711
#
# This is what actually starts MiTEE. Xiaomi's secure world does not live in
# QSEE and is not loaded by the bootloader for this boot path: it is a Gunyah
# guest VM named "trustedvm", declared in the device tree as
# soc/gh-secure-vm-loader@0 (vmid 45, firmware-name "trustedvm") and started
# from userspace by this service, whose config
# /vendor/etc/qvirtmgr-vndr.json carries "autostart": true for it.
#
# Nothing in recovery ever started it, so mitee_dlkm.ko came up with no secure
# world to talk to:
#   mitee msgq: msgq didn't set up, try later
#   mitee smc notify connect failed
# and every Weaver session failed at the transport, first as openSession ret=11
# and, once the driver was loaded, as ret=15.
#
# ELF dependency checking is disabled for the same reason as the others: it
# links the stock runtime.
include $(CLEAR_VARS)
LOCAL_MODULE := piano_qvirt_service
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_STEM := piano-qvirt-service
LOCAL_SRC_FILES := prebuilt/qvirt-service
LOCAL_MODULE_PATH := $(TARGET_RECOVERY_ROOT_OUT)/vendor/bin
LOCAL_MULTILIB := 64
LOCAL_STRIP_MODULE := false
LOCAL_CHECK_ELF_FILES := false
include $(BUILD_PREBUILT)

# The AIDL interface library the service links against. It ships on the stock
# product partition, which recovery has no reason to keep mounted, so it is
# packaged into the ramdisk beside the service.
#
# SHA-256 b72f0dcfbdf578074f38ea2cd6c126d0dc6f53e0d2a8c3148f3ef8d1a9ef94ac
include $(CLEAR_VARS)
LOCAL_MODULE := piano_qvirt_ndk
LOCAL_MODULE_CLASS := SHARED_LIBRARIES
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_STEM := vendor.qti.qvirt-V1-ndk.so
LOCAL_SRC_FILES := prebuilt/vendor.qti.qvirt-V1-ndk.so
LOCAL_MODULE_PATH := $(TARGET_RECOVERY_ROOT_OUT)/vendor/lib64
LOCAL_MULTILIB := 64
LOCAL_STRIP_MODULE := false
LOCAL_CHECK_ELF_FILES := false
include $(BUILD_PREBUILT)

# The VM configuration the service reads. Copied unmodified from the stock
# vendor partition; "trustedvm" is enabled and autostarts, "oemvm" is not.
include $(CLEAR_VARS)
LOCAL_MODULE := piano_qvirtmgr_conf
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_STEM := qvirtmgr-vndr.json
LOCAL_SRC_FILES := prebuilt/qvirtmgr-vndr.json
LOCAL_MODULE_PATH := $(TARGET_RECOVERY_ROOT_OUT)/vendor/etc
include $(BUILD_PREBUILT)
