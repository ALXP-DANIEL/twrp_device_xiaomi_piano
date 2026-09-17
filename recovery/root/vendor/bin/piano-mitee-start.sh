#!/system/bin/sh
# Wait for the stock supplicant's MiTEE readiness, not qvirtmgr's VM creation
# status. Always publish a bounded fallback so absent Weaver cannot hang UI.
# This script never loads modules or accesses credentials.
STATUS_PROP=vendor.mitee_vm.boot_completed

i=0
while [ $i -lt 40 ]; do
    st=$(getprop "$STATUS_PROP")
    if [ "$st" = "1" ]; then
        log -t piano-mitee "MiTEE reported boot complete after ${i}s"
        setprop vendor.piano.vm.running 1
        exit 0
    fi
    sleep 1
    i=$((i + 1))
done

log -t piano-mitee "MiTEE readiness timed out; starting Weaver fallback"
setprop vendor.piano.vm.running 0
exit 1
