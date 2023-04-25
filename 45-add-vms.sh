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

NUMA_NUM=$1
function add_numa {
  local i=$1
  [[ "$NUMA_NUM" ]] && NUMA_MEMORY=$(( $WORKER_MEMORY / $NUMA_NUM / 1024 / 1024 ))

  echo "Enable multi-NUMA worker-$i"
  NUMA_NODES=$((NUMA_NUM-1))
  id=$(curl_api "/vms?search=name=worker-${i}" | sed -n "s/.*vm href.*id=\"\(.*\)\">/\1/p")
  for j in $(seq 0 $NUMA_NODES); do 
       curl_api vms/$id/numanodes -X POST -d "<vm_numa_node><cpu><cores><core><index>$j</index></core></cores></cpu><index>$j</index><memory>$NUMA_MEMORY</memory></vm_numa_node>"
  done
}

echo "Create worker VMs"
for i in $(seq 1 1 $WORKERS); do
    [[ "$(curl_api "/vms?search=name=worker-${i}" | wc -l)" -gt 2 ]] && { echo "VM worker-$i exists"; continue; }
    curl_api /vms -d "<vm> <name>worker-${i}</name> <cluster> <name>Default</name> </cluster> <template> <name>worker_template</name> </template> </vm>"
    add_dns worker-$i
    if [ -n "$NUMA_NUM" ]; then
        add_numa $i
    fi
done

# reread /etc/ethers
$SSH $ENGINE "pkill -HUP dnsmasq"

# wait for VMs to be ready
while [[ "$(curl_api "/disks?search=status!=ok" | wc -l)" -gt 2 ]]; do sleep 10; done
