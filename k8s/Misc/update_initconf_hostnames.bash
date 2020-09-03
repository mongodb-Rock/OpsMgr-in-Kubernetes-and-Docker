#!/bin/bash

source ~/k8s/init.conf
TAB=$'\t'

#if [[ ${1} == "" ]]
#then 
#    exit 1 -- need opsmanager service name
#else
name="${1-opsmanager}"
#fi

# get the OpsMgr URL and internal IP
opsMgrUrl=$(     kubectl get om -o json | jq .items[0].status.opsManager.url )
eval hostname=$( kubectl get svc/${name}-svc-ext -o json | jq .status.loadBalancer.ingress[0].hostname ) 
eval opsMgrIp=$( kubectl get svc/${name}-svc-ext -o json | jq .status.loadBalancer.ingress[0].ip ) 
eval port=$(     kubectl get svc/${name}-svc-ext -o json | jq .spec.ports[0].port )

http="http"
if [[ ${port} == "8443" ]]
then
    http="https"
fi

if [[ ${hostname} == "null" ]]
then
    opsMgrExtUrl=${http}://${ip}:${port}
else
    opsMgrExtUrl=${http}://${hostname}:${port}
    if [[ "${hostname}" != "localhost" ]]
    then
        eval list=( $( nslookup ${hostname} | grep Address ) )
        opsMgrIp=${list[3]}
    else
        opsMgrIp=127.0.0.1
    fi
fi

# get the internal IP
eval hostname=$( kubectl get svc/${name}-backup -o json | jq .status.loadBalancer.ingress[0].hostname ) 
eval qbip=$( kubectl get svc/${name}-backup -o json | jq .status.loadBalancer.ingress[0].ip ) 

if [[ ${hostname} != "null" ]]
then
    if [[ "${hostname}" != "localhost" ]]
    then
        eval list=( $( nslookup ${hostname} | grep Address ) )
        qbip=${list[3]}
    else
        qbip=127.0.0.1
    fi
fi

# Update init.conf with QB IP
cat init.conf | sed -e '/queryableBackup/d' > new
echo  queryableBackup=\""$qbip"\" | tee -a new
mv new init.conf

# Update init.conf with OpsMgr info
cat init.conf | sed -e '/opsMgrUrl/d' -e '/opsMgrExt/d'  > new
echo  opsMgrUrl="$opsMgrUrl"           | tee -a new
echo  opsMgrExtIp=\""$opsMgrIp"\"          | tee -a new
echo  opsMgrExtUrl=\""$opsMgrExtUrl"\" | tee -a new
mv new init.conf

# put the internal name opsmanager-svc.mongodb.svc.cluster.local in /etc/hosts
grep "^[0-9].*opsmanager-svc.mongodb.svc.cluster.local" /etc/hosts > /dev/null 2>&1
if [[ $? == 0 ]]
then
    # replace host entry
    printf "%s\n" "Replacing host entry:"
    printf "%s\n" "${opsMgrExtIp}${TAB}opsmanager-svc.mongodb.svc.cluster.local" 
    sudo sed -E -i .bak -e "s|^[0-9].*(opsmanager-svc.mongodb.svc.cluster.local.*)|${opsMgrExtIp}${TAB}\1|" /etc/hosts
else
    # add host entry
    printf "%s\n" "Adding host entry:"
    printf "%s\n" "${opsMgrExtIp}${TAB}opsmanager-svc.mongodb.svc.cluster.local" | sudo tee -a /etc/hosts
fi

# put the internal name opsmanager-svc for queriable backup /etc/hosts
grep "^[0-9].*opsmanager-svc " /etc/hosts > /dev/null 2>&1
if [[ $? == 0 ]]
then
    # replace host entry
    printf "%s\n" "Replacing host entry:"
    printf "%s\n" "${queryableBackup}${TAB}opsmanager-svc " 
    sudo sed -E -i .bak -e "s|^[0-9].*(opsmanager-svc .*)|${queryableBackup}${TAB}\1|" /etc/hosts
else
    # add host entry
    printf "%s\n" "Adding host entry:"
    printf "%s\n" "${queryableBackup}${TAB}opsmanager-svc " | sudo tee -a /etc/hosts
fi

# get the nodes for creating custom clusters via agent automation
hostname=( $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="Hostname")].address}') )
dnslist=(  $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalDNS")].address}' ) )
iplist=(   $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalIP")].address}' ) )
names=( mongodb1 mongodb2 mongodb3 )

if [[ ${hostname} == "docker-desktop" ]]
then
hostname=(docker-desktop docker-desktop docker-desktop)
dnslist=(docker-desktop docker-desktop docker-desktop)
iplist=(127.0.0.1 127.0.0.1 127.0.0.1)
fi

for n in 0 1 2
do

  grep "^[0-9].*${names[$n]}" /etc/hosts > /dev/null 2>&1
  if [[ $? == 0 ]]
  then
    # replace host entry
    printf "%s\n" "Replacing host entry:"
    printf "%s\n"                                   "${iplist[$n]}${TAB}${names[$n]} ${dnslist[$n]} ${hostname[$n]}" 
    sudo sed -E -i .bak -e "s|^[0-9].*${names[$n]}.*|${iplist[$n]}${TAB}${names[$n]} ${dnslist[$n]} ${hostname[$n]}|" /etc/hosts
  else
    # add host entry
    printf "%s\n" "Adding host entry:"
    printf "%s\n"                                   "${iplist[$n]}${TAB}${names[$n]} ${dnslist[$n]} ${hostname[$n]}" | sudo tee -a /etc/hosts
  fi

done