# Deploy Cluster Script

## Deploy Cluster

### Current Prerequisites

These can be change based on the system needs, as of right now you will need the following installed;

* cfssl
* cfssljson
* kubectl

A ready cluster is needed for exectution.   `kubectl api-resources` should have a return.

Cope the sample_init.conf to init.conf and set the appropriate values.  See the [README Configuration Section](https://github.com/mongodb-Rock/OpsMgr-in-Kubernetes-and-Docker#configuratio "Configure Ops Manager")

### Usage

This script can be called directly or from the easy launch scripts.  If this script is executed directly Ops Manager should be up and running and the deploy_org.bash script should of already been executed, either diretcly or from the use of a _lauch script.  If certs are to be used the ./certs/[gen|make]*.bash files should be updated to meet the TLS / Certificate requirements for the system.  Lets take a look at the options for this script.  Also the launch scripts can be looked at for good examples on how to 

```
./k8s/deploy_Cluster.bash -h

Usage: deploy_Cluster.bash 
[-n name] 
[-c cpu] 
[-m memory] 
[-d disk] 
[-v ver] 
[ -e ] 
[-s shards] 
[-r mongos] 
[-l ldap[s]] 
[-o orgId] 
[-p projectName] 
[-g] 
[-x]
Usage:       -e to generate the splitHorizon configuration for the Replica Set
Usage:       -x for total clean up before (re)deployment
Usage:       -g to not recreate the certs
```
