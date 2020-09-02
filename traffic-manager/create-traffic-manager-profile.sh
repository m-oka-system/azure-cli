#!/usr/bin/env bash
set -e

rgName="azcli-rg"
location="japaneast"
tmName="paas-tm${RANDOM}"

# リソースグループを作成
az group create --name $rgName --location $location

# Traffic Managerプロファイルを作成 (優先度ルーティング)
az network traffic-manager profile create --resource-group $rgName \
  --name $tmName \
  --routing-method Priority \
  --unique-dns-name $tmName \
  --protocol HTTP \
  --port 80 \
  --ttl 0

