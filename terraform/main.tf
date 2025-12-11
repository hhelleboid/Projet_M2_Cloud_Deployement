resource "azurerm_resource_group" "rg" {
  name = "rg-${var.project_name}"
  location = var.location
}

# 1. L'Environnement Container Apps (Le "Cluster" managé)
resource "azurerm_container_app_environment" "env" {
  name = "env-ca-${var.project_name}"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
}

# 2. Le Container Registry 
resource "azurerm_container_registry" "acr" {
  name  = var.acr_name
  resource_group_name = azurerm_resource_group.rg.name
  location  = azurerm_resource_group.rg.location
  sku  = "Basic"
  admin_enabled = true
}

# 3. App BACKEND (Ollama)
resource "azurerm_container_app" "backend" {
  name = "ca-backend"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name = azurerm_resource_group.rg.name
  revision_mode = "Single"

  template {
    container {
      name = "ollama"
      image = "${azurerm_container_registry.acr.login_server}/rag-backend:${var.image_tag}"
      cpu = 2.0  # Ollama a besoin de ressources
      memory = "4Gi"
    }
  }

  ingress {
    external_enabled = false # NON accessible depuis internet
    target_port = 11434
    transport = "http"
    traffic_weight {
      percentage = 100
      latest_revision = true
    }
  }
  
  registry {
    server = azurerm_container_registry.acr.login_server
    username  = azurerm_container_registry.acr.admin_username
    password_secret_name = "acr-password"
  }
  secret {
    name  = "acr-password"
    value = azurerm_container_registry.acr.admin_password
  }
}

# 4. App FRONTEND (Streamlit)

# # 1. CRÉATION DU STOCKAGE (Nouveau)
# resource "azurerm_storage_account" "sa" {
#   name                     = "st${replace(var.project_name, "-", "")}${random_string.suffix.result}" # Doit être unique
#   resource_group_name      = azurerm_resource_group.rg.name
#   location                 = azurerm_resource_group.rg.location
#   account_tier             = "Standard"
#   account_replication_type = "LRS"
# }

# resource "random_string" "suffix" {
#   length  = 4
#   special = false
#   upper   = false
# }

# resource "azurerm_storage_share" "share" {
#   name                 = "rag-data"
#   storage_account_name = azurerm_storage_account.sa.name
#   quota                = 5 # Go
# }

# # 2. LIEN ENTRE L'ENVIRONNEMENT ACA ET LE STOCKAGE (Nouveau)
# resource "azurerm_container_app_environment_storage" "storage_mount" {
#   name                         = "mount-rag-data"
#   container_app_environment_id = azurerm_container_app_environment.env.id
#   account_name                 = azurerm_storage_account.sa.name
#   share_name                   = azurerm_storage_share.share.name
#   access_key                   = azurerm_storage_account.sa.primary_access_key
#   access_mode                  = "ReadWrite"
# }


resource "azurerm_container_app" "frontend" {
  name  = "ca-frontend"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name  = azurerm_resource_group.rg.name
  revision_mode = "Single"

  template {
    container {
      name = "streamlit"
      image = "${azurerm_container_registry.acr.login_server}/rag-frontend:${var.image_tag}"
      cpu = 2.0
      memory = "4Gi"

      env {
        name = "LLM_BASE_URL"
        # On injecte l'adresse interne du backend
        value = "http://${azurerm_container_app.backend.name}" 
      }
    }
  }

  ingress { # defnit comment on accède à lapp
    external_enabled = true # OUI accessible depuis internet
    target_port = 8501
    traffic_weight {
      percentage = 100
      latest_revision = true
    }
  }
  
  registry { # ce bloc utilise les informations du secret pour s'authentifier auprès de l'ACR
    server = azurerm_container_registry.acr.login_server
    username = azurerm_container_registry.acr.admin_username
    password_secret_name = "acr-password"
  }
  secret {
    name  = "acr-password"
    value = azurerm_container_registry.acr.admin_password
  }
}

# # 1. CRÉATION DU STOCKAGE (Nouveau)
# resource "azurerm_storage_account" "sa" {
#   name                     = "st${replace(var.project_name, "-", "")}${random_string.suffix.result}" # Doit être unique
#   resource_group_name      = azurerm_resource_group.rg.name
#   location                 = azurerm_resource_group.rg.location
#   account_tier             = "Standard"
#   account_replication_type = "LRS"
# }

# resource "random_string" "suffix" {
#   length  = 4
#   special = false
#   upper   = false
# }

# resource "azurerm_storage_share" "share" {
#   name                 = "rag-data"
#   storage_account_name = azurerm_storage_account.sa.name
#   quota                = 5 # Go
# }

# # 2. LIEN ENTRE L'ENVIRONNEMENT ACA ET LE STOCKAGE (Nouveau)
# resource "azurerm_container_app_environment_storage" "storage_mount" {
#   name                         = "mount-rag-data"
#   container_app_environment_id = azurerm_container_app_environment.env.id
#   account_name                 = azurerm_storage_account.sa.name
#   share_name                   = azurerm_storage_share.share.name
#   access_key                   = azurerm_storage_account.sa.primary_access_key
#   access_mode                  = "ReadWrite"
# }

# # 3. MODIFICATION DU FRONTEND POUR MONTER LE VOLUME
# resource "azurerm_container_app" "frontend" {
#   name                         = "ca-frontend"
#   container_app_environment_id = azurerm_container_app_environment.env.id
#   resource_group_name          = azurerm_resource_group.rg.name
#   revision_mode                = "Single"

#   template {
#     # IMPORTANT : Limiter à 1 réplique pour éviter la corruption de ChromaDB (SQLite)
#     min_replicas = 1
#     max_replicas = 1

#     container {
#       name   = "streamlit"
#       image  = "${azurerm_container_registry.acr.login_server}/rag-frontend:${var.image_tag}"
#       cpu    = 0.5
#       memory = "1Gi"

#       env {
#         name  = "LLM_BASE_URL"
#         value = "http://${azurerm_container_app.backend.name}" 
#       }

#       # --- AJOUT : Variable pour dire à Python où écrire ---
#       env {
#         name  = "PERSIST_DIRECTORY"
#         value = "/data"
#       }

#       # --- AJOUT : Montage du volume dans le conteneur ---
#       volume_mounts {
#         name = "data-volume"
#         path = "/data"
#       }
#     }

#     # --- AJOUT : Définition du volume lié au stockage Azure ---
#     volume {
#       name         = "data-volume"
#       storage_name = azurerm_container_app_environment_storage.storage_mount.name
#       storage_type = "AzureFile"
#     }
#   }

#   ingress {
#     external_enabled = true
#     target_port      = 8501
#     traffic_weight {
#       percentage      = 100
#       latest_revision = true
#     }
#   }
  
#   registry {
#     server               = azurerm_container_registry.acr.login_server
#     username             = azurerm_container_registry.acr.admin_username
#     password_secret_name = "acr-password"
#   }
#   secret {
#     name  = "acr-password"
#     value = azurerm_container_registry.acr.admin_password
#   }
# }

output "app_url" {
  value = azurerm_container_app.frontend.latest_revision_fqdn
}
output "backend_internal_url" {
  description = "L'URL interne du backend (accessible uniquement dans le réseau Azure)"
  value       = "http://${azurerm_container_app.backend.latest_revision_fqdn}"
}