#!/system/bin/sh
#
# Wait until the virtualization service reports trustedvm started, then publish
# one property. That is all this script does: init performs the privileged
# work (loading the MiTEE module) from the property trigger, so the script
# needs no module-loading rights, no /proc access and no capabilities.
#
# Why the wait exists: mitee_dlkm probes the secure world the moment it loads,
# and if the guest is not up it gives up without ever retrying.
#
#   [ 2.03] mitee msgq: msgq didn't set up, try later
#   [ 2.03] mitee smc notify connect failed
#   [21.06] gunyah_loader: Use allocated CMA memory for trustedvm
#
# Nineteen seconds too early. Weaver then fails every session with
# "openSession ret=15" even with the guest running correctly -- verified on
# hardware, trustedvm_vcpu0/vcpu1 alive and Weaver still refusing.
#
# The order cannot be corrected afterwards: rmmod blocks indefinitely while a
# TEE client holds the driver and wedges the kernel. Reproduced twice. So the
# module has to be late on its first and only load.
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
