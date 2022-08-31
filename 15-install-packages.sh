#!/bin/bash
#
#
. common_funcs

[[ $# == 1 ]] || die "$0 <RHV repo base>\ne.g. http://FQDN/builds/4.5/rhv-4.5.2-7/api"
REPO_API="$1"

for i in $ENGINE $HOSTS; do
    $SSH $i "
    [[ -x /root/clean-interfaces.sh ]] && /root/clean-interfaces.sh --nuke ;
    [[ -x /root/update-latest-rhel-release.sh ]] && /root/update-latest-rhel-release.sh 8.6 ;
    systemctl unmask firewalld ;
    dnf -y update" &
done
wait

echo "Install engine"
[[ "$ENGINE" ]] && $SSH $ENGINE "
	cd /etc/yum.repos.d ;
    curl -O $REPO_API/rhel_86_engine_x86.repo ;
    curl -O $REPO_API/rhv_45_engine.repo ;
    dnf module enable -y postgresql:12 pki-deps ;
    dnf install -y rhvm"

echo "Install hosts"
for i in $HOSTS; do
	$SSH $i "
    cd /etc/yum.repos.d ;
    curl -O $REPO_API/rhel_86_host_x86.repo ;
    curl -O $REPO_API/rhv_45_host.repo ;
    dnf install -y ovirt-host ;
    dnf install -y https://download.copr.fedorainfracloud.org/results/ovirt/ovirt-master-snapshot/centos-stream-8-x86_64/04763139-vdsm/vdsm-hook-localdisk-4.50.2.2-6.git66f31d6a5.el8.noarch.rpm" &
done
wait
echo "oVirt packages done"
