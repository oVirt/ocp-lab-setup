#!/bin/bash

. common_funcs

[[ $# -eq 1 ]] || die "$0 <assisted installer iso name>\n  iso needs to be present on data domain already or \"\" to eject"
CDROM=$1

[[ "$CDROM" != "" ]] && {
    disk_id=$(curl_api "/disks?search=name=$CDROM" |  sed -n "s/.*disk href.*id=\"\(.*\)\">/\1/p")
    [[ "$disk_id" ]] || die "iso \"$CDROM\" has not been uploaded to storage domain"
}

vm_ids=$(for i in master worker; do curl_api "vms?search=name=${i}-*%20status=Down" | sed -n "s/.*vm href.*id=\"\(.*\)\">/\1/p"; done)
echo "Configure \"$CDROM\" for all down VMs ($(command echo $vm_ids | wc -w | tr -d ' '))"
for i in $vm_ids; do
    curl_api /vms/$i/cdroms/00000000-0000-0000-0000-000000000000 -X PUT -d "<cdrom> <file id=\"$disk_id\"/> </cdrom>"
done
