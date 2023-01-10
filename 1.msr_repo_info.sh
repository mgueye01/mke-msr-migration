#!/bin/bash
# set -x
if [ $# -gt 0 ]
  then
  source $1
fi

## Capture MSR Info
[ -z "$SOURCE_MSR" ] && read -p "Enter the MSR hostname and press [ENTER]:" SOURCE_MSR
[ -z "$SOURCE_MSR_USER" ] && read -p "Enter the MSR username and press [ENTER]:" SOURCE_MSR_USER
[ -z "$SOURCE_MSR_PASSWORD" ] && read -s -p "Enter the MSR token or password and press [ENTER]:" SOURCE_MSR_PASSWORD

printf "***************************************\\n"
[ -z "$NAMESPACE" ] && read -p "Org/Namespace(all):" NAMESPACE
[ -z "$REPO_FILE" ] && read -p "Repositories file(repositories.json):" REPO_FILE
[ -z "$REPO_TAG_INFO" ] && read -p "Repositories with tags info(repo_tags.txt):" REPO_TAG_INFO
[ -z "$REPO_COUNT_FILE" ] && read -p "Repository Count file(repo_count.txt):" REPO_COUNT_FILE
printf "***************************************\\n"

## Set defaults
[ "$NAMESPACE" == "all" ] && NAMESPACE=""
[ -z "$REPO_FILE" ] && REPO_FILE="${NAMESPACE}repositories.json"
[ -z "$REPO_TAG_INFO" ] && REPO_TAG_INFO="${NAMESPACE}repo_tags.txt"
[ -z "$REPO_COUNT_FILE" ] && REPO_COUNT_FILE="${NAMESPACE}repo_count.txt"

## Reset file content
#: > $REPO_FILE
: > $REPO_TAG_INFO
: > $REPO_COUNT_FILE

## Extract repositories info
curl -ks -u ${SOURCE_MSR_USER}:${SOURCE_MSR_PASSWORD} -X GET "https://${SOURCE_MSR}/api/v0/repositories/${NAMESPACE}?pageSize=100000&count=true" -H "accept: application/json" | jq .repositories > $REPO_FILE
repos=$(cat $REPO_FILE)

repo_num=$(echo $repos | jq 'length')
repo_list=$(echo "${repos}" | jq -c -r '.[]')

# Loop through repos to get total tags & tag info
tags=0
while IFS= read -r row ; do
    namespace=$(echo "$row" | jq -r .namespace)
    reponame=$(echo "$row" | jq -r .name)
    tag_list=$(curl -ksLS -u ${SOURCE_MSR_USER}:${SOURCE_MSR_PASSWORD} -X GET "https://$SOURCE_MSR/api/v0/repositories/${namespace}/${reponame}/tags?pageSize=10000000")
    tag_count=$(echo "$tag_list" | jq 'length' )
    tag_names=$(echo "$tag_list" | jq -r .[].name)
    for item in $(echo "${tag_list}" | jq -r '.[] | @base64'); do
      _jq() {
        echo ${item} | base64 --decode
      }
      echo ${namespace},${reponame},$(_jq | jq -r '[.name, .createdAt, .updatedAt] | @csv') >> $REPO_TAG_INFO
    done

    echo "Org: ${namespace}, Repo: ${reponame}, Tags: ${tag_count}"
    echo "Org: ${namespace}, Repo: ${reponame}, Tags: ${tag_count}" >> $REPO_COUNT_FILE

    [ -z "$tag_count" ] && tag_count=0
    tags=$(($tags + $tag_count))
done <<< "$repo_list"

echo "========================================="  >> $REPO_COUNT_FILE
echo "Total Repos: ${repo_num}" >> $REPO_COUNT_FILE
echo "Total Tags: ${tags}" >> $REPO_COUNT_FILE

echo "Saving results to ${REPO_FILE}, ${REPO_TAG_INFO}, ${REPO_COUNT_FILE}"
