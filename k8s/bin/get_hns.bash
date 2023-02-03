#!/bin/bash

while getopts 'n:t:h' opts
do
  case "$opts" in
    n) name="$OPTARG" ;;
    t) serviceType="$OPTARG" ;;
    ?|h)
      echo "Usage: $(basename $0) -n clusterName [-t NodePort|LoadBalancer ] "
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

#name=${name:-myreplicaset}
#serviceType=${serviceType:-NodePort}

type=$( kubectl get mdb/${name} -o jsonpath='{.spec.type}' 2>/dev/null )

if [[ $? == 1 ]]
then
    om=1
    sharded=0 
    type=$( kubectl get om/${name} -o jsonpath='{.spec.externalConnectivity.type}' )
    serviceName=${name}-svc-ext
    serviceType=$( kubectl get svc/${serviceName} -o jsonpath='{.spec.type}' )
else

#if [[ "${sharded}" == "1" ]]
if [[ "${type}" == "ShardedCluster" ]]
then
    om=0
    sharded=1
    serviceName=${name}-svc-external
    serviceType=$( kubectl get svc/${serviceName} -o jsonpath='{.spec.type}' )
else
    om=0
    sharded=0
    serviceType=$( kubectl get svc/${name}-0 -o jsonpath='{.spec.type}' )
fi
fi

if [[ "$serviceType" != "NodePort" ]]
then
    if [[ "${sharded}" == 1 ]]
    then
        np0=$( kubectl get svc/${serviceName} -o jsonpath='{.spec.ports[0].port}' )
        slist=( $( kubectl get svc/${serviceName} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' ) )
    elif [[ "$om" == 1 ]]
      then
        np0=$( kubectl get svc/${serviceName} -o jsonpath='{.spec.ports[0].port}' )
        if [[ ${#slist[@]} == 0 ]]
        then
        slist=( $(kubectl get svc/${serviceName} -o jsonpath='{.status.loadBalancer.ingress[*].ip }' ) )
        fi
    else
        np0=$( kubectl get svc/${name}-0 -o jsonpath='{.spec.ports[0].port}' )
        np1=$( kubectl get svc/${name}-1 -o jsonpath='{.spec.ports[0].port}' )
        np2=$( kubectl get svc/${name}-2 -o jsonpath='{.spec.ports[0].port}' )

        slist=( $( kubectl get svc ${name}-0 ${name}-1 ${name}-2 -o jsonpath='{.items[*].status.loadBalancer.ingress[0].hostname}' ) )
        if [[ ${#slist[@]} == 0 ]]
        then
        slist=( $(kubectl get svc ${name}-0 ${name}-1 ${name}-2 -o jsonpath='{.items[*].status.loadBalancer.ingress[*].ip }' ) )
        fi
    fi
else
    if [[ "${sharded}" == 1 || ${om} == 1 ]]
    then
    np0=$( kubectl get svc/${serviceName} -o jsonpath='{.spec.ports[0].nodePort}' )
    np1=$np0
    np2=$np0
    else
    np0=$( kubectl get svc/${name}-0 -o jsonpath='{.spec.ports[0].nodePort}' )
    np1=$( kubectl get svc/${name}-1 -o jsonpath='{.spec.ports[0].nodePort}' )
    np2=$( kubectl get svc/${name}-2 -o jsonpath='{.spec.ports[0].nodePort}' )
    fi # not sharded
fi

if [[ "$serviceType" != "LoadBalancer" ]]
then
# get IP/DNS names
    #slist=( $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalDNS")].address}' ) )
    slist=( $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="Hostname")].address}') )
        slist=( $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalDNS")].address}' ) )
    	if [[ ${#slist[@]} == 0 ]] 
        then
    	    slist=( $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="Hostname")].address}') )
	fi
    	if [[ ${#slist[@]} == 0 && $custerType == "openshift" ]]
	then
            # OpenShift read of names
            slist=( $(kubectl get nodes -o json | jq -r '.items[].metadata.labels | select((."node-role.kubernetes.io/infra" == null) and .storage == "pmem") | ."kubernetes.io/hostname" ' ) ) 
	    #slist=( $( kubectl get nodes -o json | jq -r '.items[].metadata.labels | select(."node-role.kubernetes.io/worker") | ."kubernetes.io/hostname" '))
        fi
    	if [[ ${#slist[@]} == 0 ]] 
        then
            slist=( $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalDNS")].address}' ) )
        fi
    	if [[ ${#slist[@]} == 0 ]] 
        then
            slist=( $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalIP")].address}' ) )
        fi
    
fi

num=${#slist[@]}

if [[ $num = 1 ]]
then
# single node cluster
    hn0=${slist[0]}
    hn1=${slist[0]#}
    hn2=${slist[0]#}
else
    hn0=${slist[0]}
    hn1=${slist[1]}
    hn2=${slist[2]}
fi
printf "%s %s %s" "$hn0:$np0" "$hn1:$np1" "$hn2:$np2" 
