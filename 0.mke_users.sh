#!/bin/bash
# set -x
## Pass the env file (Optional)
if [ $# -gt 0 ]
    then
    source $1
fi

## Capture SOURCE MKE Info
[ -z "$SOURCE_MKE" ] && read -pr "Enter the MKE hostname and press [ENTER]:" SOURCE_MKE
[ -z "$SOURCE_MKE_USER" ] && read -pr "Enter the MKE username and press [ENTER]:" SOURCE_MKE_USER
[ -z "$SOURCE_MKE_PASSWORD" ] && read -s -pr "Enter the MKE token or password and press [ENTER]:" SOURCE_MKE_PASSWORD

## Capture DEST_MKE Info
[ -z "$DEST_CREATE" ] && read -pr "Create objects in the target cluster(true or false) and press [ENTER]:" DEST_CREATE

if $DEST_CREATE;
then
    printf "Capture Destination MKE Info...\n"
    [ -z "$DEST_MKE" ] && read -pr "Enter the MKE hostname and press [ENTER]:" DEST_MKE
    [ -z "$DEST_MKE_USER" ] && read -pr "Enter the MKE username and press [ENTER]:" DEST_MKE_USER
    [ -z "$DEST_MKE_PASSWORD" ] && read -s -pr "Enter the MKE token or password and press [ENTER]:" DEST_MKE_PASSWORD
fi

function getAccessToken() {
    MKE_FQDN=$1
    USER=$2
    PASSWD=$3

    # use your UCP username and password to acquire a UCP API auth token
    data=$(echo {\"username\": \"$USER\" ,\"password\": \"$PASSWD\" })
    AUTHTOKEN=$(curl -sk -d "${data}" https://${MKE_FQDN}/auth/login | awk -F ':' '{print $2}' | tr -d '"{}')

    echo "$AUTHTOKEN"
}

SRC_TOKEN=$(getAccessToken $SOURCE_MKE $SOURCE_MKE_USER $SOURCE_MKE_PASSWORD)
DEST_TOKEN=$(getAccessToken $DEST_MKE $DEST_MKE_USER $DEST_MKE_PASSWORD)

LIMIT=10000
CURLOPTS=(-kLsS -H 'accept: application/json' -H "Authorization: Bearer ${SRC_TOKEN}")
DEST_CURLOPTS=(-kLsSi -H 'accept: application/json' -H "Authorization: Bearer ${DEST_TOKEN}" -H "Content-Type: application/json")

## Get all accounts
echo "Requesting all the accounts..."
accounts=$(curl "${CURLOPTS[@]}" -X GET "https://$SOURCE_MKE/accounts/?filter=all&limit=$LIMIT" | jq -r .accounts)

echo "$accounts" > accounts.json

## Get Orgs
echo "Getting Org names..."
orgs=$(curl "${CURLOPTS[@]}" -X GET "https://$SOURCE_MKE/accounts/?filter=orgs&limit=$LIMIT" | jq -r .accounts[].name)

## Get Teams
for ORG in $orgs;
do
    if [ "$ORG" != "docker-datacenter" ]
    then
        if $DEST_CREATE;
        then
            echo "Creating org: $ORG"
            data=$(echo {\"isOrg\": true, \"name\": \"$ORG\" })
            ORG_RESPONSE=$(curl "${DEST_CURLOPTS[@]}" -sk -X POST -d "${data}" https://${DEST_MKE}/accounts)
        fi

        teams=$(curl "${CURLOPTS[@]}" -X GET "https://$SOURCE_MKE/accounts/$ORG/teams?filter=orgs&limit=$LIMIT" | jq -r .teams[].name)

        for TEAM in $teams;
        do
            ## Create Team
            if $DEST_CREATE;
            then
                ## Get Team Info
                TEAM_INFO=$(curl "${CURLOPTS[@]}" -X GET "https://$SOURCE_MKE/accounts/$ORG/teams/$TEAM")

                TEAM_DESCRIPTION=$(echo $TEAM_INFO | jq -r .description)

                data=$(echo { \"description\": \"${TEAM_DESCRIPTION}\", \"name\": \"${TEAM}\"})

                TEAM_RESPONSE=$(curl "${DEST_CURLOPTS[@]}" -sk -X POST -d "${data}" https://${DEST_MKE}/accounts/${ORG}/teams)

                ## Get memberSyncConfig
                MEMBER_SYNC_CONFIG=$(curl "${CURLOPTS[@]}"  -X GET "https://${SOURCE_MKE}/accounts/${ORG}/teams/${TEAM}/memberSyncConfig")
                MEMBER_SYNC_CONFIG_RESPONSE=$(curl "${DEST_CURLOPTS[@]}" -X PUT "https://${DEST_MKE}/accounts/${ORG}/teams/${TEAM}/memberSyncConfig" -d "$MEMBER_SYNC_CONFIG" )

                ## Get Members
                MEMBERS=$(curl "${CURLOPTS[@]}" -X GET "https://$SOURCE_MKE/accounts/$ORG/teams/$TEAM/members?filter=orgs&limit=$LIMIT" | jq -r .members[].member.name)
                ## If Sync is not enabled add users to team manually
                MEMBER_SYNC_CONFIG_FALSE=$(echo $MEMBER_SYNC_CONFIG | jq -r .enableSync)
                echo $MEMBER_SYNC_CONFIG_FALSE
                if ! $MEMBER_SYNC_CONFIG_FALSE;
                then
                    echo "LDAP Sync for the team($TEAM) is not enabled"
                    echo "Adding members to the team"
                    echo "members -- " $MEMBERS
                    for MEMBER in $MEMBERS;
                    do
                        echo "adding $MEMBER"
                        data=$(echo { \"isAdmin\": false })
                        R=$(curl "${DEST_CURLOPTS[@]}" -X PUT "https://${DEST_MKE}/accounts/${ORG}/teams/${TEAM}/members/${MEMBER}" -d "$data" )
                        # curl "${DEST_CURLOPTS[@]}" -X PUT "https://${DEST_MKE}/accounts/${ORG}/teams/${TEAM}/members/${MEMBER}" -d "$data" 
                    done
                fi
            fi
            echo $ORG "->" $TEAM "-> (" $MEMBERS ")"
        done
    fi
done
