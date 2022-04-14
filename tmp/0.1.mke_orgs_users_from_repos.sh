#!/bin/bash

source $1
## Capture MSR Info
[ -z "$MKE_HOSTNAME" ] && read -p "Enter the MSR hostname and press [ENTER]:" MKE_HOSTNAME
[ -z "$MKE_USER" ] && read -p "Enter the MSR username and press [ENTER]:" MKE_USER
[ -z "$MKE_PASSWORD" ] && read -s -p "Enter the MSR token or password and press [ENTER]:" MKE_PASSWORD

[ -z "$REPOS_FILE" ] && read -p "Repositories file(repositories.json):" REPOS_FILE
REPOSITORIES_FILE=repositories.json

# use your UCP username and password to acquire a UCP API auth token
auth_data=$(echo {\"username\": \"$MKE_USER\" ,\"password\": \"$MKE_PASSWORD\" })
AUTHTOKEN=$(curl -sk -d "${auth_data}" https://${MKE_HOSTNAME}/auth/login | awk -F ':' '{print $2}' | tr -d '"{}')
CURLOPTS=(-kLsS -H 'accept: application/json' -H 'content-type: application/json' -H "Authorization: Bearer ${AUTHTOKEN}")

## Read repositories file
repo_list=$(cat ${REPOSITORIES_FILE} | jq -c -r '.[]') 
REPO_TYPE_FILE=/tmp/repotype-$$
cat ${REPOSITORIES_FILE} | jq -r '.[] | "\(.namespace),\(.namespaceType)"' | uniq > $REPO_TYPE_FILE
for i in `cat $REPO_TYPE_FILE`; do
    ## Create NS of type Org and User
    nsType=$(echo $i | cut -f2 -d",")
    ns=$(echo $i | cut -f1 -d",")
    if [[ "organization" == $nsType ]]; then
        data=$(echo {\"isOrg\": true ,\"name\": \"$ns\" })
    else
        data=$(echo {\"isActive\": true, \"isOrg\": false ,\"name\": \"$ns\",\"password\": \"$MKE_PASSWORD\" })
    fi
    RESPONSE=$(curl "${CURLOPTS[@]}" -sk -X POST -d "${data}" https://${MKE_HOSTNAME}/accounts)
    echo $RESPONSE
    #curl 
done

exit

# Loop through repositories
while IFS= read -r row ; do
    namespace=$(echo "$row" | jq -r .namespace)
    namespace_type=$(echo "$row" | jq -r .namespaceType)
    reponame=$(echo "$row" | jq -r .name)
    repodetails=$(echo "$row" | jq 'del(.id)')

    # TODO: Check if repository exists
    # Create a repository with the settings read from repo_list
#    curl "${CURLOPTS[@]}" -X POST -d "$repodetails" https://${DTR_HOSTNAME}/api/v0/repositories/${namespace}
#    echo "Created ==> Org: ${namespace}, Repo: ${reponame}"
    echo "Namespace: ${namespace}, Type: ${namespace_type}"
done <<< "$repo_list"
echo "=========================================\\n"
