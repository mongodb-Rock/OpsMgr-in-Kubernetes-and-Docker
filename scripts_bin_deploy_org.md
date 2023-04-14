# Deploy Orginization

## Deploy Org	

### Current Prerequisites

Copy the sample_init.conf to init.conf to set your specific values.  See the [README Configurationn Section](https://github.com/mongodb-Rock/OpsMgr-in-Kubernetes-and-Docker#configuration "Configure Ops Manager")

Ops Manager is up and running.

### Usage

This script can used directly or refer to the sample launch scripts.  If this script is executed directly, the Ops Manager referenced should be up and running.  The deploy_org.bash will allow you to put resources into specific Organizations and Projects.  The deploy orginization script allows the creation of an orginization and addition of a user to that orginization.

```
./bin/deploy_org.bash -h
Usage: deploy_org.bash -o orgName -u user [-h]
```

These can be called by other scripts and set in the init.conf, or you can run it directly to create new orgs or add users to existing orgs.ß
