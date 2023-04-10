# OpsMgr K8s Openshift

## Summary:

- These scripts will install into a Kubernetes cluster:
  * Ops Manager v6
  		* the appDB
  		* a blockstore DB for backups
  		* an oplog DB for continous backups
- 2 Sample Production DBs
  * a replica set cluster
  * a sharded cluster.
  * TLS Certs are created using a self-signed CA.
  * queriable backup is available too!

### Step 1. Create or login to an Openshift/K8s Cluster

- To run a small production workload, a cluster with the following resources is needed:

  * Openshift/Kubernetes cluster typical resources:
    * Configure 32 Cores
    * Configure 128GB of Memory
    * Disk 500GB-4000TB

### Step 2. Launch the Services

the **_launch.bash** script runs several "deploy" scripts for each of the following steps:

- Script 1: **deploy_Operator.bash**

  - Setup the OM enviroment
  - Defines the namespace
  - Deploys the MongoDB Enterprise K8s Operator
- Script 2: **deploy_OM.bash**

  - Setup the Ops Manager enviroment
  - Deploy the OM Resources
    - OpsManager
    - AppDB
  - Monitors the progress of OM for Readiness
- Script 3: **deploy_Database.bash** and **deploy_DatabaseSharded.bash**

  - Deploy a DB - three more are created
  - Oplog1 and Blockstore1 dbs complete the Backup setup for OM
  - myreplicaset is a "Production" DB and has a splitHorizon configuration for external cluster access
    - connect via ``bin/connect_external.bash`` script
  - Monitors the progress until the pods are ready

### Step 3. Login to Ops Manager

- login to OM at https://opsmanager-svc.mongodb.svc.cluster.local:8443
- the admin user credentials are set in ``init.conf``
  - the scripts also create a hostname entry such as:
    ``127.0.0.1       opsmanager-svc.mongodb.svc.cluster.local # opsmgr``
    into the ``/etc/hosts`` file
  - Note: if you add the custom TLS certificate authority (certs/ca.crt) to your keystore, this allows seamless unchallenged secure https access

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

This is where TLS and OM Backup can be enabled or disabled.

```
tls=1 # yes (0 = no)
omBackup="true" # enable/disable OM backup services
orgName="ThriveAI"
omExternalName="om.${namespace}.local" # edit to provide a external DNS name for OM
```

### Exposed Service Type

Here you will be selecting either LoadBalancer or NodePort.  This field is a string enum and must be exact.  Here we have been using NodePort for the deployments.

```
serviceType="NodePort" # serviceType="LoadBalancer"
```

### OpsManager Admin

Here you set your opsmanager admin details.  Since LDAP will be in use for authentification you must set this to you sAMAccountName with a password, then after deployment change the OpsManager Auth type to LDAP.  This will allow you to save the changes and make the switch over to LDAP auth.

```
user="sAMAccountName"
password="yourPassword1$"
firstName="firstName"
lastName="lastName"
```

### DB Users

Name your first database user here.

```
dbuser="dbAdmin"
dbpassword="Mongodb1"
ldapUser="dbAdmin" # name of a db user
```

### LDAP settings - for Cluster/DB Users

This is your company LDAP settings.  Here you select if it's ldap or secure ldaps.  Point to you ldap server, set your bind user, and ldap query structure.

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

### LDAP settings - ops manager

These are the settings the Ops Manger will use after a deployment is made and LDAP is then selected as the authorization method.

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
This is where you setup how mail will be sent out via OpsManager.
```
mmsemail="account@foo.com"
mmsmailhostname="smtp.relay.net"
mmsmailusername="yourname"
mmsmailpassword="yourpassword"
```