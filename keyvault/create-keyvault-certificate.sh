#!/bin/bash

set -e

# Variables
rgName="paas-rg"
location="japaneast"
vaultName="e-paas-vault"
selfCertName="selfcert"
fqdn="www.example.com"

# Create a key vault.
az keyvault create --resource-group $rgName --location $location \
  --name $vaultName \
  --enable-soft-delete false

# Create a self-signed certificate.
sed -e "s/INPUT_YOUR_FQDN/$fqdn/g" selfcert_policy.org.json > selfcert_policy.json
az keyvault certificate create --vault-name $vaultName --name $selfCertName --policy @selfcert_policy.json

# Allow AppService service principals access to Key Vault
az keyvault set-policy --name $vaultName \
  --spn abfa0a7c-a6b6-4736-8310-5855508787cd \
  --secret-permissions get \
  --certificate-permissions get
