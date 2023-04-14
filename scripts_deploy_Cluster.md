# Deploy Cluster Script

## Deploy Cluster

### Current Prerequisites

There are a few command-line tools that must be installed such as:

* cfssl
* cfssljson
* kubectl

A Kubernetes or Openshift cluster is needed for exectution.  You can check the availability by running:  `kubectl api-resources` should return output without error.

Copy the sample_init.conf to init.conf to set your specific values.  See the [README Configurationn Section](https://github.com/mongodb-Rock/OpsMgr-in-Kubernetes-and-Docker#configuration "Configure Ops Manager")

### Usage

This script can used directly or refer to the sample launch scripts.  If this script is executed directly, the Ops Manager referenced should be up. the deploy_org.bash will allow you to put resources into specific Organizations and Projects.  If TLS certs are used, the ./certs/[gen|make]*.bash files should be updated to meet the TLS / Certificate requirements for the system.  The launch scripts provide examples for usage as here are the options to run this script

```
./k8s/deploy_Cluster.bash -h

Usage: deploy_Cluster.bash 
[-n name] 
[-c cpu] 
[-m memory] 
[-d disk] 
[-v ver] 
[-e ] 
[-s shards] 
[-r mongos] 
[-l ldap[s]] 
[-o orgId] 
[-p projectName] 
[-g] 
[-x]
Usage:       -e to generate the splitHorizon configuration for the Replica Set
Usage:       -x for total clean up before (re)deployment
Usage:       -g to not recreate the TLS certificates
Usage:       -l to enable LDAP for DB users
Usage:       -n the name of the of the resouce
Usage:       -c the number of cores per node
Usage:       -m the memory (GB) per node
Usage:       -d the storage (GB) per node
Usage:       -v the version of MongoDB to deploy
Usage:       -o the name of the org to use (default is name of the resource)
Usage:       -p the name of the project to use (default is the name of the resource)
```
