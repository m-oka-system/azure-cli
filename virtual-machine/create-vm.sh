#!/bin/bash

set -e

# Variables
rgName="w-iaas-rg"
location="japanwest"
subnetName="web-subnet"
vnetName="w-iaas-vnet"
vmName="w-iaas-vm"
vmSize="Standard_A1_v2"
imageName="Win2016Datacenter"
diskName="${vmName}-os-disk"
diskType="Standard_LRS"
diskSize=127
pipName="${vmName}-pip"
nicName="${vmName}-nic"
privateIp="10.0.1.11"
adminUser="cloudadmin"
adminPassword="input your password"

# Create a public IP address.
az network public-ip create --resource-group $rgName --location $location \
  --name $pipName \
  --sku Basic \
  --allocation-method Static

# Create a network interface.
az network nic create --resource-group $rgName --location $location \
  --name $nicName \
  --vnet-name $vnetName \
  --subnet $subnetName \
  --private-ip-address $privateIp \
  --public-ip-address $pipName

# Create an Azure Virtual Machine.
az vm create --resource-group $rgName --location $location \
  --name $vmName \
  --image $imageName \
  --size $vmSize \
  --priority Spot \
  --admin-username $adminUser \
  --admin-password $adminPassword \
  --os-disk-name $diskName \
  --os-disk-size-gb $diskSize \
  --storage-sku $diskType \
  --nics $nicName

