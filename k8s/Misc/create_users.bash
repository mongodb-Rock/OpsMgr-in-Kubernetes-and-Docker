#!/bin/bash -x

. init.conf

echo '{
        "username": "ted.doe@mongodb.com",
        "emailAddress": "ted.doe@mongodb.com",
        "firstName": "ted",
        "lastName": "Doe",
        "password": "M0ng0D8!:)",
        "roles": [
        {
          "orgId" : "ORGID",
          "roleName" : "ORG_MEMBER"
        }]
      }' | sed -e"s/ORGID/${orgId}/" > data.json

curl --user "${publicKey}:${privateKey}" --digest \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --request POST "http://opsmgr:32080/api/public/v1.0/users" \
  --data @data.json

exit

curl --user "${publicKey}:${privateKey}" --digest \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --include \
  --request POST "http://opsmgr:32080/api/public/v1.0/users" \
  --data \"
    {
      "username": "john.doe@mongodb.com",
      "emailAddress": "john.doe@mongodb.com",
      "firstName": "John",
      "lastName": "Doe",
      "password": "M0ng0D8!:)",
      "roles": [{
        "groupId": "5ee6876f23ac1a43e1df0b50",
        "roleName": "GROUP_BACKUP_ADMIN"
      },{
        "orgId" : "${ORGID}",
        "roleName" : "ORG_MEMBER"
      }]
    }\"

