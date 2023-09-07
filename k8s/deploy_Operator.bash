#!/bin/bash

d=$( dirname "$0" )
cd "${d}"
source init.conf

# Optinal - Create the metrics server
#kubectl apply -f /opt/Source/metrics-server/components.yaml 

# Create the namespace and context
kubectl create namespace ${namespace}
kubectl config set-context $(kubectl config current-context) --namespace=${namespace}

# Deploy the MongoDB Enterprise Operator
myoperator="${namespace}-myoperator.yaml"
kubectl apply -f crds.yaml
if [[ "${clusterType}" == "openshift" ]]
then
    cat mongodb-enterprise-openshift.yaml | sed \
    -e "s/namespace: mongodb/namespace: $namespace/"  > "${myoperator}"
else
    cat mongodb-enterprise.yaml | sed \
    -e "s/namespace: mongodb/namespace: $namespace/"  > "${myoperator}"
fi
kubectl apply -f "${myoperator}"

if [[ ${tls} == 1 ]] 
then
    certs/make_cert_issuer.bash ${namespace} ${issuerName} ${issuerVersion}
    [[ $? != 0 ]] && exit 1
fi
exit 0
