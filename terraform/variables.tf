variable "location" {
  default = "polandcentral"
}

variable "project_name" {
  default = "rag-chatbot"
}

# Ces variables sont sensés etre remplies par GitHub Actions si on l'utilise
variable "image_tag" { # le tag de l'image docker qui peut etre un hash de commit
  type = string
}

variable "acr_name" { # c'est le nom du registre qui doit etre unique
  type = string
}

#  ["polandcentral","norwayeast","switzerlandnorth","spaincentral","italynorth"] pour moi voici les regions disponibles