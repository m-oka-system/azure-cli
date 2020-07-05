#!/bin/bash

set -e

# Variables
# Common
rgName="paas-rg"
locations=("japaneast" "japanwest")

# AppService
appServicePlans=("e-paas-pln" "w-paas-pln")
webAppNames=("e-paas-app${RANDOM}" "w-paas-app${RANDOM}")
dnsName="www.example.com"
todoAppURL="https://github.com/Azure-Samples/dotnet-sqldb-tutorial.git"
todoAppDir="dotnet-sqldb-tutorial"
beforeCode='@Html.ActionLink("My TodoList App", "Index", "Home", new { area = "" }, new { @class = "navbar-brand" })'
afterCode='@Html.ActionLink((string)Environment.GetEnvironmentVariable("WEBSITE_SITE_NAME"), "Index", new { controller = "Todos" }, new { @class = "navbar-brand" })'

# TrafficManger
tmName="paas-tm"

# SQLServer
sqlServerNames=("e-paas-sql" "w-paas-sql")
sqlLogin="sqladmin"
sqlPassword="My5up3rStr0ngPaSw0rd!"
firewallRuleName="AllowSome"
startIP="0.0.0.0"
endIP="0.0.0.0"
failoverGroupName="paas-fog"

# SQLDatabase
databaseName="MyDatabase"
sqlEdition="Basic"
sqlSize="2GB"

# Create a resource group.
az group create --location ${locations[0]} --name $rgName

# Create an App Service plan in FREE tier.
for ((i=0; i < ${#appServicePlans[*]}; i++)); do
  az appservice plan create --resource-group $rgName --location ${locations[$i]} --name ${appServicePlans[$i]} --sku FREE
done

# Create a web app.
declare -a webAppIds=()
for ((i=0; i < ${#webAppNames[*]}; i++)); do
  webAppId=$(az webapp create --resource-group $rgName --name ${webAppNames[$i]} --plan ${appServicePlans[$i]} --query id --out tsv)
  webAppIds[$i]=$webAppId
done

# Create a Traffic Manager profile.
az network traffic-manager profile create \
  --resource-group $rgName \
  --name $tmName \
  --routing-method Priority \
  --unique-dns-name $tmName \
  --protocol HTTP \
  --port 80 \
  --ttl 0

# Create an endpoint.
for ((i=0; i < ${#webAppIds[*]}; i++)); do
  az network traffic-manager endpoint create \
    --name ${webAppNames[$i]}"-endpoint" \
    --profile-name $tmName \
    --resource-group $rgName \
    --type azureEndpoints \
    --priority $((i + 1)) \
    --target-resource-id ${webAppIds[$i]}
done

# Scale app service plan to S1
for ((i=0; i < ${#appServicePlans[*]}; i++)); do
  az appservice plan update --resource-group $rgName --name ${appServicePlans[$i]} --sku S1
done

# Bind a hostname to a web app.
for ((i=0; i < ${#webAppNames[*]}; i++)); do
  az webapp config hostname add \
      --resource-group $rgName \
      --webapp-name ${webAppNames[$i]} \
      --hostname $dnsName
done

# Create a sql server.
for ((i=0; i < ${#sqlServerNames[*]}; i++)); do
  # Create a sql server
  az sql server create --resource-group $rgName --location ${locations[$i]} --name ${sqlServerNames[$i]}  --admin-user $sqlLogin --admin-password $sqlPassword
  # Create firewall rule to allow connections from Azure services
  az sql server firewall-rule create --resource-group $rgName --server ${sqlServerNames[$i]} --name $firewallRuleName --start-ip-address $startIP --end-ip-address $endIP
done

# Create a sql database
az sql db create --resource-group $rgName \
  --name $databaseName \
  --server ${sqlServerNames[0]} \
  --service-objective $sqlEdition \
  --max-size $sqlSize \
  --collation "JAPANESE_CI_AS"

# Create a failover group
az sql failover-group create --resource-group $rgName --name $failoverGroupName \
  --server ${sqlServerNames[0]} \
  --partner-server ${sqlServerNames[1]} \
  --failover-policy Automatic \
  --grace-period 1 \
  --add-db $databaseName

# Add a sqldatabase connection string.
connectionString=$(az sql db show-connection-string --client ado.net --server ${sqlServerNames[0]} --name $databaseName | sed -e "s/<username>/$sqlLogin/" -e "s/<password>/$sqlPassword/" -e "s/${sqlServerNames[0]}/$failoverGroupName/")
for ((i=0; i < ${#webAppNames[*]}; i++)); do
  az webapp config connection-string set --resource-group $rgName --name ${webAppNames[$i]} --settings MyDbConnection="$connectionString" --connection-string-type SQLAzure
done

# Set the account-level deployment credentials
# az webapp deployment user set --user-name $username --password $password

# Configure local Git and get deployment URL
# url=$(az webapp deployment source config-local-git --name $webappname \
# --resource-group myResourceGroup --query url --output tsv)

# Git config
git config --global user.name "<your username>"
git config --global user.email "<your email>"

# Git clone todo app
git clone $todoAppURL
cd $todoAppDir
sed -i -e "s/$beforeCode/$afterCode/" ./DotNetAppSqlDb/Views/Shared/_Layout.cshtml # Bug fix
git add .
git commit -m "Update Layout.cshtml"

# Add the Azure remote to your local Git respository and push your code
for ((i=0; i < ${#webAppNames[*]}; i++)); do
  # Get app-level deployment credentials
  webAppCred=$(az webapp deployment list-publishing-credentials --resource-group $rgName --name ${webAppNames[$i]} --query scmUri --output tsv)
  # Deploy todo app to web apps
  git remote add ${webAppNames[$i]} $webAppCred
  git push ${webAppNames[$i]} master
done
