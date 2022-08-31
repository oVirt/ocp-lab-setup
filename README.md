# set up oVirt/RHV in a perf lab

There are many assumptions based on Red Hat's Perf&Scale labs

## Design
oVirt setup with VMs running OCP cluster using isolated networks
- 1 physical host installed with oVirt Engine, hosting dnsmasq for OCP network, routing to external networks, hosting NFS for VM initialization
- n-1 physical hosts installed as oVirt hosts, using vdsm-hook-localdisk for local storage. Storage is initialized when VM starts on a host for the first time, then it's reused. VMs need to be pinned to their original host.
- OCP "baremetal" network running dnsmasq, routed through the engine host to public
- OCP "provisioning" network for PXE baremetal provisioning

## Prerequisities
- set of machines with bare RHEL 8.6 installed
- inventory service returning json:
```
{
    "nodes": [
        {
            "pm_addr": "mgmt-FQDN",
        }
    ]
}
```
- 1 external interface for connectivity, 2 interfaces connected to all hosts without DHCP, for OCP's baremetal and provisioning networks.
- interfaces need to be mapped from the inventory host names. Adjust in 05-get-inventory.sh or just create the right mapping yourself by creating files _engine_ and _hosts_ with
```
 <fqdn>,<external_iface>,<baremetal_iface>,<provisioning_iface>
 ```

## Steps
can be run individually for troubleshooting/reinstalls
- process inventory json and extract the first node as the engine host and the rest as oVirt hosts
- setup ssh keys (executor->engine+hosts, new engine key, engine->hosts)
- upgrade to 8.6, install packages
- _insert reboot_
- set up engine hosts's networking and install oVirt engine
- set up local storage on hosts
- add oVirt hosts
- add master and worker templates
- create all individual VMs

## Missing
for Assisted Installer flow
- document discovery iso upload
- attach discovery CD
- start VMs

for IPI flow
- create install-config.yaml
- baremetal installer specific setup
- start vBMCs 

