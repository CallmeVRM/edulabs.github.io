#!/bin/bash

# Paramètres
rg="n8n2"
loc="eastus"
env_name="n8n-env-2"
app_name="n8n-app-2"
acr_name="edulabsn8n"
domain="n8n.edulabs.fr"
image_repo="samples/n8n"
image_tag="latest"
cert_name="n8n-cert"

# Connexion à Azure
az login

# 1. Créer le groupe de ressources
az group create -n "$rg" -l "$loc"

# 2. Créer un ACR
az acr create \
  --resource-group "$rg" \
  --name "$acr_name" \
  --sku Standard \
  --location "$loc" \
  --admin-enabled true

# 3. Récupérer les identifiants ACR
acr_username=$(az acr credential show --name "$acr_name" --query "username" -o tsv)
acr_password=$(az acr credential show --name "$acr_name" --query "passwords[0].value" -o tsv)
login_server="${acr_name}.azurecr.io"

# 4. Login Docker au registre
docker login "$login_server" --username "$acr_username" --password "$acr_password"

# 5. Pull, tag et push l’image n8n
docker pull docker.n8n.io/n8nio/n8n
docker tag docker.n8n.io/n8nio/n8n "$login_server/$image_repo:$image_tag"
docker push "$login_server/$image_repo:$image_tag"

# 6. Créer un environnement de Container Apps
az containerapp env create \
  --name "$env_name" \
  --logs-destination none \
  --resource-group "$rg" \
  --location "$loc"

# 7. Déployer l’application n8n
az containerapp create \
  --name "$app_name" \
  --resource-group "$rg" \
  --environment "$env_name" \
  --image "$login_server/$image_repo:$image_tag" \
  --target-port 5678 \
  --ingress external \
  --registry-server "$login_server" \
  --registry-username "$acr_username" \
  --registry-password "$acr_password" \
  --cpu 0.5 \
  --memory 1.0Gi \
  --min-replicas 1 \
  --max-replicas 3 \
  --env-vars N8N_BASIC_AUTH_ACTIVE=true \
             N8N_BASIC_AUTH_USER=admin \
             N8N_BASIC_AUTH_PASSWORD='MotDePasseSur123!' \
             GENERIC_TIMEZONE="Europe/Paris" \
             WEBHOOK_URL="https://$domain"

# 8. Récupérer FQDN de l’app
fqdn=$(az containerapp show \
  --name "$app_name" \
  --resource-group "$rg" \
  --query "properties.configuration.ingress.fqdn" \
  -o tsv)
echo $fqdn

# 9. Récupérer le customDomainVerificationId
verification_id=$(az containerapp show \
  --name "$app_name" \
  --resource-group "$rg" \
  --query "properties.customDomainVerificationId" \
  -o tsv)
echo "Ajoute ce TXT dans ta zone DNS :"
#Ajout un enregistrement TXT dans la zone DNS du sous-domaine asuid.n8n.edulabs.fr
echo "$verification_id"

# 10. Attendre que le DNS TXT soit propagé, puis :
az containerapp hostname add \
  --resource-group "$rg" \
  --name "$app_name" \
  --hostname "$domain"

# 11. Créer un certificat SSL managé
az containerapp env certificate create \
  --resource-group "$rg" \
  --name "$env_name" \
  --hostname "$domain" \
  --validation-method CNAME \
  --certificate-name "$cert_name"

# 12. Lier le certificat SSL au domaine
az containerapp hostname bind \
  --resource-group "$rg" \
  --name "$app_name" \
  --hostname "$domain" \
  --certificate "$cert_name" \
  --environment "$env_name"

echo "✅ Déploiement terminé. Visite : https://$domain"
