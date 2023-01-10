#!/bin/bash
# set -x
if [ $# -gt 0 ]
  then
  source $1
fi
## Capture SOURCE MSR Info
[ -z "$SOURCE_MSR" ] && read -p "Enter the MSR hostname and press [ENTER]:" SOURCE_MSR
[ -z "$SOURCE_MSR_USER" ] && read -p "Enter the MSR username and press [ENTER]:" SOURCE_MSR_USER
[ -z "$SOURCE_MSR_PASSWORD" ] && read -s -p "Enter the MSR token or password and press [ENTER]:" SOURCE_MSR_PASSWORD
echo ""

echo "Capture Destination MSR Info...\n"
[ -z "$DEST_MSR" ] && read -p "Enter the MSR hostname and press [ENTER]:" DEST_MSR
[ -z "$DEST_MSR_USER" ] && read -p "Enter the MSR username and press [ENTER]:" DEST_MSR_USER
[ -z "$DEST_MSR_PASSWORD" ] && read -s -p "Enter the MSR token or password and press [ENTER]:" DEST_MSR_PASSWORD

echo ""
[ -z "$REPOS_WITH_TAGS" ] && read -p "Repositories with tags file(repo_tags.txt):" REPOS_WITH_TAGS
[ -z "$REPOS_WITH_TAGS" ] && REPOS_WITH_TAGS="repo_tags.txt"

if ! test "$REPOS_WITH_TAGS"; then
  echo "$REPOS_WITH_TAGS not exist"
  echo "Please pass REPOS_WITH_TAGS file here"
fi

## Size in GB -> ~10G Default
# MAX_AVAIL=16061861888
MIN_AVAIL=10240

touch tags.SUCCESS
touch tags.PROCESSING
touch tags.FAILED

# Login
function msr_login() {
    MSR_URL=$1
    MSR_USER=$2
    MSR_PASSWORD=$3
    echo -e "${CYAN}Logging into $MSR_URL as $MSR_USER${NC}"
    if ! docker login $MSR_URL -u $MSR_USER -p $MSR_PASSWORD > /dev/null 2>&1; then
        echo -e "${RED}Error: Unable to login to $MSR_URL${NC}"
        exit 1
    fi
}

# Check disk size
function checkDiskSize() {
    avail=$(getDiskSize)
    echo "Disk size: $avail"
    if (($avail < $MIN_AVAIL)); then
        echo "Removing images.."
        removeImages
        #avail=10241
        #if (($avail < $MAX_AVAIL)); then
        #    echo ""
        #fi
    fi
}
function getDiskSize() {
    avail=$(df -m /var/lib/docker |tail -1 |awk '{print $4}')
    echo $avail
}

function removeImages() {

    for _file in tags.SUCCESS tags.FAILED; do
        if [ -s "$_file" ]
        then
                src_images_to_remove=$(cat $_file | sed "s/^/${SOURCE_MSR}\//" | tr '\n' ' ')
                dest_images_to_remove=$(cat $_file | sed "s/^/${DEST_MSR}\//" | tr '\n' ' ')
                
                docker image rmi -f $src_images_to_remove $dest_images_to_remove
                sleep 5s
        else
            continue
        fi
    done
}

msr_login $SOURCE_MSR $SOURCE_MSR_USER $SOURCE_MSR_PASSWORD
msr_login $DEST_MSR $DEST_MSR_USER $DEST_MSR_PASSWORD

while IFS= read -r image_tmp; do
    image=$(echo $image_tmp | awk -F, '{print $1"/"$2":"$3}' | sed 's/"//g')
    
    echo "Checking disk size..."
    checkDiskSize

    if grep -q ${image} tags.PROCESSING tags.SUCCESS; then
        echo "Skipped $image"
        continue
    else
        echo -e "Processing image: $image"

        if ! grep -q ${image} tags.PROCESSING; then
            echo "$image" >> tags.PROCESSING
        fi
        
        
        docker pull -q ${SOURCE_MSR}/${image}
	
        docker image tag ${SOURCE_MSR}/${image} ${DEST_MSR}/${image}
        docker push ${DEST_MSR}/${image}

        if [ $? -eq 0 ]; then
            echo "Completed processing image: $image"
            echo "$image" >> tags.SUCCESS
        else
            echo "Failed processing image: $image"
            echo "$image" >> tags.FAILED
        fi
	sleep 3s
        ## Remove line from processing
	#set -x
        #sed -i '.bak' "s~$image~~g" tags.PROCESSING
        #sed -i '.bak' '/^$/d' tags.PROCESSING
        sed -i "s~$image~~g" tags.PROCESSING
        sed -i '/^$/d' tags.PROCESSING
	#set +x
    fi
done < $REPOS_WITH_TAGS
