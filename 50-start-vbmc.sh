#!/bin/bash


. common_funcs

[[ "$ENGINE" ]] || die "No engine" 

echo Clone oVirt vBMC project
$SSH $ENGINE "[[ -d vbmc ]] || { git clone https://github.com/oVirt/vbmc.git; pip3 install -r vbmc/requirements.txt; }"

echo "Generate IPMI inventory"
local_addrs=""
for i in  $(seq 1 1 $MASTERS) $(seq 1 1 $WORKERS); do
    next_ipmi
    local_addrs+="$IPMI_ADDRESS/16,"
    command echo "worker-$i,$IPMI_ADDRESS,623" >> bmc
done
$SCP bmc $ENGINE:vbmc/

echo "Define addresses"
$SSH $ENGINE "nmcli con mod baremetal +ipv4.addresses \"$local_addrs\""
reset_ipmi_address
$SSH $ENGINE "nmcli con up baremetal"

echo "Create vBMCs"
$SSH $ENGINE "vbmc/ovirtbmc.py --vm-inventory vbmc/bmc --engine-fqdn $ENGINE --engine-username admin@internal --engine-password password"
