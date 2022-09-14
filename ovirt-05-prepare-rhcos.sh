#!/bin/bash

. common_funcs

[[ -n "$KUBECONFIG" ]] || die "Need KUBECONFIG set"
[[ "$1" == "remote" || "$1" == "local" ]] || die "$0 <local|remote>"
MODE=$1
DISK=rhcos.qcow2

url=$(oc get -n openshift-machine-config-operator cm/coreos-bootimages -o json | jq -r .data.stream | jq -r .architectures.x86_64.artifacts.openstack.formats.\"qcow2.gz\".disk.location)
disk_id=$(curl_api "/disks?search=name=$DISK" |  sed -n "s/.*disk href.*id=\"\(.*\)\">/\1/p")
[[ "$disk_id" ]] && {
#    echo "Detach from all VMs"
#    vms=$(curl_api "/vms?follow=cdroms" | grep -B1 "<file id=\"$disk_id\"/>" | sed -n "s|.*vm href=\"\/ovirt-engine/api\(.*\)\"\ id.*|\1|p")
#    for i in $vms; do
#        curl_api "$i/cdroms/00000000-0000-0000-0000-000000000000" -X PUT -d "<cdrom> <file id=\"\"/> </cdrom>"
#    done
    echo "Delete disk"
    curl_api "/disks/$disk_id" -f -X DELETE
    [[ $? -eq 0 ]] || die "Failed to remove previous disk $DISK"
}

echo "Upload $MODE"
if [[ "$MODE" == "local" ]]; then
    curl -k -o ovirt-engine.pem "https://$ENGINE/ovirt-engine/services/pki-resource?resource=ca-certificate&format=X509-PEM-CA"
    [[ -r "$DISK" ]] || {
        echo "Download $DISK from $url"
        curl -k "$url" | gunzip > $DISK
    }
    command echo "password" > ovirt-img.password
    ovirt-img upload-disk --engine-url https://$ENGINE --username admin@internal -s data --cafile=ovirt-engine.pem --password-file=ovirt-img.password --name="$DISK" "$DISK"
    rm -f ovirt-img.password
elif [[ "$MODE" == "remote" ]]; then
    $SSH $ENGINE "curl -f -k \"$url\" | gunzip > \"$DISK\" || echo Download failed; echo password > ovirt-img.password"
    $SSH $ENGINE ovirt-img upload-disk --engine-url https://$ENGINE --username admin@internal -s data --cafile=/etc/pki/ovirt-engine/ca.pem --password-file=ovirt-img.password --name="$DISK" "$DISK"
    $SSH $ENGINE "rm -f $DISK ovirt-img.password"
fi

echo "TODO - manually go and edit worker_template, replace its disk and attach $DISK instead(as bootable), and extend it to 100GB, then add more VMs"
