#!/bin/bash

. common_funcs

[[ $# -eq 2 ]] || die "$0 <start> <how many>"

echo "Start $2 worker VMs"
for i in $(seq $1 1 $(($1 - 1 + $2))); do
    echo "Start worker-$i"
    id=$(curl_api "/vms?search=name=worker-${i}" | sed -n "s/.*vm href.*id=\"\(.*\)\">/\1/p")
    curl_api "/vms/$id/start" -d "<action> <volatile>true</volatile> <vm> <os> <boot> <devices> <device>cdrom</device> </devices> </boot> </os> </vm> </action>"
done
