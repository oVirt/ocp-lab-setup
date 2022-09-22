# Walkthrough 

This is a walkthrough for the OCP worker on VMs project, that can be found here: [ocp-lab-setu]() https://github.com/oVirt/ocp-lab-setup)
It is meant to result in 3 bare-metal OCP masters and a large number of virtual-machine based workers. The actual number depends on the resources you have 
available in the RHV cluster that's set up as part of this walkthrough. The default is to have 3 virtual masters and 10 virtual workers though.

## Setting up the environment

### Adjusting variables required for the installation

Configure the number of masters and or workers you want to deploy as VMs in `common_funcs`:
**MASTERS=0
WORKERS=200**

The name in `common_funcs` needs to match the name you give your OCP cluster:
**OCP_CLUTER="perfscale3"
OCP_DOMAIN="example.com"**


### Get an inventory
```
./05-get-inventory.sh <URL_TO_OCP_INVENTORY_FILE>
```
We removed the first 5 entries, since we need those hosts as masters and infra nodes which resulted in the `hosts` file.
It is important to make sure that the interfaces are interconnected - adjust the name-based mapping in 05-get-inventory.sh or edit manually if that's necessary

We need to distribute our public key so we can work on the nodes without the need to authenticate every time. Make sure it uses the correct key in case you have more than just one in the user's .ssh directory.

```
./10-ssh-keys.ssh
```
This copies your ssh key ~/.ssh/id_rsa.pub key to the nodes in the `engine` and `hosts` file.

Now we need to install the required packages on all the nodes, the engine as well as the VM hosts:
```
./15-install-packages.sh <REPO_URL>
[LAB] Install engine
...
[LAB] Install hosts
...
[LAB] oVirt packages done
```

No longer needed:
~~**Make sure to reboot the nodes after this step!**~~

```bash
for i in $(cat engine) $(cat hosts); do ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=quiet -o User=root $i reboot; done
```


The next step takes care of network configuration, dnsmasq for RHV and the SD data share. If you want to set a cluster name different to the default of *perfscale*, please do so in the **common_funcs** file. Also make sure the domain is set correctly. This information relates to the name and domain you set in your OCP cluster.

```bash
./20-prepare-engine-host.sh
[LAB] Engine networking
Connection 'Wired connection 1' (71dece5b-b869-3b20-90a9-b1393dabf91e) successfully deleted.
Connection 'Wired connection 2' (b60e47bd-bcb1-366d-94c7-c6ac6570a1c2) successfully deleted.
Connection 'Wired connection 3' (7315ca38-fb52-39ad-80aa-2339c22dcb39) successfully deleted.
Connection 'baremetal' (6c139a32-acf9-4b9b-82fe-9cc77a42ada5) successfully added.
Connection 'ens2f0' (78ca32a3-da33-4784-b3e8-5727d12faf95) successfully added.
Connection 'provisioning' (ece02a74-a81c-4a35-adc2-332c1c94a143) successfully added.
Connection 'ens2f1' (1e177e0d-24aa-4791-a2c0-4a676bc755a1) successfully added.
Connection successfully activated (master waiting for slaves) (D-Bus active path: /org/freedesktop/NetworkManager/ActiveConnection/9)
Connection successfully activated (master waiting for slaves) (D-Bus active path: /org/freedesktop/NetworkManager/ActiveConnection/11)
Connection successfully activated (D-Bus active path: /org/freedesktop/NetworkManager/ActiveConnection/13)
success
success
success
success
Warning: ALREADY_ENABLED: masquerade
success
success
success
[LAB] Setup dnsmasq
dnsmasq.conf                                                                                                                                100%  300     2.2KB/s   00:00
dnsmasq: syntax check OK.
Created symlink /etc/systemd/system/multi-user.target.wants/dnsmasq.service → /usr/lib/systemd/system/dnsmasq.service.
[LAB] Create data SD share
exporting *:/srv/data
Created symlink /etc/systemd/system/multi-user.target.wants/nfs-server.service → /usr/lib/systemd/system/nfs-server.service.
```

Let's get the engine set up:
```bash
./25-setup-ovirt-engine.sh
[LAB] Run engine-setup
...
```

Plus the storage:
```bash
./30-setup-host-storage.sh
[LAB] Create hook to pin VMs
...
  Logical volume "pool0" created.
...
[LAB] Add data SD
...
[LAB] Attach data SD to Default DC
...
[LAB] Wait for DC to be up
...
```

Add the hypervisor hosts. Make sure you don't have any duplicates in the hosts file!
```bash
./35-add-ovirt-hosts.sh
```

Add the templates to the RHV. If required, modify the vm-worker.template according to your needs first. 
```bash
./40-add-templates.sh
```

In case you need access to the RHV WebUI for further customization, the address is in the **engine** file, and the credentials are **admin / password**

## OCP cluster
Now's the time to install the OCP cluster on the 5 nodes we spared out initially. Head over to [cloud.redhat.com](https://cloud.redhat.com) and set up a BM cluster.
In step 5 on that UI, you need to set the VIP and the API like this:

**API			10.100.0.1
VIP		    10.100.0.2**

The name for the cluster should be identical to the one in `common_funcs.sh`:
**OCP_CLUSTER="perfscale"
OCP_DOMAIN="example.com"**

Once the OCP cluster is up and running, I installed the latest `oc` package from [oc source](https://access.redhat.com/downloads/content/290/ver=4.11/rhel---8/4.11.5/x86_64/product-software) on the engine host, or any other host that can reach the cluster via the `API` address. 
Make sure to have the kubeconfig downloaded to that host.

## Get the VMs to work

Once that's done, add the templates to the RHV engine:
```bash
./40-add-templates.sh
```
and create the VMs:
```bash
./45-add-vms.sh
```

The VMs need to boot from a discovery ISO image in order to register with `cloud.redhat.com`. Follow the steps there to `Add Hosts` and upload the resulting ISO to the RHV engine with:
```bash
./ai-05-upload-iso.sh remote worker.iso "<URL_FOR_THE_ISO>"
```
This will upload a remote image to the engine, calling it worker.iso there, downloading it from URL_FOR_THE_ISO. The URL needs to be quoted, since it contains special characters.
The next step is to attach the ISO to all VMs that are in the state `Down`, using
```bash
./ai-10-attach-iso.sh worker.iso
```

Finally, we can boot the VMs, ideally in batches smaller or equal 50 VMs.
```bash
./ai-15-start-vms.sh 1 50
```

When the nodes are done booting, they will show up in the cloud UI at [cloud.redhat.com](https://cloud.redhat.com) under the `Add Hosts` tab for the corresponding cluster. 
Click the `Install ready hosts` button and make sure to approve the certificate signing requests (CSRs) on the masters, using this command:
```bash
for c in $(oc get csr --no-headers | grep -i pending | awk '{ print $1 }' ); do oc adm certificate approve $c; done
```

