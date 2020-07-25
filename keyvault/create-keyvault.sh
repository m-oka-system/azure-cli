#!/bin/bash

set -e

# Variables
rgName="paas-rg"
location="japaneast"
vaultName="e-paas-vault"

# Create a key vault.
az keyvault create --resource-group $rgName --location $location \
  --name $vaultName \
  --enable-soft-delete false
