#!/bin/bash
#
#
. common_funcs

[[ "$ENGINE" ]] || die "No engine" 

echo "Create master VMs"
for i in $(seq 1 1 $MASTERS); do
    [[ "$(curl_api "/vms?search=name=master-${i}" | wc -l)" -gt 2 ]] && { echo "VM master-$i exists"; continue; }
    curl_api /vms -d "<vm> <name>master-${i}</name> <cluster> <name>Default</name> </cluster> <template> <name>master_template</name> </template> </vm>"
done

echo "Create worker VMs"
for i in $(seq 1 1 $WORKERS); do
    [[ "$(curl_api "/vms?search=name=worker-${i}" | wc -l)" -gt 2 ]] && { echo "VM worker-$i exists"; continue; }
    curl_api /vms -d "<vm> <name>worker-${i}</name> <cluster> <name>Default</name> </cluster> <template> <name>worker_template</name> </template> </vm>"
done
while [[ "$(curl_api "/disks?search=status!=ok" | wc -l)" -gt 2 ]]; do sleep 10; done
