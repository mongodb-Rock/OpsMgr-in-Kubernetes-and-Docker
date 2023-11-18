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

cat <<EOF >> "${myoperator}" 
            - name: MDB_AUTOMATIC_RECOVERY_ENABLE
              value: 'true'
            - name: MDB_AUTOMATIC_RECOVERY_BACKOFF_TIME_S
              value: '480'
EOF

kubectl apply -f "${myoperator}"

if [[ ${tls} == 'true' ]] 
then
    certs/make_cert_issuer.bash ${namespace} ${issuerName} ${issuerVersion}
    [[ $? != 0 ]] && exit 1
fi
exit 0
