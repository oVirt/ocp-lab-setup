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

echo "Create hook to reboot stuck VMs"
for i in $HOSTS; do
    $SCP hook-reboot $i:/usr/libexec/vdsm/hooks/before_vm_start/hook-reboot &
done
wait

echo "Make vdsm wait longer for initial disk copy"
for i in $HOSTS; do
    $SCP longer-prepare-image.conf $i:/etc/vdsm/vdsm.conf.d/longer-prepare-image.conf &
done
wait

echo "Setup local disk space on hosts"
for i in $HOSTS; do
    $SSH $i "
    if [[ $WHOLE_DISK ]]; then
      # try dm first
      MPATH=\$(lsblk /dev/$WHOLE_DISK -o NAME -l | tail -1);
      DEV=/dev/mapper/\$MPATH;
      # fall back to bare block device
      [ -b \$DEV ] || DEV=/dev/$WHOLE_DISK
    else
      DEV=/dev/loop0
      [[ -r /vg ]] || dd if=/dev/zero of=/vg bs=1M count=0 seek=$LOCALDISK_VG_MB;
      echo \"#!/bin/bash\" > /etc/rc.local;
      echo \"losetup \$DEV /vg\" >> /etc/rc.local;
      chmod +x /etc/rc.local;
      [[ \"\$(losetup -a | cut -d: -f1)\" == \$DEV ]] || /etc/rc.local;
      lvmdevices --adddev \$DEV;
      sleep 5;
      pvdisplay -s \$DEV || pvcreate \$DEV;
    fi
    vgdisplay ovirt-local -s || { pvcreate -ff -y \$DEV; vgcreate -y ovirt-local \$DEV; };
    lvdisplay ovirt-local/pool0 || lvcreate -l100%FREE --thinpool pool0 ovirt-local" &
done
wait
