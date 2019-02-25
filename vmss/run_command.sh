#!/bin/bash
function usage(){
    me=`basename $0`
    echo ""
    echo "Usage:"
    echo "$me -n: vmss name"
    echo "    -g: resource group"
    echo "    -s: script to run"
    echo "    -i: run thru public or private interface. Values are [private] (default) or [public]"
    echo "    -h: help"
    echo ""
}
interface="private"

while getopts "n: g: s: i: h" OPTION
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
        i)
        interface=$OPTARG
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
echo "interface=$interface"

if [ "$interface" == "public" ]; then
    hosts=$(az vmss list-instance-public-ips --name $vmss_name --resource-group $resource_group --query "[].ipAddress" --output tsv)
else
    hosts=$(az vmss list-instances -n $vmss_name -g $resource_group --query "[].osProfile.computerName" --output tsv)
fi

echo $hosts > hostlist
export WCOLL=hostlist

for h in $hosts; do
    echo $h
    scp $script $h:/tmp/$script
done

pdsh "sudo bash /tmp/$script"


