#!/usr/bin/env bash
set -e

rgName="azcli-rg"
location1="japaneast"
location2="japanwest"
appServicePlanName1="e-azcli-pln"
appServicePlanName2="w-azcli-pln"
webAppName1="e-azcli-app${RANDOM}"
webAppName2="w-azcli-app${RANDOM}"
tmName="paas-tm${RANDOM}"

# リソースグループを作成
az group create --name $rgName --location $location1

# AppServiceプランをS1プランで東西リージョンに作成
az appservice plan create --resource-group $rgName --location $location1 --name $appServicePlanName1 --sku S1
az appservice plan create --resource-group $rgName --location $location2 --name $appServicePlanName2 --sku S1

# WebAppsを東西リージョンに作成
az webapp create --resource-group $rgName --name $webAppName1 --plan $appServicePlanName1
az webapp create --resource-group $rgName --name $webAppName2 --plan $appServicePlanName2

# WebAppsのIDを取得(TrafficManagerエンドポイントの登録に必要)
webAppId1=`az webapp show --resource-group $rgName --name $webAppName1 --query id --out tsv`
webAppId2=`az webapp show --resource-group $rgName --name $webAppName2 --query id --out tsv`

# Traffic Managerプロファイルを作成 (優先度ルーティング)
az network traffic-manager profile create --resource-group $rgName \
  --name $tmName \
  --routing-method Priority \
  --unique-dns-name $tmName \
  --protocol HTTP \
  --port 80 \
  --ttl 0

# Traffic ManagerのエンドポイントにWebAppsを追加
# プライマリ(優先度1)
az network traffic-manager endpoint create --resource-group $rgName
    --name ${webAppName1}"-endpoint" \
    --profile-name $tmName \
    --type azureEndpoints \
    --priority 1 \
    --target-resource-id ${webAppId1}

# セカンダリ(優先度2)
az network traffic-manager endpoint create --resource-group $rgName
    --name ${webAppName2}"-endpoint" \
    --profile-name $tmName \
    --type azureEndpoints \
    --priority 2 \
    --target-resource-id ${webAppId2}
