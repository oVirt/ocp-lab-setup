#!/bin/bash

. common_funcs

[[ -r pull-secret.txt ]] || die "Please create pull-secret.txt"

get_first_nic() {
    curl_api "/vms?search=name=${1}&follow=nics" | tr -d "\n" | sed 's|^.*<nics>||g; s|</nics>.*$||g' | sed -n 's|^.*<name>nic1</name>.*<address>\(.*\)</address>.*<name>nic2</name>.*|\1|p'
}

echo "Render install-config.yaml"
sshkey=$($SSH $ENGINE 'cat /root/.ssh/id_rsa.pub')
pull=$(cat pull-secret.txt)
sed "s|__OCP_DOMAIN__|$OCP_DOMAIN|g;
    s|__OCP_CLUSTER__|$OCP_CLUSTER|g;
    s|__BAREMETAL_NET__|$BAREMETAL_NET|g;
    s|__PROVISIONING_NET__|$PROVISIONING_NET|g;
    s|__MASTERS__|$MASTERS|g;
    s|__WORKERS__|$WORKERS|g
    s|__BAREMETAL_OCP_API__|$BAREMETAL_OCP_API|g;
    s|__BAREMETAL_OCP_APPS__|$BAREMETAL_OCP_APPS|g;
    s|__PULL_SECRET__|$pull|g;
    s|__SSH_KEY__|$sshkey|g;" install-config.yaml.template > install-config.yaml

for i in $(seq 1 $MASTERS); do
    next_ipmi
	cat >> install-config.yaml <<EOF
      - name: master-$i
        role: master
        bootMACAddress: $(get_first_nic master-$i)
        bmc:
          address: ipmi://$IPMI_ADDRESS
          username: admin
          password: password
        rootDeviceHints:
         deviceName: "/dev/sda"
EOF
done
for i in $(seq 1 $WORKERS); do
    next_ipmi
	cat >> install-config.yaml <<EOF
      - name: worker-$i
        role: worker
        bootMACAddress: $(get_first_nic worker-$i)
        bmc:
          address: ipmi://$IPMI_ADDRESS
          username: admin
          password: password
        rootDeviceHints:
         deviceName: "/dev/sda"
EOF
done
