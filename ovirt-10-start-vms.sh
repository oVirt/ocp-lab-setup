#!/bin/bash

. common_funcs

[[ -n "$KUBECONFIG" ]] || die "Need KUBECONFIG set"
[[ $# -eq 2 ]] || die "$0 <start> <how many>"

echo "Read ignition data"
tls=$(oc get -n openshift-machine-config-operator secret/machine-config-server-tls -o json | jq -r '.data."tls.crt"')
ignition="{
  \"ignition\": {
    \"config\": {
      \"merge\": [
        {
          \"source\": \"https://${BAREMETAL_OCP_API}:22623/config/worker\"
        }
      ]
    },
    \"security\": {
      \"tls\": {
        \"certificateAuthorities\": [
          {
            \"source\": \"data:text/plain;charset=utf-8;base64,${tls}\"
          }
        ]
      }
    },
    \"version\": \"3.2.0\"
  }
}"

echo "Start $2 worker VMs"
for i in $(seq $1 1 $(($1 - 1 + $2))); do

  nic=$(get_second_nic worker-$i | tr : -)
    # TODO Here we can create BMH entries..."
    echo "Start worker-$i"
    id=$(curl_api "/vms?search=name=worker-${i}" | sed -n "s/.*vm href.*id=\"\(.*\)\">/\1/p")
    curl_api "/vms/$id/start" -f -d "<action> <volatile>true</volatile> <use_ignition>true</use_ignition> <vm> <initialization><custom_script>${ignition}</custom_script></initialization> <os> <boot> <devices> <device>hd</device> </devices> </boot> </os> </vm> </action>"
    [[ $? -eq 0 ]] || { echo "Failed to run VM worker-$i"; exit 1; }
done
