#!/bin/bash
#simplify the updating of dtr workers.

if [ $# -gt 0 ]
  then
    source $1
fi

## Capture MKE & MSR Info
[ -z "$MKE_HOSTNAME" ] && read -p "Enter the MKE hostname and press [ENTER]:" MKE_HOSTNAME
[ -z "$MSR_HOSTNAME" ] && read -p "Enter the MSR hostname and press [ENTER]:" MSR_HOSTNAME
[ -z "$MSR_USER" ] && read -p "Enter the MSR username and press [ENTER]:" MSR_USER
[ -z "$MSR_PASSWORD" ] && read -s -p "Enter the MSR token or password and press [ENTER]:" MSR_PASSWORD

###################################
# edit vars
###################################
set -e
echo ""
echo ""
# Expecting the following environment variables to exist so that this script successfully completes. 
# *_server environment variables need only the domain and not the protocol, e.g. ucp.dockr.life.
# username should be an admin user
#
# MKE_HOSTNAME=""
# MSR_SERVER=""
# username=""

######  NO MOAR EDITS #######
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
NORMAL=$(tput sgr0)

#get password.
#read -sp 'password: ' password;
#Expecting the following environment variables to exist so that this script successfully completes:
# password=""

#reset variables
token=""
replicas=""

function get_replicas () {
  echo " connecting to UCP for a token and the list of DTR replicas"

  token=$(curl -sk -d '{"username":"'$MSR_USER'","password":"'$MSR_PASSWORD'"}' https://$MKE_HOSTNAME/auth/login | jq -r .auth_token)
  replicas=$(curl -skX GET "https://$MKE_HOSTNAME/containers/json" -H  "accept: application/json" -H "Authorization: Bearer $token" | jq -r '.[] | select (.Image | contains("docker/dtr-nginx") or contains("mirantis/dtr-nginx") or contains("mirantiseng/dtr-nginx")) | .Labels."com.docker.compose.service" '|sed -e 's/nginx-//g')
}

function list_workers (){
  get_replicas

  echo " connecting to UCP for node name and node NanoCPU values, then connecting to DTR to get capacityMap for each DTR replica."
  for rep in $replicas; do 
    node=$(curl -skX GET "https://$MKE_HOSTNAME/containers/json" -H  "accept: application/json" -H "Authorization: Bearer $token" | jq -r '.[] | select (.Labels."com.docker.compose.service" | tostring | contains("nginx-'$rep'")) | .Labels."com.docker.swarm.constraints" '|sed -e 's/\[\"node==//g' -e 's/\"\]//g')
    node_cpu=$(curl -skX GET "https://$MKE_HOSTNAME/nodes" -H  "accept: application/json" -H "Authorization: Bearer $token" | jq -r '.[] | select (.Description.Hostname | contains("'$node'")) | .Description.Resources.NanoCPUs')

    echo " Node = "$GREEN"$node"$NORMAL" Replica = "$GREEN"$rep"$NORMAL" CPU = "$GREEN"$node_cpu"$NORMAL" "
    curl -skX GET -u $username:$password "https://$MSR_SERVER/api/v0/workers/" -H "accept: application/json" | jq '.workers[] | select (.id | contains("'$rep'")) | .capacityMap ' 
  done
}

function update_workers (){
  get_replicas
  
  echo " updating DTR workers"
  for rep in $replicas; do
    node=$(curl -skX GET "https://$MKE_HOSTNAME/containers/json" -H  "accept: application/json" -H "Authorization: Bearer $token" | jq -r '.[] | select (.Labels."com.docker.compose.service" | tostring | contains("nginx-'$rep'")) | .Labels."com.docker.swarm.constraints" '|sed -e 's/\[\"node==//g' -e 's/\"\]//g')
    node_cpu=$(curl -skX GET "https://$MKE_HOSTNAME/nodes" -H  "accept: application/json" -H "Authorization: Bearer $token" | jq -r '.[] | select (.Description.Hostname | contains("'$node'")) | .Description.Resources.NanoCPUs')

    #calculate core and 1/2 of core.
    node_core=$(( $node_cpu/1000000000 ))
    node_core_half=$(( $node_core/2 ))

    curl -skX POST -u $username:$password "https://$MSR_SERVER/api/v0/workers/$rep/capacity" -H "accept: application/json" -H "content-type: application/json" -d '{ "capacityMap": { "mirror": '$node_core_half', "scan": '$node_core_half', "scanCheck": '$node_core' }}' > /dev/null 2>&1
    echo "  Updated $rep $GREEN" "[ok]" "$NORMAL"

  done
}

function reset (){
  list_workers  

  echo " resetting DTR workers"
  for rep in $replicas; do
    node=$(curl -skX GET "https://$MKE_HOSTNAME/containers/json" -H  "accept: application/json" -H "Authorization: Bearer $token" | jq -r '.[] | select (.Labels."com.docker.compose.service" | tostring | contains("nginx-'$rep'")) | .Labels."com.docker.swarm.constraints" '|sed -e 's/\[\"node==//g' -e 's/\"\]//g')
    curl -skX POST -u $username:$password "https://$MSR_SERVER/api/v0/workers/$rep/capacity" -H "accept: application/json" -H "content-type: application/json" -d '{ "capacityMap": { "mirror": '1', "scan": '1', "scanCheck": '1' }}' > /dev/null 2>&1
    echo "  Updated $rep $GREEN" "[ok]" "$NORMAL"

  done
}

function status (){
  echo " Usage: $0 {"$GREEN"list "$NORMAL" - list current map | "$GREEN" update "$NORMAL" - update map to half core | "$GREEN" reset "$NORMAL" - reset values to 1}"
  exit 1
}

#better error checking
command -v curl >/dev/null 2>&1 || { echo "$RED" " ** Curl was not found. Please install before preceeding. ** " "$NORMAL" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || { echo "$RED" " ** Jq was not found. Please install before preceeding. ** " "$NORMAL" >&2; exit 1; }

case "$2" in
        list) list_workers;;
        update) update_workers;;
        reset) reset;;
        *) status
esac