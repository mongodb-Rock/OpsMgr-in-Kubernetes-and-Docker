# Launch OM Bash Script

## Launch Ops Manager

### Current Prerequisites

These can be change based on the system needs, as of right now you will need the following installed;

* cfssl
* cfssljson
* kubectl

A ready cluster is needed for exectution.   `kubectl api-resources` should have a return.

Cope the sample_init.conf to init.conf and set the appropriate values.  See the [README Configuration Section](https://github.com/mongodb-Rock/OpsMgr-in-Kubernetes-and-Docker#configuratio "Configure Ops Manager")

### Usage

The Ops Manager launch script will deploy the Operator, Ops Manager, and if the backup is configured it will also deploy clusters for the backup Op Log and Backup BlockStore DB for OM.  See the [Launch Clusters Script README](https://github.com/mongodb-Rock/OpsMgr-in-Kubernetes-and-Docker/blob/master/scripts_launch_Clusters.md "Launch Clusters") for more information on cluster launching.

After the init.conf has had all it's values updated to meet the needs of the system, and all  prerequisites are met the following command maybe exectued from the ./k8s directory.

```
./_launch_OM.bash
```

This will deploy the operator then install ops manager and install any backup requirements noted in the init.conf.
