provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-rag-chatbot"
  location = "France Central"
}

# 1. Container Registry pour stocker vos images
resource "azurerm_container_registry" "acr" {
  name                = "acrragchatbot${random_id.id.hex}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true
}

# 2. Environnement Container Apps
resource "azurerm_container_app_environment" "env" {
  name                = "cae-rag-chatbot"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

# 3. App Ollama (Backend)
resource "azurerm_container_app" "ollama" {
  name                         = "ca-ollama"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    container {
      name   = "ollama"
      image  = "${azurerm_container_registry.acr.login_server}/ollama-custom:latest"
      cpu    = 2.0 # Attention: CPU est lent pour LLM, voir note GPU plus bas
      memory = "4Gi"
    }
  }
  ingress {
    external_enabled = false # Interne uniquement
    target_port      = 11434
    transport        = "tcp"
  }
}

# 4. App Streamlit (Frontend)
resource "azurerm_container_app" "streamlit" {
  name                         = "ca-streamlit"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    container {
      name   = "streamlit"
      image  = "${azurerm_container_registry.acr.login_server}/streamlit-app:latest"
      cpu    = 0.5
      memory = "1Gi"
      
      # VOS VARIABLES D'ENVIRONNEMENT ICI
      env {
        name  = "OLLAMA_HOST"
        value = "http://${azurerm_container_app.ollama.name}" # DNS interne
      }
      env {
        name  = "API_KEY"
        secret_name = "my-api-key" # Référence à un secret
      }
    }
  }
  ingress {
    external_enabled = true
    target_port      = 8501
    traffic_weight {
      percentage = 100
      latest_revision = true
    }
  }
  
  # Configuration des secrets
  secret {
    name  = "my-api-key"
    value = var.api_key_value
  }
}