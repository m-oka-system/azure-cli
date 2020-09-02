#!/usr/bin/env bash
set -e

# 共通
rgName="azcli-rg"
locations=("japaneast" "japanwest")

# AppService
appServicePlans=("e-azcli-pln" "w-azcli-pln")
webAppNames=("e-azcli-app${RANDOM}" "w-azcli-app${RANDOM}")

# DNSゾーン
dnsName=""
recordSetName="www"
fqdn=${recordSetName}.${dnsName}

# TrafficManger
tmName="azcli-tm${RANDOM}"

# KeyVault
vaultName="e-azcli-vault"
selfCertName="selfcert"

# SQLServer
sqlServerNames=("e-azcli-sql${RANDOM}" "w-azcli-sql${RANDOM}")
sqlLogin="sqladmin"
sqlPassword="My5up3rStr0ngPaSw0rd!"
firewallRuleName="AllowAllWindowsAzureIps"
startIP="0.0.0.0"
endIP="0.0.0.0"
failoverGroupName="azcli-fog${RANDOM}"

# SQLデータベース
databaseName="MyDatabase"
sqlEdition="Basic"
sqlSize="2GB"

# Git設定情報
todoAppURL="https://github.com/Azure-Samples/dotnet-sqldb-tutorial.git"
todoAppDir="dotnet-sqldb-tutorial"
gitUserName=""
gitUserEmail=""
beforeCode='@Html.ActionLink("My TodoList App", "Index", "Home", new { area = "" }, new { @class = "navbar-brand" })'
afterCode='@Html.ActionLink((string)Environment.GetEnvironmentVariable("WEBSITE_SITE_NAME"), "Index", new { controller = "Todos" }, new { @class = "navbar-brand" })'

# 変数入力済みチェック
if [ -z "$dnsName" ] || [ -z "$gitUserName" ] || [ -z "$gitUserEmail" ]; then
  echo "未定義の変数があります。変数：dnsName、gitUserName、gitUserEmailの値を定義してください。"
  exit 1
fi

# リソースグループを作成
az group create --name $rgName --location ${locations[0]}

# AppServiceプランをFreeプランで作成
declare -a appServicePlanIds=()
for ((i=0; i < ${#appServicePlans[*]}; i++)); do
  appServicePlanId=`az appservice plan create --resource-group $rgName --location ${locations[$i]} --name ${appServicePlans[$i]} --sku FREE --query id --output tsv`
  appServicePlanIds+=($appServicePlanId)
done

# WebAppsを作成
declare -a webAppIds=()
for ((i=0; i < ${#webAppNames[*]}; i++)); do
  webAppId=`az webapp create --resource-group $rgName --name ${webAppNames[$i]} --plan ${appServicePlans[$i]} --query id --output tsv`
  webAppIds+=($webAppId)
done

# Traffic Managerプロファイルを作成 (優先度ルーティング)
tmDnsName=`az network traffic-manager profile create --resource-group $rgName \
  --name $tmName \
  --routing-method Priority \
  --unique-dns-name $tmName \
  --protocol HTTP \
  --port 80 \
  --ttl 0 \
  --query TrafficManagerProfile.dnsConfig.fqdn \
  --output tsv`

# Traffic ManagerのエンドポイントにWebAppsを追加
for ((i=0; i < ${#webAppIds[*]}; i++)); do
  az network traffic-manager endpoint create \
    --name ${webAppNames[$i]}"-endpoint" \
    --profile-name $tmName \
    --resource-group $rgName \
    --type azureEndpoints \
    --priority $((i + 1)) \
    --target-resource-id ${webAppIds[$i]}
done

# DNSゾーンを作成
az network dns zone create --resource-group $rgName --name $dnsName

# CNAMEレコードを作成
az network dns record-set cname set-record --resource-group $rgName \
  --zone-name $dnsName \
  --record-set-name $recordSetName \
  --cname $tmDnsName

echo "外部のドメイン登録サービスのネームサーバをAzureDNSに変更してください。"
read -p "変更が反映したら [Enter] を押してください。"

# AppServiceプランをS1にスケールアップ
for ((i=0; i < ${#appServicePlans[*]}; i++)); do
  az appservice plan update --resource-group $rgName --name ${appServicePlans[$i]} --sku S1
done

# WebAppsにカスタムドメインを割り当て
for ((i=0; i < ${#webAppNames[*]}; i++)); do
  az webapp config hostname add --resource-group $rgName \
      --webapp-name ${webAppNames[$i]} \
      --hostname $fqdn
done

# KeyVaultを作成
KeyVaultId=`az keyvault create --resource-group $rgName --location ${locations[0]} \
  --name $vaultName \
  --enable-soft-delete false \
  --query id \
  --output tsv`

# KeyVaultに自己証明書を作成
sed -e "s/INPUT_YOUR_FQDN/$fqdn/g" selfcert_policy.org.json > selfcert_policy.json
az keyvault certificate create --vault-name $vaultName --name $selfCertName --policy @selfcert_policy.json

# AppServiceサービスプリンシパルにKeyVaultへのアクセスを許可する
# サービスプリンシパルのIDは abfa0a7c-a6b6-4736-8310-5855508787cd 固定
az keyvault set-policy --name $vaultName \
  --spn abfa0a7c-a6b6-4736-8310-5855508787cd \
  --secret-permissions get \
  --certificate-permissions get

# WebAppsから証明書へのアクセスを許可
for ((i=0; i < ${#webAppNames[*]}; i++)); do
  az webapp config appsettings set --resource-group $rgName \
    --name ${webAppNames[$i]} \
    --settings WEBSITE_LOAD_CERTIFICATES=*
done

# WebAppsに自己証明書をインポート
declare -a thumbprints=()
for ((i=0; i < ${#webAppNames[*]}; i++)); do
  thumbprint=`az resource create --resource-group $rgName \
    --name ${selfCertName}-${i} \
    --resource-type Microsoft.web/certificates \
    --is-full-object --properties "{ \"location\": \"${locations[$i]}\", \"properties\": { \"serverFarmId\": \"${appServicePlanIds[$i]}\", \"keyVaultId\":\"$KeyVaultId\", \"keyVaultSecretName\": \"$selfCertName\" } }" \
    --query properties.thumbprint \
    --output tsv`
    thumbprints+=($thumbprint)
done

# TLS/SSLバインディングの追加
for ((i=0; i < ${#thumbprints[*]}; i++)); do
  az webapp config ssl bind --resource-group $rgName \
    --name ${webAppNames[$i]} \
    --certificate-thumbprint ${thumbprints[$i]} \
    --ssl-type SNI
done

# SQLServerを作成してファイアウォール規則でAzureサービスからのアクセスを許可
for ((i=0; i < ${#sqlServerNames[*]}; i++)); do
  az sql server create --resource-group $rgName --location ${locations[$i]} --name ${sqlServerNames[$i]}  --admin-user $sqlLogin --admin-password $sqlPassword
  az sql server firewall-rule create --resource-group $rgName --server ${sqlServerNames[$i]} --name $firewallRuleName --start-ip-address $startIP --end-ip-address $endIP
done

# SQLデータベースを作成
az sql db create --resource-group $rgName \
  --name $databaseName \
  --server ${sqlServerNames[0]} \
  --service-objective $sqlEdition \
  --max-size $sqlSize \
  --collation "JAPANESE_CI_AS"

# フェールオーバーグループを作成
az sql failover-group create --resource-group $rgName \
  --name $failoverGroupName \
  --server ${sqlServerNames[0]} \
  --partner-server ${sqlServerNames[1]} \
  --failover-policy Automatic \
  --grace-period 1 \
  --add-db $databaseName

# ローカルGitの有効化
az webapp deployment source config-local-git --resource-group $rgName --name $webAppName

# WebAppsにSQLデータベースの接続文字列を登録
connectionString=`az sql db show-connection-string --client ado.net --server ${sqlServerNames[0]} --name $databaseName | sed -e "s/<username>/$sqlLogin/" -e "s/<password>/$sqlPassword/"`
for ((i=0; i < ${#webAppNames[*]}; i++)); do
  az webapp config connection-string set --resource-group $rgName --name ${webAppNames[$i]} --settings MyDbConnection="$connectionString" --connection-string-type SQLAzure
done

# ローカルGitの設定
git config --global user.name $gitUserName
git config --global user.email $gitUserEmail

# GitHubからToDoアプリをダウンロード
git clone $todoAppURL
cd $todoAppDir

# ソースを修正してコミット
sed -i -e "s/$beforeCode/$afterCode/" ./DotNetAppSqlDb/Views/Shared/_Layout.cshtml
git add .
git commit -m "Update Layout.cshtml"


# ToDoアプリをWeb Appsにデプロイ
for ((i=0; i < ${#webAppNames[*]}; i++)); do
  webAppCred=`az webapp deployment list-publishing-credentials --resource-group $rgName --name ${webAppNames[$i]} --query scmUri --output tsv`
  git remote add ${webAppNames[$i]} $webAppCred
  git push ${webAppNames[$i]} master
done
