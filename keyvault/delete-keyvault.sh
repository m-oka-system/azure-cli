#!/bin/bash

set -e

# Variables
rgName="paas-rg"
location="japaneast"
vaultName="e-paas-vault"

# Delete a key vault.
az keyvault delete --resource-group $rgName --name $vaultName

# Permanently deletes the specified secret.
az keyvault purge --location $location --name $vaultName
