#!/bin/bash
set -e
set -o pipefail

# temporarily stop yum service conflicts if applicable
set +e
systemctl stop yum.cron
systemctl stop packagekit
set -e

# wait for wala to finish downloading driver updates
sleep 60

# temporarily stop waagent
systemctl stop waagent.service

# cleanup any aborted yum transactions
yum-complete-transaction --cleanup-only

# set limits for HPC apps
cat << EOF >> /etc/security/limits.conf
*               hard    memlock         unlimited
*               soft    memlock         unlimited
*               hard    nofile          65535
*               soft    nofile          65535
EOF

# install based packages
yum install -y epel-release
if [ $? != 0 ]; then
    echo "ERROR: unable to install epel-release"
    exit 1
fi
yum install -y nfs-utils jq htop 
if [ $? != 0 ]; then
    echo "ERROR: unable to install nfs-utils jq htop"
    exit 1
fi

# Disable tty requirement for sudo
sed -i 's/^Defaults[ ]*requiretty/# Defaults requiretty/g' /etc/sudoers

setenforce 0
# Disable SELinux
cat << EOF > /etc/selinux/config
# This file controls the state of SELinux on the system.
# SELINUX= can take one of these three values:
#       enforcing - SELinux security policy is enforced.
#       permissive - SELinux prints warnings instead of enforcing.
#       disabled - No SELinux policy is loaded.
SELINUX=disabled
# SELINUXTYPE= can take one of these two values:
#       targeted - Targeted processes are protected,
#       mls - Multi Level Security protection.
SELINUXTYPE=targeted
EOF

# optimize
systemctl disable cpupower
systemctl disable firewalld

install_mlx_ofed_centos76()
{
    echo "*********************************************************"
    echo "*                                                       *"
    echo "*           Installing Mellanox OFED drivers            *" 
    echo "*                                                       *"
    echo "*********************************************************"

    KERNEL=$(uname -r)
    echo $KERNEL
    yum install -y kernel-devel-${KERNEL} python-devel

    yum install -y redhat-rpm-config rpm-build gcc-gfortran gcc-c++
    yum install -y gtk2 atk cairo tcl tk createrepo
    
    wget --retry-connrefused \
        --tries=3 \
        --waitretry=5 \
        http://content.mellanox.com/ofed/MLNX_OFED-4.5-1.0.1.0/MLNX_OFED_LINUX-4.5-1.0.1.0-rhel7.6-x86_64.tgz
        
    tar zxvf MLNX_OFED_LINUX-4.5-1.0.1.0-rhel7.6-x86_64.tgz
    
    ./MLNX_OFED_LINUX-4.5-1.0.1.0-rhel7.6-x86_64/mlnxofedinstall \
        --add-kernel-support \
        --skip-repo

}

upgrade_lis()
{
    cd /mnt/resource
    set +e
    wget --retry-connrefused --read-timeout=10 https://aka.ms/lis
    tar xvzf lis
    pushd LISISO
    ./uninstall.sh
    ./install.sh
    #yum install hyperv-daemons
    popd
    set -e
}

install_lustre()
{
    KERNEL=$(uname -r)
    echo $KERNEL

    yum install -y dkms
    # if rebuilding the rpm
    yum install -y http://download.zfsonlinux.org/epel/zfs-release.el7.noarch.rpm
    yum install -y spl-dkms zfs-dkms
    yum -y install kernel-devel-${KERNEL} rpm-build make libtool libselinux-devel
    rpmbuild --rebuild --without servers https://downloads.whamcloud.com/public/lustre/lustre-2.10.6/el7/client/SRPMS/lustre-client-dkms-2.10.6-1.el7.src.rpm
    # otherwise ...
    yum install -y /root/rpmbuild/RPMS/noarch/lustre-client-dkms-2.10.6-1.el7.centos.noarch.rpm
    yum install -y https://downloads.whamcloud.com/public/lustre/lustre-2.10.6/el7/client/RPMS/x86_64/lustre-client-2.10.6-1.el7.x86_64.rpm
    mkdir /mnt/lustre
}

# update WALA
/usr/sbin/waagent --version
sed -i -e 's/OS.EnableRDMA=y/OS.EnableRDMA=n/g' /etc/waagent.conf
yum update -y WALinuxAgent

# check if running on HB/HC
VMSIZE=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance?api-version=2017-12-01" | jq -r '.compute.vmSize')
VMSIZE=${VMSIZE,,}
echo "vmSize is $VMSIZE"
if [ "$VMSIZE" == "standard_hb60rs" ] || [ "$VMSIZE" == "standard_hc44rs" ]
then
    set +e
    yum install -y numactl
    install_mlx_ofed_centos76

    echo 1 >/proc/sys/vm/zone_reclaim_mode
    echo "vm.zone_reclaim_mode = 1" >> /etc/sysctl.conf
    sysctl -p
    
    set -e
fi

ifconfig
install_lustre

upgrade_lis
echo "End of base image "
