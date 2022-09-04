#!/bin/bash
#
#
. common_funcs

[[ "$HOSTS" ]] || die "No hosts" 

echo "Create hook to pin VMs"
sed "s/__ENGINE__/$ENGINE/g;" hook-pin.template > hook-pin
chmod +x hook-pin
for i in $HOSTS; do
    $SCP hook-pin $i:/usr/libexec/vdsm/hooks/after_vm_start/hook-pin &
done
wait

echo "Setup local disk space on hosts"
for i in $HOSTS; do
	$SSH $i "
    [[ -r /vg ]] || dd if=/dev/zero of=/vg bs=1M count=0 seek=$LOCALDISK_VG_MB;
    echo \"#!/bin/bash\" > /etc/rc.local;
    echo \"losetup /dev/loop0 /vg\" >> /etc/rc.local;
    chmod +x /etc/rc.local;
    [[ \"\$(losetup -a | cut -d: -f1)\" == /dev/loop0 ]] || /etc/rc.local;
    lvmdevices --adddev /dev/loop0;
    sleep 5;
    pvdisplay -s /dev/loop0 || pvcreate /dev/loop0;
    vgdisplay ovirt-local -s || vgcreate ovirt-local /dev/loop0;
    lvdisplay ovirt-local/pool0 || lvcreate -l100%FREE --thinpool pool0 ovirt-local" &
done
wait
