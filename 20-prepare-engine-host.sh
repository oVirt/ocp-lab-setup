#!/bin/bash
#
#
. common_funcs

[[ "$ENGINE" ]] || die "No engine" 

external_iface=$(cat engine | cut -d, -f2)
baremetal_iface=$(cat engine | cut -d, -f3)
baremetal_netmask=$(command echo $BAREMETAL_NET | cut -d/ -f2)
provisioning_iface=$(cat engine | cut -d, -f4)
provisioning_ip="$(command echo $PROVISIONING_NET | cut -d. -f1-3).1/$(command echo $PROVISIONING_NET | cut -d/ -f2)"

echo "Engine networking"
$SSH $ENGINE "
systemctl enable --now firewalld;
systemctl restart NetworkManager;
nmcli -g UUID,DEVICE c s | grep -v $external_iface | cut -d: -f1 | xargs nmcli c del;
nmcli c mod \$(nmcli -g UUID c) con-name external
nmcli c add type bridge ifname baremetal con-name baremetal;
nmcli c add type ethernet ifname $baremetal_iface con-name $baremetal_iface master baremetal;
nmcli c add type bridge ifname provisioning con-name provisioning;
nmcli c add type ethernet ifname $provisioning_iface con-name $provisioning_iface master provisioning;
nmcli c mod external connection.zone external;
nmcli c mod baremetal connection.zone public;
nmcli c mod baremetal ipv4.addresses $BAREMETAL_ENGINE/$baremetal_netmask ipv4.method manual;
nmcli c mod provisioning ipv4.addresses $provisioning_ip ipv4.method manual;
nmcli c mod external ipv4.ignore-auto-dns yes ipv6.ignore-auto-dns yes ipv4.dns-search perf-test.example.com;
nmcli c up baremetal;
nmcli c up provisioning;
nmcli c up external;
firewall-cmd --permanent --zone=public --add-service=dhcp --add-service=dns;
firewall-cmd --permanent --zone=public --add-port=623/udp
firewall-cmd --permanent --zone=external --add-service=nfs;
firewall-cmd --permanent --zone=external --add-masquerade;
firewall-cmd --permanent --zone=external --add-service=https;
firewall-cmd --permanent --zone=external --add-port=6100/tcp;
firewall-cmd --reload;"

echo "Setup dnsmasq"
cat > dnsmasq.conf <<EOF
address=/api.${OCP_CLUSTER}.${OCP_DOMAIN}/${BAREMETAL_OCP_API}
address=/.apps.${OCP_CLUSTER}.${OCP_DOMAIN}/${BAREMETAL_OCP_APPS}
read-ethers
dhcp-ignore-names
dhcp-option=3,$BAREMETAL_ENGINE
dhcp-range=tag:baremetal,${BAREMETAL_DHCP_RANGE},1h
domain=${OCP_CLUSTER}.${OCP_DOMAIN}
expand-hosts
interface=baremetal
server=$($SSH $ENGINE 'nmcli -f DHCP4.OPTION con s external | sed -n "s/.* domain_name_servers = \(.*\)/\1/p" | cut -d " " -f1')
EOF
$SCP dnsmasq.conf $ENGINE:/etc/dnsmasq.d/lab.conf

$SSH $ENGINE "dnsmasq --test; systemctl enable dnsmasq; systemctl restart dnsmasq"

echo "Create data SD share"
$SSH $ENGINE '
mkdir -p /srv/data;
chown 36:36 /srv/data;
chmod 775 /srv/data;
echo "/srv/data *(rw,insecure,no_root_squash)" > /etc/exports.d/data.exports;
exportfs -va;
systemctl enable nfs-server;
systemctl start nfs-server'
