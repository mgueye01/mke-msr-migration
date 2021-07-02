#!/bin/bash

## Extract all namespaces
admins=$(cat old-dtr-admins)

## Loop through namespaces to get users
while IFS= read -r line ; do
  ns=$(echo $line | awk -F': [[]"|","' '{sub(/"]$/,""); print $1}')
  echo "namespace: $ns"
  echo "====="
  echo $line | awk -F': [[]"|","' '{sub(/"]$/,""); for (i=2; i<=NF; i++) print $i}' | xargs -I{} echo "hello {} is part of $ns"

  echo "====="
done <<< "$admins"
