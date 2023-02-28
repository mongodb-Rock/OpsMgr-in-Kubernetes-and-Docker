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
(set -x
deploy_Operator.bash
)

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Deploy OM and wait until Running status..."
if [[ ${skipMakeCerts} = 1 || ${skipMakeCerts} == "-s" || ${skipMakeCerts} == "-g" ]]
then
    export skip="-g"
fi
(set -x
deploy_OM.bash $skip -n "${omName}" -c "2.00" -m "8Gi" -d "40Gi" -v "$omVersion"
)

if [[ ${omBackup} == true ]]
then
printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create the Backup Oplog1 DB for OM ..."
    (set -x
    deploy_Cluster.bash -n "${omName}-oplog" $skip      -c "2.00" -m "8Gi" -d "100Gi" -v "$appdbVersion"
    )
printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create the Backup BlockStore1 DB for OM ..."
    (set -x
    deploy_Cluster.bash -n "${omName}-blockstore" $skip -c "2.00" -m "8Gi" -d "500Gi" -v "$appdbVersion"
    )
fi

date
