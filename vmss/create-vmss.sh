#!/bin/bash

set -e

# Variables
rgName="w-iaas-rg"
location="japanwest"
vmssName="w-iaas-vmss"
imageName="w-iaas-win2016-ja-with-azmodule-20200308144738"
imageId=$(az image show --resource-group $rgName --name $imageName --query id --output tsv)
sku="Standard_A1_v2"
adminUser="cloudadmin"
adminPassword="My5up3rStr0ngPaSw0rd!"
diskType="Standard_LRS"
vnetName="w-iaas-vnet"
subnetName="web-subnet"
lbName=${vmssName}-lb
lbPublicIpAddressName=${lbName}-ip
lbBackendPoolName=${lbName}-bepool
lbSku="Basic"
lbNatPoolName=${lbName}-natpool
backendPort=3389
probeName=${lbName}-probe
instanceCount=1

# Create vmss with Load Balancer
az vmss create --resource-group $rgName --location $location \
  --name $vmssName \
  --image $imageName \
  --vm-sku $sku \
  --priority Spot \
  --admin-username $adminUser \
  --admin-password $adminPassword \
  --storage-sku $diskType \
  --vnet-name $vnetName \
  --subnet $subnetName \
  --lb $lbName \
  --public-ip-address $lbPublicIpAddressName \
  --backend-pool-name $lbBackendPoolName \
  --lb-sku $lbSku \
  --lb-nat-pool-name $lbNatPoolName \
  --backend-port $backendPort \
  --instance-count $instanceCount \
  --scale-in-policy Default \
  --upgrade-policy-mode Manual \
  --single-placement-group true

# Create a probe
az network lb probe create \
  --resource-group $rgName \
  --name $probeName \
  --lb-name $lbName \
  --protocol Tcp \
  --port 80 \
  --interval 5

# Create a load balancing rule
az network lb rule create \
  --resource-group $rgName \
  --name ${lbName}-rule \
  --lb-name $lbName \
  --frontend-ip-name loadBalancerFrontEnd \
  --protocol tcp \
  --frontend-port 80 \
  --backend-port 80 \
  --backend-pool-name $lbBackendPoolName \
  --probe-name $probeName
