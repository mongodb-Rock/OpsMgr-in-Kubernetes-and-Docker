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
if [[ ${skipMakeCerts} = 1 || ${skipMakeCerts} == "-s" || ${skipMakeCerts} == "-g" ]]
then
    export skip="-g"
fi
deploy_OM.bash $skip -n "${omName}" -c "2.00" -m "8Gi" -d "40Gi" -v "$omVersion"

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create the Backup Oplog1 DB for OM ..."
    deploy_Cluster.bash -n "${omName}-oplog" $skip      -c "2.00" -m "4Gi" -d "40Gi" -v "$appdbVersion"

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create the Backup BlockStore1 DB for OM ..."
    deploy_Cluster.bash -n "${omName}-blockstore" $skip -c "2.00" -m "4Gi" -d "40Gi" -v "$appdbVersion"

if [[ ! -e custom.conf ]]
then
    printf "\n%s\n" "__________________________________________________________________________________________"
    printf "%s\n" "Create the first Org in OM ..."
    orgName="DemoOrg"
    bin/deploy_org.bash "${orgName}"
fi
source custom.conf

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create a Production ReplicaSet Cluster with a splitHorizon configuration for External access ..."
    projectName="DemoProject1"
    deploy_Cluster.bash -n "myreplicaset" -l "${ldapType}" -c "2.00" -m "8Gi" -d "40Gi" -o "${orgId}" -p "${projectName}"
    cluster1="$projectName-myreplicaset"

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create a Production Sharded Cluster  ..."
    projectName="DemoProject2"
    deploy_Cluster.bash -n "mysharded"      -c "1.00" -m "2Gi" -d "4Gi" -s "2" -r "2" -o "${orgId}" -p "${projectName}" # -v "$mdbVersion"
    cluster2="$projectName-mysharded"

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Update init.conf with IPs and put k8s internal hostnames in /etc/hosts ..."
update_initconf_hostnames.bash "opsmanager" "$cluster1" "$cluster2"

date
