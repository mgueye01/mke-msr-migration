#!/bin/bash

if [ $# -gt 0 ]
  then
    source $1
fi

## Capture DTR Info
[ -z "$DEST_MSR" ] && read -p "Enter the DTR hostname and press [ENTER]:" DEST_MSR
[ -z "$DEST_MSR_USER" ] && read -p "Enter the DTR username and press [ENTER]:" DEST_MSR_USER
[ -z "$DEST_MSR_PASSWORD" ] && read -s -p "Enter the DTR token or password and press [ENTER]:" DEST_MSR_PASSWORD
echo "***************************************\\n"
[ -z "$REPOS_FILE" ] && read -p "Repositories file(repositories.json):" REPOS_FILE
REPOSITORIES_FILE=repositories.json

TOKEN=$(curl -kLsS -u ${DEST_MSR_USER}:${DEST_MSR_PASSWORD} "https://${DEST_MSR}/auth/token" | jq -r '.token')
CURLOPTS=(-kLsS -H 'accept: application/json' -H 'content-type: application/json' -H "Authorization: Bearer ${TOKEN}")

## Read repositories file
repo_list=$(cat ${REPOSITORIES_FILE} | jq -c -r '.[]') 

# Loop through repositories
while IFS= read -r row ; do
    namespace=$(echo "$row" | jq -r .namespace)
    reponame=$(echo "$row" | jq -r .name)
    repodetails=$(echo "$row" | jq 'del(.id)')

    # TODO: Check if repository exists
    # Create a repository with the settings read from repo_list
    curl "${CURLOPTS[@]}" -X POST -d "$repodetails" https://${DEST_MSR}/api/v0/repositories/${namespace}
    echo "Created ==> Org: ${namespace}, Repo: ${reponame}"
done <<< "$repo_list"
echo "=========================================\\n"
