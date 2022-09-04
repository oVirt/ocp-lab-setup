#!/bin/bash

. common_funcs

[[ $# -eq 2 ]] || die "$0 <start> <how many>"

echo "Create $2 BMHs"
for i in $(seq 1 $MASTERS) $(seq 1 1 $1); do next_ipmi; done

for i in $(seq $1 1 $(($1 - 1 + $2))); do
	$SSH $ENGINE "
export KUBECONFIG=/home/kni/clusterconfigs/auth/kubeconfig;
oc -n openshift-machine-api create -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: worker-$i-bmc-secret
  namespace: openshift-machine-api
type: Opaque
data:
  username: YWRtaW4=
  password: cGFzc3dvcmQ=
---
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: worker-$i
  namespace: openshift-machine-api
spec:
  online: true
  bootMACAddress: $(get_first_nic worker-$i)
  bmc:
    address: ipmi://${IPMI_ADDRESS}
    credentialsName: worker-$i-bmc-secret
    disableCertificateVerification: true
    username: admin
    password: password
EOF
"
	next_ipmi
done
