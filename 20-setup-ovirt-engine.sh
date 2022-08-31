#!/bin/bash
#
#
. common_funcs

[[ "$ENGINE" ]] || die "No engine" 

echo "Create data SD share"
$SSH $ENGINE '
mkdir -p /srv/data;
chown 36:36 /srv/data;
chmod 775 /srv/data;
echo "/srv/data *(rw,insecure,no_root_squash)" > /etc/exports.d/data.exports;
exportfs -va;
systemctl enable nfs-server;
systemctl start nfs-server'

external_iface=$(cat engine | cut -d, -f2)
baremetal_iface=$(cat engine | cut -d, -f3)
baremetal_netmask=$(command echo $BAREMETAL_NET | cut -d/ -f2)

echo "Engine networking"
$SSH $ENGINE "
nmcli c mod $external_iface connection.zone external;
nmcli c mod $baremetal_iface connection.zone public;
firewall-cmd --permanent --zone=public --add-service=nfs --add-service=dhcp --add-service=dns;
firewall-cmd --permanent --zone=external --add-masquerade;
firewall-cmd --permanent --zone=external --add-service=https;
firewall-cmd --permanent --zone=external --add-port=6100/tcp;
firewall-cmd --reload;
nmcli c mod $baremetal_iface ipv4.addresses $BAREMETAL_ENGINE/$baremetal_netmask ipv4.method manual
route add -net $BAREMETAL_NET dev $baremetal_iface"

echo "Setup dnsmasq"
cat > dnsmasq.conf <<EOF
address=/.apps.${OCP_CLUSTER}.${OCP_DOMAIN}/${BAREMETAL_OCP_APPS}
dhcp-generate-names=$baremetal_iface
dhcp-ignore-names
dhcp-option=3,$BAREMETAL_ENGINE
dhcp-range=tag:${baremetal_iface},${BAREMETAL_DHCP_RANGE},1h
domain=${OCP_CLUSTER}.${OCP_DOMAIN}
expand-hosts
interface=$baremetal_iface
server=$($SSH $ENGINE 'grep ^nameserver /etc/resolv.conf | head -1 | cut -d" " -f2')
EOF
$SCP dnsmasq.conf $ENGINE:/etc/dnsmasq.d/lab.conf

$SSH $ENGINE "dnsmasq --test; systemctl enable dnsmasq; systemctl restart dnsmasq"

echo "Run engine-setup"
sed "s/__ENGINE__/$ENGINE/g; s/__ENGINE_DOMAIN__/$(command echo $ENGINE | cut -d. -f2-)/g" ovirt-engine-setup-answers.template > ovirt-engine-setup-answers
$SCP ovirt-engine-setup-answers $ENGINE:
$SSH $ENGINE "engine-setup --config-append=ovirt-engine-setup-answers"
$SSH $ENGINE "
engine-config -s ClientModeVncDefault=NoVnc; 
engine-config -s UserDefinedVMProperties='localdisk=^(lvm|lvmthin)$' --cver=4.7;
systemctl restart ovirt-engine"

echo "Roll engine key to hosts for Add Host"
$SSH $ENGINE "ssh-keygen -y -f /etc/pki/ovirt-engine/keys/engine_id_rsa > /etc/pki/ovirt-engine/keys/engine_id_rsa.pub"
$SSH $ENGINE "for i in $(command echo $HOSTS); do ssh-copy-id -i /etc/pki/ovirt-engine/keys/engine_id_rsa root@\$i & done; wait"
