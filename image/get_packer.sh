#!/bin/bash
packer_version=1.3.2

packerzip=https://releases.hashicorp.com/packer/$packer_version/packer_${packer_version}_linux_amd64.zip
wget $packerzip -O packer.zip
unzip packer.zip 
