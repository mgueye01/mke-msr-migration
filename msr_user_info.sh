#!/bin/bash

## Capture source MSR Info
[ -z "$MSR_HOSTNAME" ] && read -p "Enter the SOURCE DTR hostname and press [ENTER]: " MSR_HOSTNAME
[ -z "$MSR_USER" ] && read -p "Enter the SOURCE DTR username and press [ENTER]: " MSR_USER
[ -z "$MSR_PASSWORD" ] && read -s -p "Enter the SOURCE DTR token or password and press [ENTER]: " MSR_PASSWORD

echo -e "\nProcessing ....."
MEMBERS_FILE=/var/tmp/dtr-members-$$
ADMINS_FILE=/var/tmp/dtr-admins-$$

## Extract all orgs
nss=$(curl -ks -u ${MSR_USER}:${MSR_PASSWORD} "https://${MSR_HOSTNAME}/enzi/v0/accounts?filter=orgs&limit=9999" -H "accept: application/json" | \
       jq -r -c '.accounts[] | select((.isOrg == true) and (.name != "docker-datacenter")) | .name')

## Loop through namespaces to get users
while IFS= read -r namespace ; do
  member_list=$(curl -ksLS -u ${MSR_USER}:${MSR_PASSWORD} -X GET "https://$MSR_HOSTNAME/enzi/v0/accounts/${namespace}/members?pageSize=9999&count=true" | \
    jq '[.members[] | select(.isAdmin == false) | .member.name]' | jq -r -c 'sort')
  admin_list=$(curl -ksLS -u ${MSR_USER}:${MSR_PASSWORD} -X GET "https://$MSR_HOSTNAME/enzi/v0/accounts/${namespace}/members?pageSize=9999&count=true" | \
    jq '[.members[] | select((.member.name != "admin") and (.isAdmin == true)) | .member.name]' | jq -r -c 'sort')
  [ "[]" == $member_list ] || echo "$namespace: $member_list" >> $MEMBERS_FILE
  [ "[]" == $admin_list ] ||  echo "$namespace: $admin_list" >> $ADMINS_FILE
done <<< "$nss"

#echo -e "====== PROCESSING COMPLETE ======"
#echo -e "Check the contents of the files:\n $MEMBERS_FILE and $ADMINS_FILE"
#echo -e "=================================\n"

## Capture destination MSR Info
[ -z "$DEST_MSR_HOSTNAME" ] && read -p "Enter the DESTINATION MSR hostname and press [ENTER]: " DEST_MSR_HOSTNAME
[ -z "$DEST_MSR_USER" ] && read -p "Enter the DESTINATION MSR username and press [ENTER]: " DEST_MSR_USER
[ -z "$DEST_MSR_PASSWORD" ] && read -s -p "Enter the DESTINATION MSR token or password and press [ENTER]: " DEST_MSR_PASSWORD

admins=$(cat $ADMINS_FILE)
while IFS= read -r line ; do
  ns=$(echo $line | awk -F': [[]"|","' '{sub(/"]$/,""); print $1}')
  echo $line | awk -F': [[]"|","' '{sub(/"]$/,""); for (i=2; i<=NF; i++) print $i}' | \
    xargs -I{} curl -ksLS -u ${DEST_MSR_USER}:${DEST_MSR_PASSWORD} -X PUT "https://${DEST_MSR_HOSTNAME}/enzi/v0/accounts/${ns}/members/{}" -H "Content-Type: application/json" -d '{"isAdmin":true}'
done <<< "$admins"
