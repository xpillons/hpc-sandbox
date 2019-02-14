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

read_value subscription_id ".subscription_id"
read_value location ".location"
read_value sp_client_id ".service_principal.client_id"
read_value sp_client_secret ".service_principal.client_secret"
read_value sp_tenant_id ".service_principal.tenant_id"
read_value images_rg ".images.resource_group"
read_value images_storage ".images.storage_account"
read_value image_name ".images.name"
read_value image_publisher ".images.publisher"
read_value image_offer ".images.offer"
read_value image_sku ".images.sku"
read_value vm_size ".images.vm_size"
read_value packer_exe ".packer.executable"
read_value base_image ".packer.base_image"
read_value private_only ".packer.private_only"
read_value vnet_name ".packer.vnet_name"
read_value subnet_name ".packer.subnet_name"
read_value vnet_resource_group ".packer.vnet_resource_group"
private_only=${private_only,,}

timestamp=$(date +%Y%m%d-%H%M%S)

# create resource group for images (if not already there)
echo "create resource group for images (if not already there)"
exists=$(az group show --name $images_rg --out tsv)
if [ "$exists" == "" ]; then
    echo "Creating resource group for images ($images_rg)"
    az group create --name $images_rg --location $location --output tsv
    if [ $? != 0 ]; then
        echo "ERROR: Failed to create resource group"
        exit 1
    fi
fi

# create storage account for images (if not already there)
echo "create storage account for images (if not already there)"
exists=$( \
    az storage account show \
        --name $images_storage \
        --resource-group $images_rg \
        --output tsv \
)
if [ "$exists" == "" ]; then
    echo "Creating storage account for images ($images_storage)"
    az storage account create \
        --name $images_storage \
        --kind StorageV2 \
        --location $location \
        --resource-group $images_rg \
        --output table
    if [ $? != 0 ]; then
        echo "ERROR: Failed to storage account"
        exit 1
    fi
fi

# update storage type based on VM size
storage_account_type="Premium_LRS"
vm_size=${vm_size,,}
case "$vm_size" in
    *_h16*) 
        storage_account_type="Standard_LRS"
        ;;
    *_f72*)
        storage_account_type="Standard_LRS"
        ;;
esac
echo "storage_account_type=$storage_account_type"

vmsku=$(echo $vm_size | cut -d '_' -f 2)
app_img_name=$vmsku-$timestamp

private=""
if [ "$private_only" == "yes" ]; then
    private="private_"
fi

managed=""
case $storage_account_type in
    "Premium_LRS")
        managed="managed"
        image_name=$app_img_name
        ;;
    "Standard_LRS")
        managed="unmanaged"
        ;;
esac
packer_build_template="build_${private}from_${managed}.json"
echo "packer_build_template=$packer_build_template"

# run packer
PACKER_LOG=1
packer_log=packer-output-$timestamp.log
version=$($packer_exe --version)

echo "running on packer version $version"

if [ "$version" == "1.3.3" ]; then
    echo "version 1.3.3 is not supported and have a bug, use 1.3.2 or 1.3.4+"
    exit 1
fi

$packer_exe build -timestamp-ui \
    -var subscription_id=$subscription_id \
    -var location=$location \
    -var resource_group=$images_rg \
    -var tenant_id=$sp_tenant_id \
    -var client_id=$sp_client_id \
    -var client_secret=$sp_client_secret \
    -var image_name=$image_name \
    -var image_publisher=$image_publisher \
    -var image_offer=$image_offer \
    -var image_sku=$image_sku \
    -var vm_size=$vm_size \
    -var storage_account_type=$storage_account_type \
    -var baseimage=$base_image \
    -var storage_account=$images_storage \
    -var vnet_name=$vnet_name \
    -var subnet_name=$subnet_name \
    -var vnet_resource_group=$vnet_resource_group \
    $packer_build_template \
    | tee $packer_log

if [ $? != 0 ]; then
    echo "ERROR: Bad exit status for packer"
    exit 1
fi

errors=$(grep "ERROR" $packer_log)
echo "Testing errors : $errors"
if [ "$errors" != "" ]; then
    echo "errors while creating the image"
    echo "*******************************"
    echo $errors
    echo "*******************************"

    echo "Deleting image $app_img_name"
    az image delete --name $app_img_name --resource-group $images_rg
    exit 1
fi

if [ "$storage_account_type" == "Standard_LRS" ]; then
    # get vhd source from the packer output
    vhd_source="$(grep -Po '(?<=OSDiskUri\: )[^$]*' $packer_log)"

    echo "Creating image: $app_img_name (using $vhd_source)"
    az image create \
        --name $app_img_name \
        --resource-group $images_rg \
        --source $vhd_source \
        --os-type Linux \
        --location $location \
        --output table

    if [ $? != 0 ]; then
        echo "ERROR: Failed to create image"
        exit 1
    fi
fi

rm $packer_log

