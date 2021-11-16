#!/bin/bash

d=$( dirname "$0" )
cd "${d}"
source init.conf

name=${1:-opsmanager}
skipcerts=${2:-0}
mdbom="mdbom_${name}.yaml"
mdbom_tls="mdbom_${name}_tls.yaml"

if [[ ${tls} == 1 && ${skipcerts} == 0 ]]
then
    printf "\n%s\n" "__________________________________________________________________________________________"
    printf "%s\n" "Getting Certs status..."
    # Generate CA and create certs for OM and App-db
    rm certs/${name}*.pem certs/ca.pem certs/queryable-backup.pem > /dev/null 2>&1
    certs/make_OM_certs.bash ${name}
    ls -1 certs/*pem certs/*crt 
fi

# Create the credentials for main admin user
kubectl delete secret         admin-user-credentials > /dev/null 2>&1
kubectl create secret generic admin-user-credentials \
    --from-literal=Username="${user}" \
    --from-literal=Password="${password}" \
    --from-literal=FirstName="${firstName}" \
    --from-literal=LastName="${lastName}"
  
if [[ ${tls} == 1 ]]
then
# For enablement of TLS (https) - provide certs and certificate authority
    kubectl delete secret         ${name}-cert > /dev/null 2>&1
    kubectl create secret generic ${name}-cert \
        --from-file="server.pem=certs/${name}-svc.pem" \
        --from-file="certs/queryable-backup.pem" # need specific keyname server.pem
    # CA used to define the projects configmap and agent ca for OM dbs
    kubectl delete configmap ${name}-ca > /dev/null 2>&1
    kubectl create configmap ${name}-ca \
        --from-file="ca-pem=certs/ca.pem" \
        --from-file="mms-ca.crt=certs/ca.pem" # need specific keynames ca-pem and mms-ca.crt

# For enablement of TLS on the appdb - custom certs
appdb=${name}-db
certs/make_db_certs.bash ${appdb} 
# Create a secret for the member certs for TLS
kubectl delete secret ${appdb}-cert > /dev/null 2>&1
# sleep 3
# kubectl get secrets
kubectl create secret tls ${appdb}-cert \
    --cert=certs/${appdb}.crt \
    --key=certs/${appdb}.key

#  Deploy OpsManager resources
    kubectl apply -f ${mdbom_tls}
else
    kubectl delete secret         ${name}-cert > /dev/null 2>&1
    kubectl create secret generic ${name}-cert --from-file="certs/queryable-backup.pem"

    kubectl apply -f ${mdbom}
fi

# Monitor the progress until the OpsMgr app is ready
while true
do
    kubectl get om 
    eval status=$(  kubectl get om -o json | jq .items[0].status.opsManager.phase )
    eval message=$( kubectl get om -o json | jq .items[0].status.opsManager.message )
    printf "%s\n" "status.opsManager.message: $message"
    if [[ "$status" == "Running" ]];
    then
        break
    fi
    sleep 15
done

# pre v1.8.2 - fix to expose port 25999 for queryable backup
# kubectl apply -f svc_${name}-backup.yaml
# pre v1.8.2 - fix to get a DNS name for the backup-daemon pod
# kubectl apply -f svc_${name}-backup-daemon.yaml
# list services for OM and QB

# update init.conf and put internal hostnames in /etc/hosts
while true
do
    kubectl get svc | grep ${name} | grep pending
    if [[ $? = 1 ]]
    then
        kubectl get svc/${name}-svc-ext # svc/${name}-backup svc/${name}-backup-daemon-0
        break
    fi
    printf "%s\n" "Sleeping 15 seconds to allow IP/Hostnames to be created"
    sleep 15
done
Misc/update_initconf_hostnames.bash

exit 0
