#!/bin/bash

if [ $# -gt 0 ]
  then
    source $1
fi

## Capture MSR Info
echo "********** SOURCE MSR TO CONFIGURE MIRROR (Mirror Policy is created here) ******************"
[ -z "$MSR_HOSTNAME" ] && read -p "Enter the MSR hostname and press [ENTER]:" MSR_HOSTNAME
[ -z "$MSR_USER" ] && read -p "Enter the MSR username and press [ENTER]:" MSR_USER
[ -z "$MSR_PASSWORD" ] && read -s -p "Enter the MSR token or password and press [ENTER]:" MSR_PASSWORD
echo "********* REMOTE MSR CONFIG - Location to pull images from (Old MSR) ***********\\n"
[ -z "$REMOTE_MSR_HOSTNAME" ] && read -p "Enter the REMOTE MSR hostname and press [ENTER]:" REMOTE_MSR_HOSTNAME
[ -z "$REMOTE_MSR_USER" ] && read -p "Enter the MSR username and press [ENTER]:" REMOTE_MSR_USER
[ -z "$REMOTE_MSR_PASSWORD" ] && read -s -p "Enter the MSR token or password and press [ENTER]:" REMOTE_MSR_PASSWORD

echo ""
echo "***************************************\\n"

REMOTE_USER=${REMOTE_MSR_USER}
REMOTE_TOKEN=${REMOTE_MSR_PASSWORD}
REMOTE_URL="https://${REMOTE_MSR_HOSTNAME}"

[ -z "$REPO_FILE" ] && read -p "Repositories file(repositories.json):" REPO_FILE

TOKEN=$(curl -kLsS -u ${MSR_USER}:${MSR_PASSWORD} "https://${MSR_HOSTNAME}/auth/token" | jq -r '.token')
CURLOPTS=(-kLsS -H 'accept: application/json' -H 'content-type: application/json' -H "Authorization: Bearer ${TOKEN}")

## Read repositories file
repo_list=$(cat ${REPO_FILE} | jq -c -r '.[]') 

# Loop through repositories
while IFS= read -r row ; do
    namespace=$(echo "$row" | jq -r .namespace)
    reponame=$(echo "$row" | jq -r .name)

    ## Get existing mirroring policies
    pollMirroringPolicies=$(curl "${CURLOPTS[@]}" -X GET \
        "https://${MSR_HOSTNAME}/api/v0/repositories/${namespace}/${reponame}/pollMirroringPolicies")

    num_mirrors=$(echo $pollMirroringPolicies | jq 'length')
    if [ "$num_mirrors" -eq "0" ]; then
        ## Post data for mirror
        mirrordata=$(echo { \"rules\": [], \"username\": \"${REMOTE_USER}\", \"password\": \"${REMOTE_TOKEN}\", \"localRepository\": \"${namespace}/${reponame}\", \"remoteHost\": \"${REMOTE_URL}\", \"remoteRepository\": \"${namespace}/${reponame}\", \"remoteCA\": \"\", \"skipTLSVerification\": true, \"tagTemplate\": \"%n\", \"enabled\": false })

        response=$(curl "${CURLOPTS[@]}" -X POST -d "$mirrordata" \
            "https://${MSR_HOSTNAME}/api/v0/repositories/${namespace}/${reponame}/pollMirroringPolicies?initialEvaluation=true")

        echo $response
        echo "Configured mirror on repo ${namespace}/${reponame}"
    else
        echo "Mirror already configured on ${namespace}/${reponame}"
    fi

done <<< "$repo_list"
echo "=========================================\\n"
