#!/bin/bash

d=$( dirname "$0" )
cd "${d}"
source init.conf

while getopts 'n:c:m:d:v:l:xh' opt
do
  case "$opt" in
    n) name="$OPTARG" ;;
    c) cpu="$OPTARG" ;;
    m) mem="$OPTARG" ;;
    d) dsk="$OPTARG" ;;
    v) ver="$OPTARG" ;;
    l) ldap="$OPTARG" ;;
    x) x="1" ;; # cleanup
    ?|h)
      echo "Usage: $(basename $0) [-n name] [-c cpu] [-m memory] [-d disk] [-c arg] [-l ldap] [-a authorization][-x]"
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

name="${name:-myreplicaset}"
cpu="${cpu:-0.5}"
mem="${mem:-500Mi}"
dsk="${dsk:-1Gi}"
ver="${ver:-$mdbVersion}"
ldap="${ldap:-$ldap}"
cleanup=${x:-0}

# make manifest from template
if [[ ${ldap} == 'ldap' || ${ldap} == 'ldaps' ]]
then
  mdbuser="mdbuser_${ldap}_${name}.yaml"
  mdb="mdb_${ldap}_${name}.yaml"
else
  mdbuser="mdbuser_${name}.yaml"
  mdb="mdb_${name}.yaml"
fi
tlsc="#TLS "
tlsr=$tlsc
if [[ ${tls} == 1 ]]
then
tlsr=""
fi
ldaptls=""
if [[ ${ldap} == 'ldaps' ]]
then
  ldaptls="tls"
fi

if [[ ${ldap} == 'ldap' || ${ldap} == 'ldaps' ]]
then
  cat mdb_replicaset_ldap.yaml | sed \
      -e "s/$tlsc/$tlsr/" \
      -e "s/MEM/$mem/" \
      -e "s/CPU/$cpu/" \
      -e "s/DISK/$dsk/" \
      -e "s/VERSION/$ver/" \
      -e "s/NAMESPACE/$namespace/" \
      -e "s/LDAPTLS/$ldaptls/" \
      -e "s/LDAPBINDQUERYUSER/$ldapBindQueryUser/" \
      -e "s/LDAPAUTHZQUERYTEMPLATE/$ldapAuthzQueryTemplate/" \
      -e "s/LDAPUSERTODNMAPPING/$ldapUserToDNMapping/" \
      -e "s/LDAPTIMEOUTMS/$ldapTimeoutMS/" \
      -e "s/LDAPUSERCACHEINVALIDATIONINTERVAL/$ldapUserCacheInvalidationInterval/" \
      -e "s/LDAPSERVER/$ldapServer/" \
      -e "s/NAME/$name/" > "$mdb"
else
  cat mdb_replicaset.yaml | sed \
      -e "s/$tlsc/$tlsr/" \
      -e "s/MEM/$mem/" \
      -e "s/CPU/$cpu/" \
      -e "s/DISK/$dsk/" \
      -e "s/VERSION/$ver/" \
      -e "s/NAMESPACE/$namespace/" \
      -e "s/NAME/$name/" > "$mdb"
fi
#dbuserlc=${dbuser,,}
dbuserlc=$( printf "$dbuser" | tr '[:upper:]' '[:lower:]' )
if [[ ${ldap} == 'ldap' || ${ldap} == 'ldaps' ]]
then
  cat mdbuser_ldap_template.yaml | sed \
      -e "s/NAME/${name}/" \
      -e "s/USER/${dbuserlc}/" > "$mdbuser"
else
    cat mdbuser_template.yaml | sed \
      -e "s/NAME/${name}/" \
      -e "s/USER/${dbuserlc}/" > "$mdbuser"
fi
# clean up any previous certs and services
if [[ ${cleanup} = 1 ]]
then
  #kubectl delete secret "${name}-cert" > /dev/null 2>&1
  #kubectl delete csr $( kubectl get csr | grep "${name}" | awk '{print $1}' )
  kubectl delete mdb "${name}"
  kubectl delete pvc $( kubectl get pvc | grep "${name}" | awk '{print $1}' )
  kubectl delete svc $( kubectl get svc | grep "${name}" | awk '{print $1}' )
fi

# create new certs if the service does not exist
# check to see if the svc needs to be created
for n in ${exposed_dbs[@]}
do
  if [[ "$n" == "${name}" ]] 
  then
  # kubectl get svc "${name}-0" > /dev/null 2>&1
  # if [[ $? != 0 ]]
  # then
    # expose ports - creates loadlancer or nodeport service for each pod of member set
    # add the nodeport map for splitHorizon into the yaml file
    printf "%s\n" "Generating NodePort/Loadbalancer Service ports..."
    expose_service.bash "${mdb}" ${cleanup}
    source init.conf
  # fi
  fi
done

# Create map for OM Org/Project
if [[ ${tls} == 1 ]]
then
kubectl delete configmap "${name}" > /dev/null 2>&1
kubectl create configmap "${name}" \
    --from-literal="baseUrl=${opsMgrUrl}" \
    --from-literal="projectName=${name}" \
    --from-literal="sslMMSCAConfigMap=opsmanager-ca" \
    --from-literal="sslRequireValidMMSServerCertificates='true'"

rm "${PWD}/certs/${name}"* > /dev/null 2>&1
if [[ -e dnsHorizon ]] 
then
  dnsHorizon=( $(cat dnsHorizon) )
  rm dnsHorizon
  "${PWD}/certs/make_db_certs.bash" "${name}" ${dnsHorizon[@]}
else
  "${PWD}/certs/make_db_certs.bash" "${name}"
fi
# Create a secret for the member certs for TLS
kubectl delete secret "mdb-${name}-cert" > /dev/null 2>&1
# sleep 3
# kubectl get secrets
kubectl create secret tls "mdb-${name}-cert" \
    --cert="${PWD}/certs/${name}.crt" \
    --key="${PWD}/certs/${name}.key"

for ctype in agent clusterfile
do   
    "${PWD}/certs/make_sharded_certs.bash" "${name}" ${ctype}
    # Create a secret for the member certs for TLS
    cert=""
    if [[ "${ctype}" == "agent" ]]
    then
    cert="-certs"
    fi
    kubectl delete secret "mdb-${name}-${ctype}${cert}" > /dev/null 2>&1
    kubectl create secret tls "mdb-${name}-${ctype}${cert}" \
        --cert="${PWD}/certs/${name}-${ctype}.crt" \
        --key="${PWD}/certs/${name}-${ctype}.key"
done


# Create a map for the cert
kubectl delete configmap ca-pem > /dev/null 2>&1
kubectl create configmap ca-pem \
    --from-file="ca-pem=${PWD}/certs/ca.pem"
else
kubectl delete configmap "${name}" > /dev/null 2>&1
kubectl create configmap "${name}" \
    --from-literal="baseUrl=${opsMgrUrl}" \
    --from-literal="projectName=${name}"
fi # tls

# Create a a secret for db user credentials
kubectl delete secret         ${name}-${dbuserlc} > /dev/null 2>&1
kubectl create secret generic ${name}-${dbuserlc} \
    --from-literal=name="${dbuser}" \
    --from-literal=password="${dbpassword}"

# Create the User Resource
kubectl apply -f "${mdbuser}"

# remove any certificate requests
list=( $( kubectl get csr 2>/dev/null | grep "${name}" | awk '{print $1}' ) )
if [[ ${#list[@]} > 0 ]]
then
    kubectl delete csr ${list[@]} > /dev/null 2>&1
fi

# Create the DB Resource
kubectl apply -f "${mdb}"

# Monitor the progress
resource="mongodb/${name}"
printf "\n%s\n" "Monitoring the progress of resource ${resource} ..."
notapproved="Not all certificates have been approved"
certificate="Certificate"
while true
do
    kubectl get "${resource}"
    pstatus=$( kubectl get "${resource}" -o jsonpath={'.status.phase'} )
    message=$( kubectl get "${resource}" -o jsonpath={'.status.message'} )
    printf "%s\n" "status.message: $message"
    if [[ "${message:0:39}" == "${notapproved}" ||  "${message:0:11}" == "${certificate}" ]]
    then
        # TLS Cert approval (if using autogenerated certs -- deprecated)
        kubectl certificate approve $( kubectl get csr | grep "Pending" | awk '{print $1}' )
    fi
    #if [[ "$pstatus" == "Pending" || "$pstatus" == "Running" ]];
    if [[ "$pstatus" == "Running" ]];
    then
        printf "Status: %s\n" "$pstatus"
        break
    fi
    sleep 15
done

sleep 5
printf "\n"
bin/get_connection_string.bash -n "${name}"
printf "\n"
printf "%s\n" "Wait a minute for the reconfiguration and then connect directly by running: bin/connect_external.bash   -n \"${name}\""
printf "%s\n" "                                        or connect from the pod by running: bin/kub_connect_to_pod.bash -n \"${name}\""

exit 0
