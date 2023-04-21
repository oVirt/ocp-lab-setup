#!/bin/bash
#
#
. common_funcs

[[ "$ENGINE" ]] || die "No engine" 

add_dns() {
    local nic=$(get_second_nic $1)
    $SSH $ENGINE "
        sed -i \"/.* $1/d\" /etc/ethers
        command echo \"${nic} $1\" >> /etc/ethers"
}

echo "Create master VMs"
for i in $(seq 1 1 $MASTERS); do
    [[ "$(curl_api "/vms?search=name=master-${i}" | wc -l)" -gt 2 ]] && { echo "VM master-$i exists"; continue; }
    curl_api /vms -d "<vm> <name>master-${i}</name> <cluster> <name>Default</name> </cluster> <template> <name>master_template</name> </template> </vm>"
    add_dns master-$i
done

echo "Create worker VMs"
for i in $(seq 1 1 $WORKERS); do
    [[ "$(curl_api "/vms?search=name=worker-${i}" | wc -l)" -gt 2 ]] && { echo "VM worker-$i exists"; continue; }
    curl_api /vms -d "<vm> <name>worker-${i}</name> <cluster> <name>Default</name> </cluster> <template> <name>worker_template</name> </template> </vm>"
    add_dns worker-$i
done

if [[ $# -gt 1 && "numa" == $(echo "$1" | tr '[:upper:]' '[:lower:]') && $2 -gt 0 ]]; then
   echo "Create multi-NUMA VMs"

   NUMA_NODES=$2
   NUMA_MEMORY=$(($WORKER_MEMORY / $NUMA_NODES)) # total memory (i.e. for 16GB and 4 nodes, 4GB for each NUMA)

   for j in $(seq 1 $NUMA_NODES); do
      curl_api vms/$id/numanodes -X POST -d "<vm_numa_node><cpu><cores><core><index>$j</index></core></cores></cpu><index>$j</index><memory>$NUMA_MEMORY</memory></vm_numa_node>"
   done
else
   echo "Create multi-NUMA VMs Failed: ./45-add-vms.sh NUMA|numa <# NUMA nodes>"
fi

# reread /etc/ethers
$SSH $ENGINE "pkill -HUP dnsmasq"

# wait for VMs to be ready
while [[ "$(curl_api "/disks?search=status!=ok" | wc -l)" -gt 2 ]]; do sleep 10; done
