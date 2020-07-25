#!/bin/bash

set -e

# Variables
rgName="paas-rg"
location="japaneast"
vaultName="e-paas-vault"
selfCertName="selfcert"
fqdn="www.example.com"

# Create a self-signed certificate.
sed -e "s/INPUT_YOUR_FQDN/$fqdn/g" selfcert_policy.org.json > selfcert_policy.json
az keyvault certificate create --vault-name $vaultName --name $selfCertName --policy @selfcert_policy.json
