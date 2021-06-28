#!/bin/bash

## Capture MSR Info
[ -z "$MSR_HOSTNAME" ] && read -p "Enter the OLD MSR hostname and press [ENTER]: " MSR_HOSTNAME
[ -z "$MSR_USER" ] && read -p "Enter the OLD MSR username and press [ENTER]: " MSR_USER
[ -z "$MSR_PASSWORD" ] && read -s -p "Enter the OLD MSR token or password and press [ENTER]: " MSR_PASSWORD

echo -e "\nProcessing ....."
MEMBERS_FILE=/var/tmp/dtr-members-$$
ADMINS_FILE=/var/tmp/dtr-admins-$$

## Extract all namespaces
nss=$(curl -ks -u ${MSR_USER}:${MSR_PASSWORD} "https://${MSR_HOSTNAME}/enzi/v0/accounts?filter=orgs&limit=1000" -H "accept: application/json" | \
       jq -r -c '.accounts[] | select((.isOrg == true) and (.name != "docker-datacenter")) | .name')

## Loop through namespaces to get users
while IFS= read -r namespace ; do
  member_list=$(curl -ksLS -u ${MSR_USER}:${MSR_PASSWORD} -X GET "https://$MSR_HOSTNAME/enzi/v0/accounts/${namespace}/members?pageSize=1000&count=true" | \
    jq -r -c '[.members[] | select(.isAdmin == false) | .member.name]')
  admin_list=$(curl -ksLS -u ${MSR_USER}:${MSR_PASSWORD} -X GET "https://$MSR_HOSTNAME/enzi/v0/accounts/${namespace}/members?pageSize=1000&count=true" | \
    jq -r -c '[.members[] | select((.member.name != "admin") and (.isAdmin == true)) | .member.name]')
  [ "[]" == $member_list ] || echo "$namespace: $member_list" >> $MEMBERS_FILE
  [ "[]" == $admin_list ] ||  echo "$namespace: $admin_list" >> $ADMINS_FILE
done <<< "$nss"

echo -e "====== PROCESSING COMPLETE ======"
echo -e "Check the contents of the files:\n $MEMBERS_FILE and $ADMINS_FILE"
echo -e "=================================\n"
