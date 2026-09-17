#!/system/bin/sh
#
# Wait until the virtualization service reports trustedvm started, then publish
# one property. That is all this script does: init performs the privileged
# work (loading the MiTEE module) from the property trigger, so the script
# needs no module-loading rights, no /proc access and no capabilities.
#
# Why the script exists: Weaver's start must wait for the guest, but must also
# fire on timeout so TWRP's credential path cannot block forever. The script
# polls the VM status property and publishes readiness; init starts Weaver from
# the trigger.
#
#   [ 2.03] mitee msgq: msgq didn't set up, try later
#   [ 2.03] mitee smc notify connect failed
#
# These init-time lines appear on stock too and are transient, not a failure:
# stock loads mitee_dlkm at 2.06s, BEFORE its VM starts at 13.16s, and the RM
# notifier then receives the label-5 queue capabilities as VM 45 starts. A
# module loaded only after RUNNING misses that one-shot notification. The
# module is loaded before the VM service now (see init.recovery.qcom.rc) and
# is never unloaded: rmmod wedges the kernel while a TEE client holds it.
#
# An earlier version of this script looked for qcrosvm's vcpu threads in
# /proc. That needed to read other domains' process entries, which a platform
# neverallow forbids (domain.te:1238), so it reads the service's own status
# property instead. qvirtservice publishes NOT_STARTED while the VM is down
# and replaces it once the guest is up.

STATUS_PROP=vendor.qvirtmgr.trustedvm.status

i=0
while [ $i -lt 40 ]; do
    st=$(getprop $STATUS_PROP)
    if [ -n "$st" ] && [ "$st" != "NOT_STARTED" ]; then
        log -t piano-mitee "trustedvm reported '$st' after ${i}s"
        setprop vendor.piano.vm.running 1
        exit 0
    fi
    sleep 1
    i=$((i + 1))
done

log -t piano-mitee "trustedvm never left NOT_STARTED; MiTEE driver not loaded"
setprop vendor.piano.vm.running 0
exit 1
