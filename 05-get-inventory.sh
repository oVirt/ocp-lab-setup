#!/bin/bash
. common_funcs

URL="$1"
[[ "$URL" ]] || die "$0 <ocpinventory.json URL>\n  Creates engine,hosts: <fqdn>,<external_iface>,<baremetal_iface>,<provisioning_iface>"

render_line() {
    local ifaces=
    [[ "$1" =~ -fc640\. ]] && ifaces="eno1,ens2f0,ens2f1"
    [[ "$1" =~ e23-h12-.*-fc640\. || "$i" =~ e23-h24-.*-fc640\. ]] && ifaces="eno1,eth3,eth2"
    [[ "$1" =~ -r640\. ]] && ifaces="eno1np0,ens1f1,ens2f0"
    [[ "$1" =~ -740xd\. ]] && ifaces="eno3,ens7f0,ens7f1"
    [[ "$ifaces" ]] || die "No networking match for $i"
    command echo "$i,$ifaces"
}

echo Engine:
i=$(curl -s "$URL" | jq -r ".nodes[0].pm_addr" | sed s/mgmt-//)
render_line $i | tee engine

echo Hosts:
>hosts
for i in $(curl -s "$URL" | jq -r ".nodes[1:] | .[].pm_addr" | sed s/mgmt-//g); do
   render_line $i | tee -a hosts
done
