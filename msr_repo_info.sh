#!/bin/bash

## Capture MSR Info
[ -z "$MSR_HOSTNAME" ] && read -p "Enter the MSR hostname and press [ENTER]:" MSR_HOSTNAME
[ -z "$MSR_USER" ] && read -p "Enter the MSR username and press [ENTER]:" MSR_USER
[ -z "$MSR_PASSWORD" ] && read -s -p "Enter the MSR token or password and press [ENTER]:" MSR_PASSWORD

echo "***************************************\\n"
[ -z "$REPOS_FILE" ] && read -p "Repositories file(repositories.json):" REPOS_FILE
[ -z "$REPOS_WITH_TAGS" ] && read -p "Repositories with tags file(repo_tags.txt):" REPOS_WITH_TAGS
[ -z "$REPOS_COUNT_FILE" ] && read -s -p "Repository Count file(repo_count.txt):" REPOS_COUNT_FILE
echo "***************************************\\n"

REPOS_FILE=${1:-repositories.json}
REPOS_WITH_TAGS=${2:-repo_tags.txt}
REPOS_COUNT_FILE=${3:-repo_count.txt}

## Empty files
: > $REPOS_FILE
: > $REPOS_WITH_TAGS
: > $REPOS_COUNT_FILE

## Extract repositories info
repos=$(curl -ks -u ${MSR_USER}:${MSR_PASSWORD} -X GET "https://${MSR_HOSTNAME}/api/v0/repositories?pageSize=100000&count=true" -H "accept: application/json" | jq .repositories)
repo_num=$(echo $repos | jq 'length')
repo_list=$(echo "${repos}" | jq -c -r '.[]')
# # Loop through repos to get total tags
tags=0
while IFS= read -r row ; do
    namespace=$(echo "$row" | jq -r .namespace)
    reponame=$(echo "$row" | jq -r .name)
    tag_list=$(curl -ksLS -u ${MSR_USER}:${MSR_PASSWORD} -X GET "https://$MSR_HOSTNAME/api/v0/repositories/${namespace}/${reponame}/tags?pageSize=10000000")
    tag_count=$(echo "$tag_list" | jq 'length' )
    tag_names=$(echo "$tag_list" | jq -r .[].name)
    
    if ((tag_count > 0)); then
      for tag in $tag_names;
      do
        echo "${namespace}/${reponame}:${tag}" >> $REPOS_WITH_TAGS
      done
    fi

    echo "Org: ${namespace}, Repo: ${reponame}, Tags: ${tag_count}"
    echo "Org: ${namespace}, Repo: ${reponame}, Tags: ${tag_count}" >> $REPOS_COUNT_FILE
    
    tags=$(($tags + $tag_count))
done <<< "$repo_list"

echo "========================================="  >> $REPOS_COUNT_FILE
echo "Total Repos: ${repo_num}" >> $REPOS_COUNT_FILE
echo "Total Tags: ${tags}" >> $REPOS_COUNT_FILE

echo "Saving results to ${REPOS_FILE}, ${REPOS_WITH_TAGS}, ${REPOS_COUNT_FILE}"
echo $repos > ${REPOS_FILE}