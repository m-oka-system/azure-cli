#!/bin/bash

set -e

# Variables
rgName="paas-rg"
location="japaneast"
vaultName="e-paas-vault"

# Recover a key vault.
az keyvault recover --resource-group $rgName --location $location --name $vaultName
