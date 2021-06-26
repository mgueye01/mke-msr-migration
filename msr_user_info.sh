#!/bin/bash

## Capture MSR Info
[ -z "$MSR_HOSTNAME" ] && read -p "Enter the MSR hostname and press [ENTER]:" MSR_HOSTNAME
[ -z "$MSR_USER" ] && read -p "Enter the MSR username and press [ENTER]:" MSR_USER
[ -z "$MSR_PASSWORD" ] && read -s -p "Enter the MSR token or password and press [ENTER]:" MSR_PASSWORD

## Extract all namespaces
nss=$(curl -ks -u ${MSR_USER}:${MSR_PASSWORD} -X GET "https://${MSR_HOSTNAME}/enzi/v0/accounts?filter=orgs" -H "accept: application/json" | \
       jq -r -c '.accounts[] | select((.isOrg == true) and (.name != "docker-datacenter")) | .name')

## Loop through namespaces to get users
while IFS= read -r namespace ; do
  echo $namespace
  member_list=$(curl -ksLS -u ${MSR_USER}:${MSR_PASSWORD} -X GET "https://$MSR_HOSTNAME/enzi/v0/accounts/${namespace}/members?pageSize=1000&count=true" | \
                   jq -r -c '[.members[] | select(.isAdmin == false) | .member.name]')
  admin_list=$(curl -ksLS -u ${MSR_USER}:${MSR_PASSWORD} -X GET "https://$MSR_HOSTNAME/enzi/v0/accounts/${namespace}/members?pageSize=1000&count=true" | \
                   jq -r -c '[.members[] | select(.isAdmin == true) | .member.name]')
  echo "$namespace: $member_list"
  echo "$namespace: $admin_list"
done <<< "$nss"

