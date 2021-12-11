$RESOURCE_GROUP = "d-debug"
$LOCATION = "canadacentral"
$CONTAINERAPPS_ENVIRONMENT = "env"
$LOG_ANALYTICS_WORKSPACE = "workspace-logs"
$STORAGE_ACCOUNT = "jehollandebug"
$ACR = "jeffhollan.azurecr.io"
$ACR_Login = "jeffhollan"
$ACR_Password = "$(az acr credential show -n $ACR --query "passwords[0].value" -o tsv)"
$SB_CONNECTIONSTRING = "<connection-string>"

# az extension add --source https://workerappscliextension.blob.core.windows.net/azure-cli-extension/containerapp-0.2.0-py2.py3-none-any.whl
# az provider register --namespace Microsoft.Web

# # az group create --name $RESOURCE_GROUP --location "$LOCATION"

# Creo workspace
az monitor log-analytics workspace create --resource-group $RESOURCE_GROUP --workspace-name $LOG_ANALYTICS_WORKSPACE
$LOG_ANALYTICS_WORKSPACE_CLIENT_ID = (az monitor log-analytics workspace show --query customerId -g $RESOURCE_GROUP -n $LOG_ANALYTICS_WORKSPACE --out tsv)
$LOG_ANALYTICS_WORKSPACE_CLIENT_SECRET = (az monitor log-analytics workspace get-shared-keys --query primarySharedKey -g $RESOURCE_GROUP -n $LOG_ANALYTICS_WORKSPACE --out tsv)

# Creo Environment
az containerapp env create `
  --name $CONTAINERAPPS_ENVIRONMENT `
  --resource-group $RESOURCE_GROUP `
  --logs-workspace-id $LOG_ANALYTICS_WORKSPACE_CLIENT_ID `
  --logs-workspace-key $LOG_ANALYTICS_WORKSPACE_CLIENT_SECRET `
  --location "$LOCATION"

# # Setup dello store dove verranno inserite le configurazioni di dapr
# # az storage account create `
# #   --name $STORAGE_ACCOUNT `
# #   --resource-group $RESOURCE_GROUP `
# #   --location "$LOCATION" `
# #   --sku Standard_RAGRS `
# #   --kind StorageV2
$STORAGE_ACCOUNT_KEY = (az storage account keys list --resource-group $RESOURCE_GROUP --account-name $STORAGE_ACCOUNT --query '[0].value' --out tsv)

# Deploy app:
az containerapp create `
  --name web `
  --resource-group $RESOURCE_GROUP `
  --environment $CONTAINERAPPS_ENVIRONMENT `
  --secrets "accountkey=$STORAGE_ACCOUNT_KEY,connectionstring=$SB_CONNECTIONSTRING" `
  --registry-login-server $ACR `
  --registry-username $ACR_Login `
  --registry-password $ACR_Password `
  --image $ACR/web:latest `
  --target-port 80 `
  --ingress 'external' `
  --min-replicas 1 `
  --max-replicas 1 `
  --enable-dapr `
  --dapr-app-port 80 `
  --dapr-app-id cloudchampion-web `
  --dapr-components ./components.yaml

az containerapp create `
  --name order `
  --resource-group $RESOURCE_GROUP `
  --environment $CONTAINERAPPS_ENVIRONMENT `
  --secrets "accountkey=$STORAGE_ACCOUNT_KEY,connectionstring=$SB_CONNECTIONSTRING" `
  --registry-login-server $ACR `
  --registry-username $ACR_Login `
  --registry-password $ACR_Password `
  --image $ACR/order:test `
  --min-replicas 1 `
  --max-replicas 1 `
  --enable-dapr `
  --dapr-app-port 80 `
  --dapr-app-id cloudchampion-order `
  --dapr-components ./components.yaml