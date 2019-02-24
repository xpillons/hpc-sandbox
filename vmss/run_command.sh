#!/bin/bash
function usage(){
    me=`basename $0`
    echo ""
    echo "Usage:"
    echo "$me -n: vmss name"
    echo "    -g: resource group"
    echo "    -s: script to run"
    echo "    -h: help"
    echo ""
}

while getopts "n: g: s: h" OPTION
do
    case ${OPTION} in
        n)
        vmss_name=$OPTARG
            ;;
        g)
        resource_group=$OPTARG
            ;;
        s)
        script=$OPTARG
            ;;
        h)
        usage
        exit 0
            ;;
    esac
done

shift $(( OPTIND - 1 ));

echo "vmss_name=$vmss_name"
echo "resource_group=$resource_group"
echo "script=$script"

hosts=$(az vmss list-instance-public-ips --name $vmss_name --resource-group $resource_group --query "[].ipAddress" --output tsv)
echo $hosts > hostlist
export WCOLL=hostlist

for h in $hosts; do
    echo $h
    scp $script $h:/tmp/$script
done

pdsh "sudo bash /tmp/$script"


