# Deploy Ops Manager Script

## Deploy OM

### Current Prerequisites

Copy the sample_init.conf to init.conf to set your specific values.  See the [README Configurationn Section](https://github.com/mongodb-Rock/OpsMgr-in-Kubernetes-and-Docker#configuration "Configure Ops Manager")

### Usage

This script can used directly or refer to the sample launch scripts.  If this script is executed directly, ensure your init.conf file is correct or your options passed to the script are proper before executing.  The launch scripts provide examples for usage as here are the options to run this script

```
./deploy_OM.bash -h
Usage: deploy_OM.bash [-n name] [-v omVersion] [-a appdbVersion] [-c cpu] [-m memory] [-d disk] [-g] [-t]
     use -t for k8s clusters with limited memory such as docker or minikube, etc br
```
