#!/bin/bash
## Configures Mirror on the repositories

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

[ -z "$REPO_MIRROR_ENABLE" ] && REPO_MIRROR_ENABLE=true

## Extract repositories info
REPO_FILE=/var/tmp/msr-repos-$REMOTE_MSR_HOSTNAME-$$
curl -ks -u ${REMOTE_MSR_USER}:${REMOTE_MSR_PASSWORD} -X GET "https://${REMOTE_MSR_HOSTNAME}/api/v0/repositories/${NAMESPACE}?pageSize=100000&count=true" -H "accept: application/json" | jq .repositories > $REPO_FILE
repos=$(cat $REPO_FILE)
## Read repositories file
repo_list=$(echo "${repos}" | jq -c -r '.[]')
echo "Captured repositoies list in $REPO_FILE"
CURLOPTS=(-kLsS -u ${MSR_USER}:${MSR_PASSWORD} -H 'accept: application/json' -H 'content-type: application/json')

# Loop through repositories
while IFS= read -r row ; do
    namespace=$(echo "$row" | jq -r .namespace)
    reponame=$(echo "$row" | jq -r .name)
    repodetails=$(echo "$row" | jq 'del(.id)')

    response=$(curl --write-out '%{http_code}' "${CURLOPTS[@]}" -X POST -d "$repodetails" https://${MSR_HOSTNAME}/api/v0/repositories/${namespace})
    http_code=$(tail -n1 <<< "$response" | sed 's/}//')
    content=$(sed '$ d' <<< "$response")

    if [ x"$http_code" == x"200" ]; then
        status="CREATED"
    elif [ x"$http_code" == x"400" ]; then
        status="EXISTS"
    elif [ x"$http_code" == x"404" ]; then
        status="NO_SUCH_ACCOUNT"
    fi

    ## Get existing mirroring policies
    pollMirroringPolicies=$(curl "${CURLOPTS[@]}" -X GET \
        "https://${MSR_HOSTNAME}/api/v0/repositories/${namespace}/${reponame}/pollMirroringPolicies")

    num_mirrors=$(echo $pollMirroringPolicies | jq 'length')

    if [ "$num_mirrors" -eq "0" ]; then
        ## Post data for mirror
        mirrordata=$(echo { \"rules\": [], \"username\": \"${REMOTE_USER}\", \"password\": \"${REMOTE_TOKEN}\", \"localRepository\": \"${namespace}/${reponame}\", \"remoteHost\": \"${REMOTE_URL}\", \"remoteRepository\": \"${namespace}/${reponame}\", \"remoteCA\": \"\", \"skipTLSVerification\": true, \"tagTemplate\": \"%n\", \"enabled\": $REPO_MIRROR_ENABLE })

        response=$(curl "${CURLOPTS[@]}" -X POST -d "$mirrordata" \
            "https://${MSR_HOSTNAME}/api/v0/repositories/${namespace}/${reponame}/pollMirroringPolicies?initialEvaluation=true")

        mirror_status="CREATED"
    elif [ "$num_mirrors" -gt "0" ]; then
        mirror_status="EXISTS"
    else
        mirror_status="ERROR"
    fi
    echo "Repo: ${namespace}/${reponame}, Status: ${status}, Mirror Policy: ${mirror_status}"
done <<< "$repo_list"
echo "=========================================\\n"
