#!/bin/bash

. common_funcs

[[ "$ENGINE" ]] || die "No engine" 

echo "Run engine-setup"
sed "s/__ENGINE__/$ENGINE/g; s/__ENGINE_DOMAIN__/$(command echo $ENGINE | cut -d. -f2-)/g" ovirt-engine-setup-answers.template > ovirt-engine-setup-answers
$SCP ovirt-engine-setup-answers $ENGINE:
$SSH $ENGINE "engine-setup --config-append=ovirt-engine-setup-answers --accept-defaults"
$SSH $ENGINE "
engine-config -s ClientModeVncDefault=NoVnc; 
engine-config -s UserDefinedVMProperties='localdisk=^(lvm|lvmthin)$' --cver=4.7;
systemctl restart ovirt-engine"

echo "Roll engine key to hosts for Add Host"
$SSH $ENGINE "ssh-keygen -y -f /etc/pki/ovirt-engine/keys/engine_id_rsa > /etc/pki/ovirt-engine/keys/engine_id_rsa.pub"
$SSH $ENGINE "for i in $(command echo $HOSTS); do ssh-copy-id -i /etc/pki/ovirt-engine/keys/engine_id_rsa root@\$i & done; wait"
