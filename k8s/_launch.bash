#!/bin/bash

# argument if set to 1 will skip creating new certs for OM and the App DB
skipMakeCerts=${1:-0} 

d=$( dirname "$0" )
cd "${d}"
source init.conf

#which jq > /dev/null
#if [[ $? != 0 ]]
#then
#    printf "%s\n" "Exiting - Missing jq tool - run: brew install jq"
#    exit 1
#fi

which cfssl > /dev/null
if [[ $? != 0 ]]
then
    printf "%s\n" "Exiting - Missing cloudformation certificiate tools - install cfssl and cfssljson"
    exit 1
fi

which kubectl > /dev/null
if [[ $? != 0 ]]
then
    printf "%s\n" "Exiting - Missing kubectl tool - (brew) install kubernetes-cli"
    exit 1
fi

kubectl api-resources > /dev/null 2>&1
if [[ $? != 0 ]]
then
    printf "%s\n" "Exiting - Check kubectl or cluster readiness"
    exit 1
fi

date
printf "\n%s\n" "__________________________________________________________________________________________"
context=$( kubectl config current-context )
printf "\n%s\n" "Using context: ${context}"

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Deploy the Operator ..."
deploy_Operator.bash

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Deploy OM and wait until Running status..."
if [[ ${skipMakeCerts} = 1 || ${skipMakeCerts} == "-s" ]]
then
    skip="-s"
fi

# deploy Ops Manager
deploy_OM.bash -n "opsmanager" $skip -c 0.5 -m 1Gi -d 4Gi -v "$omVersion"

#printf "\n%s\n" "__________________________________________________________________________________________"
#printf "%s\n" "Create the first Org in OM ..."
#deploy_org.bash

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create the Backup Oplog1 DB for OM ..."

# deploy Ops Manager Backup Oplog
deploy_Database.bash -n "opsmanager-oplog"      -c "0.50" -m "2Gi"          -v "$appdbVersion"


printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create the Backup BlockStore1 DB for OM ..."

# deploy Ops Manager Backup BlockStore
deploy_Database.bash -n "opsmanager-blockstore" -c "0.50" -m "2Gi"          -v "$appdbVersion"


printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Generate splitHorizon configuration for External access to a Production DB ..."

# deploy Replicated Database generate  splitHorizon configuration for External access to a Production DB
#if [[ $ldap == 'ldap' || $ldap == 'ldaps' ]]
#then
    deploy_Database.bash -n "myldaprs"  -l ldaps      -c "1.00" -m "4Gi" -d "4Gi" -v "6.0.1-ent"
    replicasetName="myldaprs"
#else
    deploy_Database.bash -n "myreplicaset"          -c "1.00" -m "4Gi" -d "4Gi" -v "6.0.1-ent"
    replicasetName="myreplicaset"
#fi

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Generate configuration for External access to a Sharded Production DB ..."

# deploy Sharded Databases Generate Config for External Access
deploy_DatabaseSharded.bash -n "mysharded"      -c "1.00" -m "2Gi" -d "4Gi" -s "2" -r "2" -v "$mdbVersion"
shardingName="mysharded"


printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Update init.conf with IPs and put k8s internal hostnames in /etc/hosts ..."
update_initconf_hostnames.bash "opsmanager" "$replicasetName" "$shardedName"

date
