# Launch Clusters Script

## Launch Clusters

### Current Prerequisites

These can be change based on the system needs, as of right now you will need the following installed;

* cfssl
* cfssljson
* kubectl

A ready cluster is needed for exectution.   `kubectl api-resources` should have a return.

Cope the sample_init.conf to init.conf and set the appropriate values.  See the [README Configuration Section](https://github.com/mongodb-Rock/OpsMgr-in-Kubernetes-and-Docker#configuratio "Configure Ops Manager")

### Usage

This script is for an easy launch using the configuation provided in the init.conf file.  When doing this the scripts will first run another script which will deploy the Orginization the cluster will be in.  This calls a script in the ./k8s/bin directory calll `deploy_org.bash` and will use the settings in the init.conf set for `orgName`.  If the org does not exist it will create it, if it already exists it will grab the org id to use in the cluster creation.  The following command maybe exectued from the ./k8s directory.

```
./_launch_Clusters.bash
```

This will deploy a mongodb cluster.  This command executes the [deploy_Cluster.bash script](https://github.com/mongodb-Rock/OpsMgr-in-Kubernetes-and-Docker/blob/master/scripts_deploy_Cluster.md "Deploy Cluster").
