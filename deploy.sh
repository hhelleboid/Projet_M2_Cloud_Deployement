#!/bin/bash

# --- CONFIGURATION ---
REPO_APP_URL="https://$MY_TOKEN@github.com/hhelleboid/Projet_Cloud_M2" # L'URL HTTPS
ACR_NAME="acrragchatbotprojectm2" # Le nom de votre registre (doit être unique)
TF_DIR="./terraform"
APP_DIR="./temp_app_repo"

# Couleurs pour le style
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}### 1. Vérification de la connexion Azure ###${NC}"
# Vérifie si l'utilisateur est connecté, sinon lance le login
if ! az account show 2>/dev/null; then
    echo "Veuillez vous connecter à Azure..."
    az login
else
    echo "Déjà connecté à Azure."
fi



# On récupère l'ID de l'abonnement actif
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# On vérifie qu'on a bien récupéré quelque chose
if [ -z "$SUBSCRIPTION_ID" ]; then
    echo "Erreur : Impossible de récupérer l'ID de souscription."
    exit 1
fi

# echo "Utilisation de la souscription : $SUBSCRIPTION_ID"
echo "Utilisation de la souscription ......"

# On définit la variable d'environnement standard pour Terraform
export ARM_SUBSCRIPTION_ID=$SUBSCRIPTION_ID




echo "Vérification de l'enregistrement du provider Microsoft.App..."
PROVIDER_STATE=$(az provider show -n Microsoft.App --query "registrationState" -o tsv)

if [ "$PROVIDER_STATE" != "Registered" ]; then
    echo "Le provider Microsoft.App n'est pas enregistré. Enregistrement en cours..."
    az provider register --namespace Microsoft.App
    
    # On attend que ce soit fini, cela preut prendre quelques minutes
    while [ "$PROVIDER_STATE" != "Registered" ]; do
        echo "En attente de l'enregistrement..." 
        sleep 10
        PROVIDER_STATE=$(az provider show -n Microsoft.App --query "registrationState" -o tsv)
    done
    echo "Provider Microsoft.App enregistré avec succès !"
else
    echo "Provider Microsoft.App déjà enregistré."
fi



# Récupération d'un tag unique pour les images (Timestamp ou Git Commit)
IMAGE_TAG=$(date +%s)
echo -e "${GREEN} Tag de déploiement : $IMAGE_TAG ${NC}"

echo -e "${GREEN} 2. Récupération du Code Application ${NC}"
# On nettoie l'ancien dossier s'il existe
rm -rf $APP_DIR
# On clone le repo de l'app
git clone $REPO_APP_URL $APP_DIR

echo "Correction des fins de ligne (CRLF -> LF) pour les scripts..."
find $APP_DIR -name "*.sh" -type f -exec sed -i 's/\r$//' {} +


echo -e "${GREEN} 3. Construction et Push des Images Docker ${NC}"

# Vérifier si l'ACR existe, sinon on laisse Terraform le créer plus tard ? 
# Problème : on a besoin de l'ACR pour pousser l'image AVANT le terraform apply final.
# Astuce : On fait un 'az acr login' si l'ACR existe déjà, sinon il faudra lancer terraform une première fois.

# On tente le login ACR (échouera si c'est la toute première fois, c'est normal)
az acr login --name $ACR_NAME 2>/dev/null || echo "ACR non accessible ou inexistant, on continue..."

# BUILD FRONTEND 
echo "Build Frontend..."
docker build -t $ACR_NAME.azurecr.io/rag-frontend:$IMAGE_TAG $APP_DIR/app

# BUILD BACKEND
echo "Build Backend..."
docker build -t $ACR_NAME.azurecr.io/rag-backend:$IMAGE_TAG $APP_DIR/backend_ollama

# Si c'est le tout premier déploiement, l'ACR n'existe pas encore.
# On doit lancer Terraform pour créer l'infra de base (dont l'ACR).
echo -e "${GREEN} 4. Initialisation Infrastructure  avec Terraform ${NC}"
cd $TF_DIR
terraform init

# On applique Terraform. 
# Si l'ACR n'existe pas, Terraform va le créer.
# MAIS les Container Apps vont échouer car l'image n'est pas encore pushée.
# C'est le paradoxe de l'œuf et la poule. 

# SOLUTION ROBUSTE : On sépare la création de l'ACR du reste si nécessaire,
# ou on utilise l'option -target pour créer l'ACR d'abord.

echo "Création du Container Registry en priorité..."
terraform apply -target=azurerm_container_registry.acr -auto-approve -var="image_tag=$IMAGE_TAG" -var="acr_name=$ACR_NAME"

echo "Pause de 15 secondes pour s'assurer que l'ACR est prêt..."
sleep 15

# Maintenant que l'ACR existe sûr, on push les images
echo -e "${GREEN} 5. Push des images vers Azure ${NC}"
az acr login --name $ACR_NAME
docker push $ACR_NAME.azurecr.io/rag-frontend:$IMAGE_TAG
docker push $ACR_NAME.azurecr.io/rag-backend:$IMAGE_TAG

# Maintenant que les images sont là, on déploie TOUTE l'infra (les Container Apps)
echo -e "${GREEN}6. Finalisation du Déploiement (Container Apps) ${NC}"
terraform apply -auto-approve -var="image_tag=$IMAGE_TAG" -var="acr_name=$ACR_NAME"

# Affichage de l'URL
echo -e "${GREEN} DÉPLOIEMENT TERMINÉ AVEC SUCCÈS ${NC}"
terraform output

# chmod +x deploy.sh
# ./deploy.sh


#  installer azure cli et terraform avant