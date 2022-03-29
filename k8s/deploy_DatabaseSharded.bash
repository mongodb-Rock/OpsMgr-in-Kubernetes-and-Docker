#!/bin/bash

d=$( dirname "$0" )
cd "${d}"
source init.conf

name="${1:-my-sharded}"
mdb="mdb_${name}.yaml"
mdbuser="mdbuser_${name}.yaml"
shift
cleanup=${1:-0}

# clean up any previous certs and services
if [[ ${cleanup} = 1 ]]
then
  #kubectl delete secret ${name}-cert > /dev/null 2>&1
  #kubectl delete csr $( kubectl get csr | grep "${name}" | awk '{print $1}' )
  kubectl delete svc $( kubectl get svc | grep "${name}" | awk '{print $1}' )
  kubectl delete mdb ${name}
fi

# Create map for OM Org/Project
if [[ ${tls} == 1 ]]
then
    kubectl delete configmap ${name} > /dev/null 2>&1
    kubectl create configmap ${name} \
        --from-literal="baseUrl=${opsMgrUrl}" \
        --from-literal="projectName=${name}" \
        --from-literal="sslMMSCAConfigMap=opsmanager-ca" \
        --from-literal="sslRequireValidMMSServerCertificates='true'"

  rm certs/${name}*
    # mdb-{metadata.name}-mongos-cert
    # mdb-{metadata.name}-config-cert
    # mdb-{metadata.name}-<x>-cert x=0,1 (2 shards)
  for ctype in agent mongos config 0 1
  do   
    certs/make_sharded_certs.bash ${name} ${ctype}
    # Create a secret for the member certs for TLS
    kubectl delete secret mdb-${name}-${ctype}-cert > /dev/null 2>&1
    kubectl create secret tls mdb-${name}-${ctype}-cert \
        --cert=certs/${name}-${ctype}.crt \
        --key=certs/${name}-${ctype}.key
  done

    # Create a map for the cert
    kubectl delete configmap ca-pem > /dev/null 2>&1
    kubectl create configmap ca-pem \
        --from-file="ca-pem=certs/ca.pem"
else
    kubectl delete configmap ${name} > /dev/null 2>&1
    kubectl create configmap ${name} \
        --from-literal="baseUrl=${opsMgrUrl}" \
        --from-literal="projectName=${name}"
fi #tls

# Create a a secret for db user credentials
kubectl delete secret         dbadmin-${name} > /dev/null 2>&1
kubectl create secret generic dbadmin-${name} \
    --from-literal=name="${dbadmin}" \
    --from-literal=password="${dbpassword}"

# Create the User Resource
kubectl apply -f "${mdbuser}"

# Create the DB Resource

list=( $( kubectl get csr | grep "${name}" | awk '{print $1}' ) )
if [[ ${#list[@]} > 0 ]]
then
    kubectl delete csr ${list[@]}
fi
kubectl apply -f "${mdb}"

# Monitor the progress
notapproved="Not all certificates have been approved"
certificate="Certificate"
pod=mongodb/${name}
while true
do
    kubectl get ${pod}
    eval status=$(  kubectl get ${pod} -o json| jq '.status.phase' )
    eval message=$( kubectl get ${pod} -o json| jq '.status.message' )
    printf "%s\n" "status.message: $message"
    if [[ "${message:0:39}" == "${notapproved}" ||  "${message:0:11}" == "${certificate}" ]]
    then
        # TLS Cert approval (if using autogenerated certs -- depricated)
        kubectl certificate approve $( kubectl get csr | grep "Pending" | awk '{print $1}' )
    fi
    #if [[ $status == "Pending" || $status == "Running" ]];
    if [[ "$status" == "Running" ]];
    then
        printf "%s\n" "$status"
        break
    fi
    sleep 15
done

# get keys for TLS
tls=$( kubectl get mdb/${name} -o jsonpath='{.spec.security.tls}' )
if [[ "${tls}" == "map[enabled:true]" || "${tls}" == *"\"enabled\":true"* ]]
then
    eval version=$( kubectl get mdb ${name} -o jsonpath={.spec.version} )
    if [[ ${version%%.*} = 3 ]]
    then
        ssltls_options=" --ssl --sslCAFile ca.pem --sslPEMKeyFile server.pem "
        ssltls_enabled="&ssl=true"
    else
        ssltls_options=" --tls --tlsCAFile ca.pem --tlsCertificateKeyFile server.pem "
        ssltls_enabled="&tls=true"
    fi
fi

eval cs=\$${name//-/}_URI
if [[ "$cs" != "" ]]
then
  printf "\n"
  printf "%s\n" "Wait a minute for the reconfiguration and then connect by running: Misc/connect_external.bash ${name}"
  fcs=\'${cs}${ssltls_enabled}\'
  printf "\n%s\n\n" "Connect String: ${fcs} ${ssltls_options}"
else
  printf "\n"
  printf "%s\n" "Wait a minute for the reconfiguration and then connect by running: Misc/kub_connect_to_pod.bash ${name}"
fi

exit 0
