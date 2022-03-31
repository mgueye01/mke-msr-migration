#!/bin/bash

## Update Tag Limits
if [ $# -gt 0 ]
  then
    source $1
fi

## Capture MSR Info
[ -z "$MSR_HOSTNAME" ] && read -p "Enter the MSR hostname and press [ENTER]:" MSR_HOSTNAME
[ -z "$MSR_USER" ] && read -p "Enter the MSR username and press [ENTER]:" MSR_USER
[ -z "$MSR_PASSWORD" ] && read -s -p "Enter the MSR token or password and press [ENTER]:" MSR_PASSWORD

echo "***************************************\\n"
[ -z "$NAMESPACE" ] && read -p "Org/Namespace(all):" NAMESPACE
[ -z "$REPO_FILE" ] && read -p "Repositories file(repositories.json):" REPO_FILE
[ -z "$REPO_TAG_LIMIT" ] && read -p "Tag limit for the repositories($NAMESPACE):" REPO_TAG_LIMIT
echo "***************************************\\n"

## Set defaults
[ -z "$NAMESPACE" ] && NAMESPACE=""
[ -z "$REPO_FILE" ] && REPO_FILE="${NAMESPACE}_repositories.json"

## Read repositories file
repo_list=$(cat ${REPO_FILE} | jq -c -r '.[]') 

## CURLOPTS
CURLOPTS=(-kLsS -H 'accept: application/json' -H 'content-type: application/json')

# Loop through repositories
while IFS= read -r row ; do
    namespace=$(echo "$row" | jq -r .namespace)
    reponame=$(echo "$row" | jq -r .name)
    data=$(echo {\"tagLimit\": $REPO_TAG_LIMIT })
    curl "${CURLOPTS[@]}" -u ${MSR_USER}:${MSR_PASSWORD} -X PATCH -d "$data" https://${MSR_HOSTNAME}/api/v0/repositories/${namespace}/${reponame}
    echo "Patched ==> Org: ${namespace}, Repo: ${reponame}"
done <<< "$repo_list"
echo "=========================================\\n"