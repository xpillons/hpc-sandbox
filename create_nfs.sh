rsaPublicKey=$(cat ~/.ssh/id_rsa.pub)

parameters=$(cat << EOF
{
    "adminUser": {
        "value": ""
    },
    "vnetName": {
        "value": "$vnetname"
    },
    "rsaPublicKey": {
        "value": "$rsaPublicKey"
    }
}
EOF
)
resource_group=""

az group deployment create \
    --resource-group "$resource_group" \
    --template-file nfs.json \
    --parameters "$parameters"

