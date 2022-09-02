#!/bin/bash

. common_funcs

[[ $# -lt 2 || "$1" == "remote" && "$#" -ne 3 ]] && die "$0 <local|remote> <assisted installer iso file name> [URL to download from, remotely]"
MODE=$1
ISO=$2
URL=$3

disk_id=$(curl_api "/disks?search=name=$ISO" |  sed -n "s/.*disk href.*id=\"\(.*\)\">/\1/p")
[[ "$disk_id" ]] && {
    echo "Detach from all VMs"
    vms=$(curl_api "/vms?follow=cdroms" | grep -B1 "<file id=\"$disk_id\"/>" | sed -n "s|.*vm href=\"\/ovirt-engine/api\(.*\)\"\ id.*|\1|p")
    for i in $vms; do
        curl_api "$i/cdroms/00000000-0000-0000-0000-000000000000" -X PUT -d "<cdrom> <file id=\"\"/> </cdrom>"
    done
    echo "Delete disk"
    curl_api "/disks/$disk_id" -f -X DELETE
    [[ $? -eq 0 ]] || die "Failed to remove previous ISO"
}

echo "Upload $MODE"
if [[ "$MODE" == "local" ]]; then
    curl -k -o ovirt-engine.pem "https://$ENGINE/ovirt-engine/services/pki-resource?resource=ca-certificate&format=X509-PEM-CA"
    echo "password" > ovirt-img.password
    ovirt-img upload-disk --engine-url https://$ENGINE --username admin@internal -s data --cafile=ovirt-engine.pem --password-file=ovirt-img.password --name="$ISO" "$ISO"
    rm -f ovirt-img.password
elif [[ "$MODE" == "remote" ]]; then
    $SSH $ENGINE "curl -f -o \"$ISO\" \"$URL\" || echo Download failed; echo password > ovirt-img.password"
    $SSH $ENGINE ovirt-img upload-disk --engine-url https://$ENGINE --username admin@internal -s data --cafile=/etc/pki/ovirt-engine/ca.pem --password-file=ovirt-img.password --name="$ISO" "$ISO"
    $SSH $ENGINE "rm -f $ISO ovirt-img.password"
fi
