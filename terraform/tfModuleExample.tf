data "azurerm_subscription" "current" {}

data "azurerm_client_config" "current" {}

resource "random_integer" "example" {
  min = 10
  max = 99
}

# create project specific rg

resource "azurerm_resource_group" "example" {
  name     = "rg-${var.app_name}-${random_integer.example.result}"
  location = "eastus2"
}

# get data for AKS.


data "azurerm_kubernetes_cluster" "example" {
  name                = "sh02-eus2-01"
  resource_group_name = "prod-clu-grp01"
}


# install kV

resource "azurerm_key_vault" "example" {
  name                        = "akv-${var.app_name}-${random_integer.example.result}"
  location                    = azurerm_resource_group.example.location
  resource_group_name         = azurerm_resource_group.example.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  enable_rbac_authorization   = true
}
resource "azurerm_role_assignment" "example_akv_rbac" {
  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Key Vault Administrator"
  scope                = azurerm_key_vault.example.id
}

# adding this so they can delete the secret
resource "azurerm_role_assignment" "example_akv_rbac_for_del" {
  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Key Vault Secrets Officer"
  scope                = azurerm_key_vault.example.id
}

# create Managed ID 

resource "azurerm_user_assigned_identity" "example" {
  location            = azurerm_resource_group.example.location
  name                = "mid-${var.app_name}-${random_integer.example.result}"
  resource_group_name = azurerm_resource_group.example.name
}

# create federated ID
resource "azurerm_federated_identity_credential" "example" {
  name                = "fid-${var.app_name}-${random_integer.example.result}"
  resource_group_name = azurerm_resource_group.example.name
  parent_id           = azurerm_user_assigned_identity.example.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = data.azurerm_kubernetes_cluster.example.oidc_issuer_url
  subject             = "system:serviceaccount:${var.app_name}:${var.app_name}"
}

# set permissions for user assigned identity to access key vault

resource "azurerm_role_assignment" "acrreadformid" {
  principal_id         = azurerm_user_assigned_identity.example.principal_id
  role_definition_name = "Key Vault Reader"
  scope                = azurerm_key_vault.example.id
}

# Example command for key vault with RBAC enabled using `key` type
## note, this is different to the cli!

resource "azurerm_role_assignment" "example" {
  principal_id         = azurerm_user_assigned_identity.example.principal_id
  role_definition_name = "Key Vault Certificate User"
  scope                = azurerm_key_vault.example.id
}


# sql server
resource "azurerm_cosmosdb_account" "example" {
  name                  = "mongo-${var.app_name}-${random_integer.example.result}"
  location              = azurerm_resource_group.example.location
  resource_group_name   = azurerm_resource_group.example.name
  default_identity_type = join("=", ["UserAssignedIdentity", azurerm_user_assigned_identity.example.id])
  offer_type            = "Standard"
  kind                  = "MongoDB"

  capabilities {
    name = "EnableMongo"
  }

  consistency_policy {
    consistency_level = "Strong"
  }

  geo_location {
    location          = "westus"
    failover_priority = 0
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.example.id]
  }
}

# add secrets to KV 


resource "azurerm_role_assignment" "example_akv_4automation" {
  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Key Vault Secrets Officer"
  scope                = azurerm_key_vault.example.id
}

resource "azurerm_key_vault_secret" "example" {
  name         = "db-connection-string"
  value        = azurerm_cosmosdb_account.example.primary_mongodb_connection_string
  key_vault_id = azurerm_key_vault.example.id
}


## ACR and permissions
resource "azurerm_container_registry" "example" {
  name                = "acr${var.app_name}${random_integer.example.result}"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  sku                 = "Premium"
  admin_enabled       = false
  georeplications {
    location                = "West US2"
    zone_redundancy_enabled = true
    tags                    = {}
  }
}

resource "azurerm_role_assignment" "aksacr" {
  principal_id                     = data.azurerm_kubernetes_cluster.example.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.example.id
  skip_service_principal_aad_check = true
}



## gitops config for NS

resource "azurerm_kubernetes_flux_configuration" "example" {
  name       = "${var.app_name}-${random_integer.example.result}"
  cluster_id = data.azurerm_kubernetes_cluster.example.id
  namespace  = var.app_name

  git_repository {
    url             = var.app_repo_url
    reference_type  = "branch"
    reference_value = "main"

  }

  kustomizations {
    name = "kustomization-1"
    path = "./apps/app1"
  }

}

## add policy assignment for locking resources on rg

resource "azurerm_resource_group_policy_assignment" "example" {
  name                 = "azpol-allowed-res-${var.app_name}-${random_integer.example.result}"
  resource_group_id    = azurerm_resource_group.example.id
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