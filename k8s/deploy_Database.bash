#!/bin/bash

d=$( dirname "$0" )
cd "${d}"
PATH=$PATH:"${d}"/Misc

source init.conf
name="${1:-my-replica-set}"
mdb="mdb_${name}.yaml"
mdbuser="mdbuser_${name}.yaml"

# clean up any previous certs and services
if [[ ${cleanup} ]]
then
kubectl delete secret ${name}-cert > /dev/null 2>&1

kubectl delete csr ${name}-0.mongodb > /dev/null 2>&1
kubectl delete csr ${name}-1.mongodb > /dev/null 2>&1
kubectl delete csr ${name}-2.mongodb > /dev/null 2>&1

kubectl delete svc ${name}-0 > /dev/null 2>&1
kubectl delete svc ${name}-1 > /dev/null 2>&1
kubectl delete svc ${name}-2 > /dev/null 2>&1
fi

# create new certs if the service does not exist

for n in ${exposed_dbs[@]}
do
  if [[ "$n" == "${name}" ]] 
  then
    kubectl get svc ${name}-0 > /dev/null 2>&1
    if [[ $? != 0 ]]
    then
      # expose nodeports - creates nodeport service for each pod of member set
      # add the nodeport map for splitHorizon
      printf "%s\n" "Generating Service ports..."
      Misc/expose_service.bash ${mdb}
      source init.conf
    fi
  fi
done

# Create map for OM Org/Project
if [[ ${tls} == 1 ]]
then
kubectl delete configmap ${name} > /dev/null 2>&1
kubectl create configmap ${name} \
  --from-literal="baseUrl=${opsMgrUrl}" \
  --from-literal="projectName=${name//-/}" \
  --from-literal="sslMMSCAConfigMap=opsmanager-cert-ca" \
  --from-literal="sslRequireValidMMSServerCertificates=‘true’"
else
kubectl delete configmap ${name} > /dev/null 2>&1
kubectl create configmap ${name} \
  --from-literal="baseUrl=${opsMgrUrl}" \
  --from-literal="projectName=${name//-/}"
fi

# Create a secret for the member certs for TLS
# kubectl delete secret ${name}-cert
# sleep 10
# kubectl get secrets
# kubectl create secret generic ${name}-cert \
#   --from-file=${name}-0-pem \
#   --from-file=${name}-1-pem \
#   --from-file=${name}-2-pem
# Create a map for the cert
# kubectl delete configmap ca-pem
# kubectl create configmap ca-pem --from-file=ca-pem

# Create a a secret for db user credentials
kubectl delete secret         dbadmin-${name} > /dev/null 2>&1
kubectl create secret generic dbadmin-${name} \
  --from-literal=name="${dbadmin}" \
  --from-literal=password="${dbpassword}"

# Create the User Resource
kubectl apply -f "${mdbuser}"

# Create the DB Resource

kubectl apply -f "${mdb}"

kubectl delete csr ${name}-0.mongodb > /dev/null 2>&1
kubectl delete csr ${name}-1.mongodb > /dev/null 2>&1
kubectl delete csr ${name}-2.mongodb > /dev/null 2>&1

# Monitor the progress
notapproved="Not all certificates have been approved"
certificate="Certificate"
while true
do
    kubectl get mongodb/${name}
    eval status=$( kubectl get mongodb/${name} -o json| jq '.status.phase' )
    eval message=$( kubectl get mongodb/${name} -o json| jq '.status.message')
    printf "%s\n" "$message"
    if [[ "${message:0:39}" == "${notapproved}" ||  "${message:0:11}" == "${certificate}" ]]
    then
        # TLS Cert approval (if using autogenerated certs -- depricated)
        kubectl certificate approve ${name}-0.mongodb 
        kubectl certificate approve ${name}-1.mongodb
        kubectl certificate approve ${name}-2.mongodb
    fi
    #if [[ $status == "Pending" || $status == "Running" ]];
    if [[ "$status" == "Running" ]];
    then
        printf "%s\n" "$status"
        break
    fi
    sleep 15
done

printf "\n"
printf "%s\n" "Wait a minute for the reconfiguration and then connect by running: Misc/connect_external.bash ${name}"
eval cs=\$${name//-/}_URI
printf "%s\n" "Connect String: $cs" 
printf "\n"

exit 0