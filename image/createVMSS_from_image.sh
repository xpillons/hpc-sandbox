#!/bin/bash

config_file="config.json"

function usage(){
    me=`basename $0`
    echo ""
    echo "Usage:"
    echo "$me -c config.json"
    echo "    -c: config file to use"
    echo "    -h: help"
    echo ""
}

# Read value from json file $config_file
# $1 is the variable to fill
# $2 is the json path to the value
function read_value {
    read $1 <<< $(jq -r "$2" $config_file)
    echo "read_value: $1=${!1}"
    if [ $? != 0 ]; then
        echo "ERROR: Failed to read $2 from $config_file"
        exit 1
    fi
}

while getopts "a: c: h" OPTION
do
    case ${OPTION} in
        c)
        config_file=$OPTARG
            ;;
        h)
        usage
        exit 0
            ;;
    esac
done

shift $(( OPTIND - 1 ));

echo "config file: $config_file"

read_value location ".location"
read_value vm_size ".images.vm_size"
read_value images_rg ".images.resource_group"

vmsku=$(echo $vm_size | cut -d '_' -f 2)

image_id=$(az image list -g ${images_rg} --query "[?contains(name,'${vmsku}-')].[id]" -o tsv | sort | tail -n1)
echo $image_id

test_rg=azcat_$(date "+%Y%m%d-%H%M%S")
az group create --name $test_rg --location $location
vmssname=foo

az vmss create \
    -g $test_rg \
    -n $vmssname \
    --image $image_id \
    --instance-count 0 \
    --no-wait \
    --single-placement-group true \
    --vm-sku $vm_size --ssh-key-value @~/.ssh/id_rsa.pub
