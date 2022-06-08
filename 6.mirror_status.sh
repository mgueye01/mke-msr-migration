#!/bin/bash

if [ $# -gt 0 ]
  then
    source $1
fi

## Capture MSR Info
[ -z "$MSR_HOSTNAME" ] && read -p "Enter the MSR hostname and press [ENTER]:" MSR_HOSTNAME
[ -z "$MSR_USER" ] && read -p "Enter the MSR username and press [ENTER]:" MSR_USER
[ -z "$MSR_PASSWORD" ] && read -s -p "Enter the MSR token or password and press [ENTER]:" MSR_PASSWORD
echo "********* REMOTE MSR CONFIG - Location to pull images from (Old MSR) ***********\\n"
[ -z "$REMOTE_MSR_HOSTNAME" ] && read -p "Enter the REMOTE MSR hostname and press [ENTER]:" REMOTE_MSR_HOSTNAME
[ -z "$REMOTE_MSR_USER" ] && read -p "Enter the MSR username and press [ENTER]:" REMOTE_MSR_USER
[ -z "$REMOTE_MSR_PASSWORD" ] && read -s -p "Enter the MSR token or password and press [ENTER]:" REMOTE_MSR_PASSWORD
echo ""
echo "***************************************\\n"

[ -z "$REPO_FILE" ] && read -p "Repositories file(repositories.json):" REPO_FILE

CURLOPTS=(-kLsS -u ${MSR_USER}:${MSR_PASSWORD} -H 'accept: application/json' -H 'content-type: application/json')
REMOTE_CURLOPTS=(-kLsS -u ${REMOTE_MSR_USER}:${REMOTE_MSR_PASSWORD} -H 'accept: application/json' -H 'content-type: application/json')

## Read repositories file
repo_list=$(cat ${REPO_FILE} | jq -c -r '.[]') 

# Loop through repositories
while IFS= read -r row ; do
    namespace=$(echo "$row" | jq -r .namespace)
    reponame=$(echo "$row" | jq -r .name)
    status="Not Enabled"
    tag_count=0
    remote_tag_count=0

    ## Get Tags from Source MSR
    tags=$(curl "${CURLOPTS[@]}" -X GET \
        "https://${MSR_HOSTNAME}/api/v0/repositories/${namespace}/${reponame}/tags?pageSize=10000000")
    tag_count=$(echo "$tags" | jq 'length' )
    ## Get Tags from Destination MSR
    tags_remote=$(curl "${REMOTE_CURLOPTS[@]}" -X GET \
        "https://${REMOTE_MSR_HOSTNAME}/api/v0/repositories/${namespace}/${reponame}/tags?pageSize=10000000")
    remote_tag_count=$(echo "$tags_remote" | jq 'length' )

    ## Get existing mirroring policies
    pollMirroringPolicies=$(curl "${CURLOPTS[@]}" -X GET \
        "https://${MSR_HOSTNAME}/api/v0/repositories/${namespace}/${reponame}/pollMirroringPolicies")

    policies_num=$(echo $repos | jq 'length')
    policies=$(echo $pollMirroringPolicies | jq -c -r '.[]')
    while IFS= read -r policy; do
        id=$(echo $policy | jq -r .id)
        enabled=$(echo $policy | jq -r .enabled)
        if [ "x$enabled" == "xtrue" ]
        then
            lastStatus=$(echo $policy | jq -r .lastStatus.code)
            if [ "x$remote_tag_count" == "x0" ]
            then
                lastStatus="SUCCESS"
            fi
            ## Repo, enabled, source_tags, destination_tags, last_status
            echo "$namespace/$reponame,$enabled,$tag_count,$remote_tag_count,$lastStatus"
            #echo "${namespace}/${reponame}, PolicyId: ${id}, Enabled: ${enabled} ==> Status: ${lastStatus}"
        else
            echo "$namespace/$reponame,Mirror Not Enabled on this repository"
            #echo "Repo: ${namespace}/${reponame}, PolicyId: ${id}, Enabled: ${enabled}"
        fi
        id=
        enabled=
        status=
    done <<< "$policies"
done <<< "$repo_list"
echo "=========================================\\n"