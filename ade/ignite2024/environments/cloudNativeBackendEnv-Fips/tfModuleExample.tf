data "azurerm_subscription" "current" {}

data "azurerm_client_config" "current" {}

resource "random_integer" "example" {
  min = 10
  max = 99
}

# reference created ADE RG
data "azurerm_resource_group" "rg" {
  name = var.resource_group_name

}

# get data for AKS.


data "azurerm_kubernetes_cluster" "example" {
  name                = "AKS CLUSTER NAME" 
  resource_group_name = "RESOURCE GROUP NAME"
}


## set perms to namespace to the ADE user deploying the environment
 resource "azurerm_role_assignment" "example_aks_ns_user_perms" {
   principal_id         = var.ade_userid 
   role_definition_name = "Azure Kubernetes Service RBAC Reader"
   scope                = "${data.azurerm_kubernetes_cluster.example.id}/namespaces/${var.name}"
 }




# create key vault

resource "azurerm_key_vault" "example" {
  name                        = "akv-${var.name}-${random_integer.example.result}"
  location                    = "eastus"
  resource_group_name         = data.azurerm_resource_group.rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  enable_rbac_authorization   = true
  tags                    = {
    teamname = var.teamname

  }
}

# check if this is still needed - we had to provide secrets officer
resource "azurerm_role_assignment" "example_akv_rbac" {
  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Key Vault Administrator"
  scope                = azurerm_key_vault.example.id
}

# adding this so they can delete the secret, making it Admin so TF can delete the secret
resource "azurerm_role_assignment" "example_akv_rbac_for_del" {
  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Key Vault Secrets Officer"
  scope                = azurerm_key_vault.example.id
}

# create Managed ID 

resource "azurerm_user_assigned_identity" "example" {
  location            = "eastus"
  name                = "mid-${var.name}-${random_integer.example.result}"
  resource_group_name = data.azurerm_resource_group.rg.name
    tags                    = {
    teamname = var.teamname

  }
}
  

# Federate the identity so it can be used with the K8s NS + svc account
resource "azurerm_federated_identity_credential" "example" {
  name                = "fid-${var.name}-${random_integer.example.result}"
  resource_group_name = data.azurerm_resource_group.rg.name
  parent_id           = azurerm_user_assigned_identity.example.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = data.azurerm_kubernetes_cluster.example.oidc_issuer_url
  subject             = "system:serviceaccount:${var.name}:${var.name}"
}

# set permissions for user assigned identity to access key vault

resource "azurerm_role_assignment" "acrreadformid" {
  principal_id         = azurerm_user_assigned_identity.example.principal_id
  role_definition_name = "Key Vault Reader"
  scope                = azurerm_key_vault.example.id
}


## get granfana DB

data "azurerm_dashboard_grafana" "example" {
  name                = "GRAF DB NAME" 
  resource_group_name = "RESOURCE GROUP"
}

## return endpoint <HERE ADD URL>
output "grafana-dashboard_url" {
  value = data.azurerm_dashboard_grafana.example.endpoint
}

# note - if you use TF to grant the ade deployer permissions to view it, you can only do this once, otherwise TF will error, I suspect putting users in AAD groups is a better approach
output "aks-cluster-connection-cmd" {
  value = "az aks get-credentials --resource-group ${data.azurerm_kubernetes_cluster.example.resource_group_name} --name ${data.azurerm_kubernetes_cluster.example.name}"
}

output "aks-cluster-namespace" {
  value = "${var.name}"
}


# grant permissions to Log Analytics

# get log analytics db
data "azurerm_log_analytics_workspace" "example" {
  name                = "LA WORKSPACE NAME"
  resource_group_name = "RESOURCE GROUP NAME"
}

output "log-analytis-connection-uri" {
  value = "https://ade.loganalytics.io/subscriptions/e049fcf1-c84b-4de4-ba9a-a168a4cbab7a/resourcegroups/prod-clu-grp01/providers/microsoft.operationalinsights/workspaces/perfclusterlogs"
}

output "log_analytics_url" {
  value = "https://dataexplorer.azure.com"
}

output "argocd_url" {
  value = "https://localhost:8080"
}

# here we just generate a db string, you could extend the TF to reach out to Cosmos to get it
resource "azurerm_key_vault_secret" "example" {
  name         = "db-conn-string"
  value        = "my-mongo-db-connection-string" 
  key_vault_id = azurerm_key_vault.example.id
  depends_on = [ azurerm_role_assignment.example_akv_rbac, azurerm_role_assignment.example_akv_rbac_for_del ]
}


# here we add in restrictions of what can be added to the resource group
resource "azurerm_resource_group_policy_assignment" "example" {
  name                 = "azpol-allowed-res-${var.name}-${random_integer.example.result}"
  resource_group_id    = data.azurerm_resource_group.rg.id
  policy_definition_id = "/providers/microsoft.authorization/policydefinitions/a08ec900-254a-4555-9bf5-e42af04b5c5c"
  enforce              = false
  parameters           = <<PARAMETERS
   {
      "listOfResourceTypesAllowed": {
        "value": [
          "Microsoft.ContainerService/managedClusters",
          "Microsoft.OperationsManagement/solutions",
          "Microsoft.OperationalInsights/workspaces",
          "Microsoft.ManagedIdentity/userAssignedIdentities",
          "Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials",
          "microsoft.insights/dataCollectionRules",
          "microsoft.insights/metricalerts",
          "microsoft.insights/dataCollectionEndpoints",
          "microsoft.insights/actiongroups",
          "Microsoft.AlertsManagement/prometheusRuleGroups",
          "microsoft.documentdb/databaseaccounts",
          "microsoft.containerregistry/registries",
          "microsoft.containerregistry/registries/replications",
          "microsoft.containerregistry/registries/replications",
          "microsoft.keyvault/vaults"
        ]
      }
    }
  PARAMETERS
}

# add outputs for keyvault name and MSI ID, (optional) if the developer needs to debug
output "keyvault_id" {
  value = azurerm_key_vault.example.id
}

output "msi_client_id" {
  value = azurerm_user_assigned_identity.example.client_id
}