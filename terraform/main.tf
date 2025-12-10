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
resource "azurerm_container_app" "frontend" {
  name  = "ca-frontend"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name  = azurerm_resource_group.rg.name
  revision_mode = "Single"

  template {
    container {
      name = "streamlit"
      image = "${azurerm_container_registry.acr.login_server}/rag-frontend:${var.image_tag}"
      cpu = 0.5
      memory = "1Gi"

      env {
        name = "LLM_BASE_URL"
        # On injecte l'adresse interne du backend
        value = "http://${azurerm_container_app.backend.name}" 
      }
    }
  }

  ingress {
    external_enabled = true # OUI accessible depuis internet
    target_port = 8501
    traffic_weight {
      percentage = 100
      latest_revision = true
    }
  }
  
  registry {
    server = azurerm_container_registry.acr.login_server
    username = azurerm_container_registry.acr.admin_username
    password_secret_name = "acr-password"
  }
  secret {
    name  = "acr-password"
    value = azurerm_container_registry.acr.admin_password
  }
}



output "app_url" {
  value = azurerm_container_app.frontend.latest_revision_fqdn
}