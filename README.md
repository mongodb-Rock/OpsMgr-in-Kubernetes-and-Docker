# OpsMgr K8s Openshift

## Summary:

- These scripts will install MongoDB and Ops Manager into a Kubernetes/Openshift cluster:
  * Ops Manager v6
    * the appDB cluster
    * a blockstore cluster for PIT backups
    * an oplog cluster for support of continous backups
- Sample Production Clusters (DBs)
  * a replica set cluster
  * a sharded cluster
  * TLS Certs are created using a self-signed CA or customer provided CA.
  * Queriable backup is available too!

### Step 1. Create or login to an Openshift/K8s Cluster

- To run a small production workload, a cluster with the following resources is needed:

  * Openshift/Kubernetes cluster typical resources:
    * Configure 32 Cores
    * Configure 128GB of Memory
    * Disk 500GB-4000TB

### Step 2. Launch the Services

the **_launch.bash** script runs several "deploy" scripts for each of the following steps:

- Script 1: **deploy_Operator.bash**

  - Setup the OM environment
  - Defines the namespace
  - Deploys the MongoDB Enterprise K8s Operator
  - Deploys the optional cert-manager

- Script 2: **deploy_OM.bash**

  - Setup the Ops Manager (OM) environment
  - Deploy the OM Resources
    - Ops Manager 
    - AppDB
  - Monitors the progress of OM for readiness
- Script 3: **deploy_Database.bash** and **deploy_DatabaseSharded.bash**

  - Deploy a Cluster (DB) - several clusters are created
  - Oplog1 and Blockstore1 Clusters complete the Backup setup for OM
  - myreplicaset is a "Production" DB and has a splitHorizon configuration for external cluster access
    - connect via ``bin/connect_external.bash`` script
  - the script monitors the progress of the deployment until the pods are ready

### Step 3. Login to Ops Manager

- login to OM at https://opsmgr.mydomain.com:8443
- the admin user credentials are set in ``init.conf``
  - the script also creates a hostname entry such as:
    ``192.168.x.x       opsmanager-svc.mongodb.svc.cluster.local opsmgr.mydomain.com``
    into the ``/etc/hosts`` file
  - Note: if you add the self-signed TLS certificate authority (certs/ca.crt) to your keystore, this allows seamless unchallenged secure https access

## Configuration

Under the ./k8s/ dir you will find a sample_init.conf file that contains the configuration settings for your deployment.  After making changes to this file you'll rename it to init.conf and use it in the deployments.

### Copy sample_init.conf

To get started copy the sample_init.conf to init.conf, as follows:
`cp sample_init.conf init.conf`

### NameSpace and the Issuer

Next you will change the following lines to meet your namespace needs and to whom is deploying this cluster.

```
export namespace="mynamespace" # edit this to change the namespace for this deployment
export issuerName="myissuer" # edit this to change the issuer for this deployment
```

So here you would validate the namespace and issuerNames are correct for this deployment.

### Cluster Type and Version

These scripts can be built to run on different cluster types, such as kubernetes and openshift.  Openshift's commands are very similar to that of straight kubernetes so little to no changes are needed in most cases.  In addition to the type and versions, in this section you will name your OpsManager.

```
clusterType="openshift" 
omName="opsmanager"
omVersion="6.0.11"
appdbVersion="5.0.14-ent"
mdbVersion="6.0.4-ent"
mongoshVersion="1.8.0"
```

Update this section to the appropriate versions for you deployment.

### Default Size for OM

Here you set your CPU and memory requirements.

```
omcpu="4.00"
ommemlim="16Gi"
ommemreq="8Gi"
```

### Backup Daemon Sizing

Make sure you have enough disk space for you backups if this is enabled.

```
bdcpu="4.00"
bdmemlim="16Gi"
bdmemreq="8Gi"
bddsk="100Gi"
```

### Some Deployment Options

This section sets up the use of TLS and if OM Backup is enabled as well a the external DNS name for the OM instance.

```
tls=1 # yes (0 = no)
omBackup="true" # enable/disable OM backup services
orgName="ThriveAI"
omExternalName="om.${namespace}.local" # edit to provide a external DNS name for OM
```

### Exposed Service Type

If you plan to connect to Cluster resources from outside of the K8s cluster then the pods needs services - either LoadBalancer or NodePort.  This field is a string enum and must be exact.  If there is no LoadBalancer available, then use NodePort for the deployments.

```
serviceType="NodePort" # serviceType="LoadBalancer"
```

### OpsManager Admin

To set the opsmanager admin details change the name/passord for the initial OM admim user.  If you plan to use LDAP for authentification, you will need to set this user a user that is also in LDAP - e.g use sAMAccountName with an arbitrary password.  Then after the deployment, one changes the OpsManager Auth type from the app DB to use LDAP in the configuration settings. 

```
user="sAMAccountName"
password="yourPassword1$"
firstName="firstName"
lastName="lastName"
```

### DB Users

Create/indentify the first database user here:

```
dbuser="dbAdmin"
dbpassword="Mongodb1"
ldapUser="dbAdmin" # name of a db user
```

### LDAP settings - for Cluster/DB Users

You can pre-populate the configuration with your LDAP settings for use of LDAP for DB users.  These identify the key parameters for LDAP usage as outlined in the OM documentation.

```
ldapType="ldap" # ldaps enum ('ldap','ldaps', # anything other value turns ldap off)
ldapServer="cs.msds.kp.org:389" # may need to take an array of servers
ldapBindQueryUser="svcfork"
ldapBindQueryPassword="secret" # bindQueryPasswordSecretRef: the bind user "password" put into a secret
ldapAuthzQueryTemplate="{USER}?memberOf?base"
ldapUserToDNMapping='[ { match: "(.+)", ldapQuery: "OU=Managed,OU=Users,OU=PTC,OU=RPON East,DC=cs,DC=msds,DC=kp,DC=org??sub?(sAMAccountName={0})" } ]'
ldapCertMapName="kube-root-ca.crt" # ConfigMap containing a CA certificate that validates the LDAP server's TLS certificate.
ldapKey="ca.crt" # key containing the cert
ldapTimeoutMS=10000
ldapUserCacheInvalidationInterval=30
```

### LDAP settings - Ops Manager AuthN/AuthZ

You can also pre-populate the configuration with your LDAP settings for use of LDAP for the Ops Manager user Authentication and Authorization.  These identify the key parameters for LDAP usage as outlined in the OM documentation. These are the settings the Ops Manger can use to swith to LDAP is then selected as the OM authorization method.

```
mmsldapurl="ldap://cs.msds.kp.org:389"
mmsldapbinddn="svcfork" # Bind DN e.g. "cn=admin,dc=example,dc=org"
mmsldapbindpassword="servicepassword" # Bind DN credentials
mmsldapuserbasedn="OU=Managed,OU=Users,OU=PTC,OU=RPON East,DC=cs,DC=msds,DC=kp,DC=org"
mmsldapgroupbasedn="OU=Groups,DC=cs,DC=msds,DC=kp,DC=org" # default to ^
mmsldapusersearchattribute="sAMAccountName" #
mmsldapgroupmember="member"
mmsldapusergroup="memberOf" # deprecated
mmsldapglobalroleowner="CN=Thriveai_ocp_mongodb,OU=Groups,DC=cs,DC=msds,DC=kp,DC=org"
mmsldapuserfirstname="givenName"
mmsldapuserlastname="sn"
mmsldapuseremail="mail"
```

### Mail Relay Account

To set up for e-mail based alerts, configure e-mail here or or set up later.
```
mmsemail="account@foo.com"
mmsmailhostname="smtp.relay.net"
mmsmailusername="yourname"
mmsmailpassword="yourpassword"
```

## Launch Scripts README

Files are located in the k8s directory of the repository.First cd to the k8s director

* [_launch_Clusters.bash](https://github.com/mongodb-Rock/OpsMgr-in-Kubernetes-and-Docker/blob/master/scripts_launch_Clusters.md)
* [_launch_OM.bash](https://github.com/mongodb-Rock/OpsMgr-in-Kubernetes-and-Docker/blob/master/scripts_launch_OM.md)

## Deploy Scripts README

Files are located in the k8s directory of the repository.

* [deploy_Cluster.bash](https://github.com/mongodb-Rock/OpsMgr-in-Kubernetes-and-Docker/blob/master/scripts_deploy_Cluster.md)
