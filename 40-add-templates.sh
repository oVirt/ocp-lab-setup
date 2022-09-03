#!/bin/bash
#
#
. common_funcs

[[ "$ENGINE" ]] || die "No engine" 

echo "Create template VMs"
sed "s/__MASTER_MEMORY__/$MASTER_MEMORY/g; s/__MASTER_CPUS__/$MASTER_CPUS/g" vm-master.template > vm-master
sed "s/__WORKER_MEMORY__/$WORKER_MEMORY/g; s/__WORKER_MEMORY_MIN__/$WORKER_MEMORY_MIN/g; s/__WORKER_CPUS__/$WORKER_CPUS/g" vm-worker.template > vm-worker
curl_api /vms -d "@vm-master"
curl_api /vms -d "@vm-worker"

baremetal_id=$(curl_api /vnicprofiles | grep -B1 "<name>baremetal</name>" | sed -n "s/.*vnic_profile href.*id=\"\(.*\)\">/\1/p")
provisioning_id=$(curl_api /vnicprofiles | grep -B1 "<name>provisioning</name>" | sed -n "s/.*vnic_profile href.*id=\"\(.*\)\">/\1/p")

for i in master worker; do
    id=$(curl_api "/vms?search=name=$i" | sed -n "s/.*vm href.*id=\"\(.*\)\">/\1/p") 

    curl_api /vms/$id/nics -d "<nic> <name>nic1</name> <vnic_profile id=\"$provisioning_id\"/> </nic>"
    curl_api /vms/$id/nics -d "<nic> <name>nic2</name> <vnic_profile id=\"$baremetal_id\"/> </nic>"

    curl_api /vms/$id/diskattachments -d "<disk_attachment> <bootable>true</bootable> <interface>virtio_scsi</interface> <disk> <format>cow</format> <sparse>true</sparse> <provisioned_size>$DISK_SIZE</provisioned_size> <storage_domains> <storage_domain> <name>data</name> </storage_domain> </storage_domains> </disk> </disk_attachment>"
    sleep 5
    
    while [[ "$(curl_api "/disks?search=status!=ok" | wc -l)" -gt 2 ]]; do sleep 10; done

    echo "Convert $i VM to ${i}_template"
    curl_api /templates -d "<template><name>${i}_template</name><vm id=\"${id}\"/></template>"
    rc=1
    while [[ "$rc" -ne 0 ]]; do sleep 5; curl_api "/vms/${id}" -f -X DELETE; rc=$?; done
done
