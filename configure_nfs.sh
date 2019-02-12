#!/bin/bash
nfsnode=$1

echo "uploading setup script"
# remove old entries for the nfs nodes in case of several retries to avoid ssh failures
ssh-keygen -f "~/.ssh/known_hosts" -R ${nfsnode}
scp -o StrictHostKeyChecking=no setup_nfs.sh hpcadmin@${nfsnode}:setup_nfs.sh
echo "Configuring NFS disk and mount point"
ssh -o StrictHostKeyChecking=no hpcadmin@${nfsnode} "sudo bash setup_nfs.sh"
