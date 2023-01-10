#!/bin/bash
## Configures Mirror on the repositories
set -x
if [ $# -gt 0 ]
  then
    source $1
fi

## Capture MSR Info
echo "********** SOURCE MSR TO CONFIGURE MIRROR (Mirror Policy is created here) ******************"
[ -z "$SOURCE_MSR" ] && read -p "Enter the MSR hostname and press [ENTER]:" SOURCE_MSR
[ -z "$SOURCE_MSR_USER" ] && read -p "Enter the MSR username and press [ENTER]:" SOURCE_MSR_USER
[ -z "$SOURCE_MSR_PASSWORD" ] && read -s -p "Enter the MSR token or password and press [ENTER]:" SOURCE_MSR_PASSWORD
echo "********* REMOTE MSR CONFIG - Location to pull images from (Old MSR) ***********\\n"
[ -z "$DEST_MSR" ] && read -p "Enter the REMOTE MSR hostname and press [ENTER]:" DEST_MSR
[ -z "$DEST_MSR_USER" ] && read -p "Enter the MSR username and press [ENTER]:" DEST_MSR_USER
[ -z "$DEST_MSR_PASSWORD" ] && read -s -p "Enter the MSR token or password and press [ENTER]:" DEST_MSR_PASSWORD

echo ""
echo "***************************************\\n"

DEST_USER=${DEST_MSR_USER}
DEST_TOKEN=${DEST_MSR_PASSWORD}
DEST_URL="https://${DEST_MSR}"

[ -z "$REPO_FILE" ] && read -p "Repositories file(repositories.json):" REPO_FILE

CURLOPTS=(-kLsS -u ${SOURCE_MSR_USER}:${SOURCE_MSR_PASSWORD} -H 'accept: application/json' -H 'content-type: application/json')

## Read repositories file
repo_list=$(cat ${REPO_FILE} | jq -c -r '.[]') 

# Loop through repositories
while IFS= read -r row ; do
    namespace=$(echo "$row" | jq -r .namespace)
    reponame=$(echo "$row" | jq -r .name)

    ## Get existing mirroring policies
    pollMirroringPolicies=$(curl "${CURLOPTS[@]}" -X GET \
        "https://${SOURCE_MSR}/api/v0/repositories/${namespace}/${reponame}/pollMirroringPolicies")

    num_mirrors=$(echo $pollMirroringPolicies | jq 'length')
    if [ "$num_mirrors" -eq "0" ]; then
        ## Post data for mirror
        mirrordata=$(echo { \"rules\": [], \"username\": \"${DEST_USER}\", \"password\": \"${DEST_TOKEN}\", \"localRepository\": \"${namespace}/${reponame}\", \"remoteHost\": \"${DEST_URL}\", \"remoteRepository\": \"${namespace}/${reponame}\", \"remoteCA\": \"\", \"skipTLSVerification\": true, \"tagTemplate\": \"%n\", \"enabled\": false })

        response=$(curl "${CURLOPTS[@]}" -X POST -d "$mirrordata" \
            "https://${SOURCE_MSR}/api/v0/repositories/${namespace}/${reponame}/pollMirroringPolicies?initialEvaluation=true")

        echo "Configured mirror on repo ${namespace}/${reponame}"
    elif [ "$num_mirrors" -gt "0" ]; then
        echo "Mirror already configured on ${namespace}/${reponame}"
    else
        echo "Error configuring mirror on ${namespace}/${reponame}"
    fi

done <<< "$repo_list"
echo "=========================================\\n"
