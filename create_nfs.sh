#!/bin/bash

resource_group=$1
vnetname=$2

rsaPublicKey=$(cat ~/.ssh/id_rsa.pub)

parameters=$(cat << EOF
{
    "vnetName": {
        "value": "$vnetname"
    },
    "rsaPublicKey": {
        "value": "$rsaPublicKey"
    }
}
EOF
)


az group deployment create \
    --resource-group "$resource_group" \
    --template-file nfs.json \
    --parameters "$parameters"

