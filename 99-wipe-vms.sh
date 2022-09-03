#!/bin/bash
#
#
. common_funcs

[[ "$HOSTS" ]] || die "No hosts" 

echo "Delete all VMs"
mastervms=$(curl_api "/vms?search=name=master*" | sed -n "s/.*vm href.*id=\"\(.*\)\">/\1/p")
workervms=$(curl_api "/vms?search=name=worker*" | sed -n "s/.*vm href.*id=\"\(.*\)\">/\1/p")
for i in $mastervms $workervms; do
    curl_api "/vms/${i}" -f -X DELETE
    [[ "$?" -eq 0 ]] || die "failed to delete VM id $i"
done

echo "Wipe local storage on hosts"
for i in $HOSTS; do
	$SSH $i "
    wipes=\$(lvdisplay ovirt-local -c | grep -v ovirt-local/pool0 | cut -d: -f1);
    for i in \$wipes; do [[ -h \$i ]] && wipefs -a \$i; done;
    lvremove -y ovirt-local/pool0" &
done
wait

./30-setup-host-storage.sh
