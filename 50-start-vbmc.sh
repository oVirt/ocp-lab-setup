#!/bin/bash


. common_funcs

[[ "$ENGINE" ]] || die "No engine" 

echo "Create addresses"
local_addrs=""
for i in  $(seq 1 1 $MASTERS) $(seq 1 1 $WORKERS); do
    next_ipmi
    local_addrs+="$IPMI_ADDRESS/16,"
done
$SSH $ENGINE "nmcli con mod baremetal +ipv4.addresses \"$local_addrs\""
reset_ipmi_address
$SSH $ENGINE "nmcli con up baremetal"

echo "Create vBMCs"
for i in $(seq 1 1 $MASTERS); do
    next_ipmi
    [[ "$(curl_api "/vms?search=name=master-${i}" | wc -l)" -gt 2 ]] || die "VM master-$i missing"
    $SSH $ENGINE "./ovirtbmc.py --address $IPMI_ADDRESS --engine-fqdn $ENGINE --engine-username admin@internal --engine-password password --vm master-$i" &
done
for i in $(seq 1 1 $WORKERS); do
    next_ipmi
    [[ "$(curl_api "/vms?search=name=worker-${i}" | wc -l)" -gt 2 ]] || die "VM worker-$i missing"
    $SSH $ENGINE "./ovirtbmc.py --address $IPMI_ADDRESS --engine-fqdn $ENGINE --engine-username admin@internal --engine-password password --vm worker-$i" &
done
wait
