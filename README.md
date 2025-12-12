# Projet Cloud M2 - Déploiement d'un Chatbot RAG sur Azure

Ce projet automatise le déploiement d'une architecture micro-services sur Azure pour héberger un Chatbot RAG (Retrieval-Augmented Generation) utilisant **Ollama** (Backend) et **Streamlit** (Frontend).

L'infrastructure est gérée par **Terraform** et les conteneurs sont hébergés sur **Azure Container Apps**.

## 📋 Prérequis

Avant de lancer le déploiement, assurez-vous que les outils suivants sont installés sur votre machine locale :

1. **Azure CLI** : Pour l'authentification et les commandes Azure.
   * [Guide d'installation](https://learn.microsoft.com/fr-fr/cli/azure/install-azure-cli)
2. **Terraform** : Pour l'Infrastructure as Code (IaC).
   * [Guide d'installation](https://developer.hashicorp.com/terraform/downloads)
3. **Docker Desktop** : Pour construire les images localement avant de les pousser.
   * [Guide d'installation](https://www.docker.com/products/docker-desktop/)
4. **Git** : Pour cloner les dépôts.

## ⚙️ Configuration Initiale

### 1. Définir le Token GitHub (Important)

Le script de déploiement doit cloner le code source de l'application (Frontend/Backend) qui se trouve dans un dépôt privé. Vous devez définir un **Personal Access Token (PAT)**.

* Créez un token sur GitHub (Settings -> Developer Settings -> Personal access tokens).
* Ajoutez-le dans votre terminal avant de lancer le script :

```bash
# Sur Git Bash / Linux / Mac
export MY_TOKEN="ghp_votre_token_secret_ici..."

# Sur PowerShell
$env:MY_TOKEN="ghp_votre_token_secret_ici..."
```

### 2. Vérifier la Zone (Région Azure)

Certaines régions peuvent avoir des quotas limités pour les comptes étudiants (Azure for Students).

> [!TIP]
> **Comment vérifier les régions autorisées ?**
> Dans le portail Azure, accédez à : **Policy** → **Assignments** → **Allowed resource deployment regions** → **Parameter value**.

Si vous rencontrez des restrictions, modifiez la variable `location` dans le fichier `terraform/variables.tf` avec une région autorisée (par exemple : `eastus`, `westeurope`).

### 🚀 3. Déploiement

Le déploiement est entièrement automatisé via le script `deploy.sh` sur Git Bash.

**Étapes de déploiement :**

1. Connectez-vous à Azure (avant ou le lancement du scripts de deploiment):

```bash
az login
```

2. Rendez le script exécutable :

```bash
chmod +x deploy.sh
```

3. Lancez le déploiement :

```bash
./deploy.sh
```

**Le script effectue automatiquement :**

- Vérification de la connexion Azure et de l'enregistrement du provider Microsoft.App pour activer la la fonctionnalité Azure Container Apps
- Clonage du code de l'application depuis le dépôt privé
- Construction des images Docker (Frontend & Backend) localement
- Création du registre Azure Container Registry (ACR) via Terraform
- Envoi des images vers l'ACR
- Déploiement de l'infrastructure complète (Container Apps, Environnement, Réseau) via Terraform

### 🌐 4. Accès à l'application

Une fois le déploiement terminé avec succès, Terraform affichera l'URL publique du Frontend dans le terminal.

```bash
Outputs:

app_url = "https://ca-frontend--xxx"
```

### 5. Ajouter les documents (Knowledge Base)

Puisqu'il s'agit d'un RAG, le chatbot a besoin de documents pour répondre aux questions.
Avant de lancer de poser des quesions assurez-vous de téléverser les pdfs au préalable.

### Note sur la CD

L'automatisation complète via **GitHub Actions** n'a pas pu être activée sur ce projet en raison de restrictions de sécurité liées à la création de **Service Principals** (App Registrations) sur l'abonnement Azure utilisé.

Le déploiement actuel repose donc sur une approche semi-automatisée via le script local `deploy.sh` couplé à Terraform.

Cependant, le pipeline CI/CD complet a été conçu et est disponible dans le fichier `.github/workflows/deploy.yml`.

> **Piste d'amélioration :**
> Pour contourner ces restrictions en production, la solution recommandée serait d'utiliser une **Identité Managée (User Assigned Managed Identity)** pour permettre à GitHub Actions de s'authentifier sans secrets statiques.

Pour des raisons non encore identifiés sur les autres navigateurs, autres que Google Chrome il y a des erreurs de chargement de pdfs. 
Nous réglerons ce soucis très bientôt.

Lien de test : https://ca-frontend--q8doieb.whitesky-5070b3e4.polandcentral.azurecontainerapps.io/
