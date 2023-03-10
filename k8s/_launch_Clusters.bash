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
kubectl config set-context $(kubectl config current-context) --namespace=${namespace}

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create a custom Org to put your projects in ..."
# Create the Org and put orgId info in custom.conf
(set -x
bin/deploy_org.bash -o ${orgName} # ThriveAI
)
test -e custom.conf && source custom.conf
orgId="${orgName}_orgId"
orgId="${!orgId}"

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create Production ReplicaSet Cluster(s) with a splitHorizon configuration for External access ..."
    (set -x; 
    deploy_Cluster.bash -n "mda-replicaset"       -e -l "${ldapType}" -c "2.00" -m "8Gi" -d "40Gi" -o "${orgId}" -p "mda"
    )

    (set -x; 
    deploy_Cluster.bash -n "msg-mgmt-replicaset" -e  -l "${ldapType}" -c "2.00" -m "8Gi" -d "40Gi" -o "${orgId}" -p "msg-mgmt"
    )

date
