---
layout: default
title: Installation n8n sur Azure en mode Azure Container Application
parent: n8n
grand_parent: Déploiements
nav_order: 3
---

<button class="btn js-toggle-dark-mode">Activer le mode sombre</button>

<script>
const toggleDarkMode = document.querySelector('.js-toggle-dark-mode');

jtd.addEvent(toggleDarkMode, 'click', function(){
  if (jtd.getTheme() === 'dark') {
    jtd.setTheme('light');
    toggleDarkMode.textContent = 'Activer le mode sombre';
  } else {
    jtd.setTheme('dark');
    toggleDarkMode.textContent = 'Activer le mode clair';
  }
});
</script>

# Navigation 
{: .no_toc }

## Table des matières
{: .text-delta }

- [1. Position actuelle, vérifier où vous êtes :](#position)
- [2. Se déplacer dans l'environnement Linux](#deplacement)
- [3. Explorer le contenu d’un dossier avec ls](#liste)
- [4. Astuces pour aller plus vite ](#pushdpopd)

##  Introduction



## Version Azure CLI

# Connexion à Azure
az login

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
storage_account="n8nstrgedulabs"
file_share="n8nstrg"

# 1. Créer le groupe de ressources
az group create -n "$rg" -l "$loc"

# Création de Storage Account

az storage account create \
  --name "$storage_account" \
  --resource-group "$rg" \
  --location "$loc" \
  --sku Standard_GRS \
  --kind StorageV2 \
  --enable-large-file-share true \
  --allow-blob-public-access false \
  --allow-shared-key-access true \
  --https-only true \
  --enable-infrastructure-encryption true \
  --default-action Deny

name : n8nstrgedulabs
redundancy : GRS
Performance : Standard
Tier : Hot
Enable storage account key access
Require secure transfer for REST API operations
Enable large file shares
Disable Public Network
Enable large file shares : Blob and File only
Enable infrastructure encryption : yes

# Récupérer une clé d’accès
storage_key=$(az storage account keys list \
  --resource-group "$rg" \
  --account-name "$storage_account" \
  --query '[0].value' -o tsv)

# Créer le File Share
az storage share-rm create \
  --resource-group "$rg" \
  --storage-account "$storage_account" \
  --name "$file_share"

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

subscription_id=$(az account show --query "id" -o tsv)
kube_env_id="/subscriptions/${subscription_id}/resourceGroups/${rg}/providers/Microsoft.App/managedEnvironments/${env_name}"
cert_id="${kube_env_id}/certificates/${cert_name}"

# Ajouter un fileshare a l'env
az containerapp env storage set \
  --name "$env_name" \
  --resource-group "$rg" \
  --storage-name n8nfileshare \
  --access-mode ReadWrite \
  --azure-file-account-name "$storage_account" \
  --azure-file-account-key "$storage_key" \
  --azure-file-share-name "$file_share"

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
  --env-vars \
      N8N_BASIC_AUTH_ACTIVE=true \
      N8N_BASIC_AUTH_USER=admin \
      N8N_BASIC_AUTH_PASSWORD=MotDePasseSur123! \
      GENERIC_TIMEZONE=Europe/Paris \
      WEBHOOK_URL=https://$domain \
      N8N_USER_FOLDER=/data

# Ajout du volume :
az containerapp update \
  --name "$app_name" \
  --resource-group "$rg" \
  --set \
    properties.configuration.volumeMounts="[{'volumeName':'myfileshare','mountPath':'/data'}]" \
    properties.template.volumes="[{'name':'n8nfileshare','storageType':'AzureFile','storageName':'n8nfileshare'}]"



# Vérification : 
az containerapp show \
  --name "$app_name" \
  --resource-group "$rg" \
  --query "properties.configuration.volumeMounts"

az containerapp show \
  --name "$app_name" \
  --resource-group "$rg" \
  --query "properties.template.volumes"


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


## Version Azure Powershell

```powershell
# Connexion à Azure
Connect-AzAccount

# Déclaration des variables
$rg = "n8n"
$loc = "eastus"
$envName = "n8n-env"
$appName = "n8n-app-1"
$domain = "n8n.edulabs.fr"
$acrName = "edulabsn8n2"

# Créer le groupe de ressources
New-AzResourceGroup -Name $rg -Location $loc

# Créer une Azure Container Registry
New-AzContainerRegistry -ResourceGroupName $rg -Name $acrName -Sku Standard -Location $loc -EnableAdminUser

# Récupérer les infos d'identification ACR
$acrCreds = Get-AzContainerRegistryCredential -Name $acrName -ResourceGroupName $rg
$acrLogin = $acrCreds.Username
$acrPassword = $acrCreds.Password
$loginServer = "$acrName.azurecr.io"

#Login ACR
docker login $loginServer --username $acrLogin --password $acrPassword

# Pull/Tag/Push l’image Docker dans l’ACR
docker pull docker.n8n.io/n8nio/n8n
docker tag docker.n8n.io/n8nio/n8n "$($acrName).azurecr.io/samples/n8n"
docker push "$($acrName).azurecr.io/samples/n8n"

# Créer l’environnement Container App
$workloadProfile = New-AzContainerAppWorkloadProfileObject `
  -Name "Consumption" `
  -Type "Consumption"

# Crée un environnement Azure Container App avec un profil de workload "Consumption"
New-AzContainerAppManagedEnv `
  -Name   $envName `
  -ResourceGroupName $rg `
  -Location $loc `
  -WorkloadProfile $workloadProfile


# Crée un secret nommé "acr-password" contenant le mot de passe ACR (nécessaire pour l'accès privé à l'image)

$secret = New-AzContainerAppSecretObject -Name "acr-password" -Value $acrPassword

# Récupère l'ID de l'environnement Container App pour lier l'application au bon environnement
$env_id = (Get-AzContainerAppManagedEnv -ResourceGroupName $rg -Name $envName).Id

# Déclare les variables d'environnement nécessaires à la configuration de l'application n8n
$envVars = @(
  New-AzContainerAppEnvironmentVarObject -Name "N8N_BASIC_AUTH_ACTIVE" -Value "true"
  New-AzContainerAppEnvironmentVarObject -Name "N8N_BASIC_AUTH_USER" -Value "admin"
  New-AzContainerAppEnvironmentVarObject -Name "N8N_BASIC_AUTH_PASSWORD" -Value "MotDePasseSur123!"
  New-AzContainerAppEnvironmentVarObject -Name "GENERIC_TIMEZONE" -Value "Europe/Paris"
  New-AzContainerAppEnvironmentVarObject -Name "WEBHOOK_URL" -Value "https://$domain"
)

# Définit le template du conteneur à déployer, incluant l'image, les ressources, et les variables d'environnement
$container_n8n = New-AzContainerAppTemplateObject `
  -Name "$appName-container" `
  -Image "$loginServer/samples/n8n:latest" `
  -ResourceCpu 0.5 `
  -ResourceMemory "1.0Gi" `
  -Env $envVars

# Configure l'application : accès externe, port cible, et authentification au registre ACR à l'aide du secret
$config_n8n = New-AzContainerAppConfigurationObject `
  -IngressExternal:$true `
  -IngressTargetPort 5678 `
  -Registry @( @{
      Server = $loginServer
      Username = $acrLogin
      PasswordSecretRef = "acr-password"
  }) `
  -Secret $secret


# Créer la Container App
New-AzContainerApp `
  -Name              $appName `
  -ResourceGroupName $rg `
  -Location          $loc `
  -EnvironmentId     $env_id `
  -TemplateContainer $container_n8n `
  -Configuration     $config_n8n `
  -ScaleMinReplica   1 `
  -ScaleMaxReplica   3


# 💡 Ajouter manuellement dans ta zone DNS :
# - CNAME: n8n.edulabs.fr -> <fqdn>
# - TXT: asuid.n8n.edulabs.fr -> <customDomainVerificationId>

az containerapp hostname add `
  --resource-group $rg `
  --name $appName `
  --hostname $domain


# Récupérer l’URL publique
# Récupérer et parser la configuration
$config_cname = (Get-AzContainerApp -Name $appName -ResourceGroupName $rg).Configuration | ConvertFrom-Json

# Récupérer le FQDN
$fqdn = $config_cname.ingress.fqdn
Write-Output "$fqdn"

# Récupérer le customDomainVerificationId pour DNS TXT
(Get-AzContainerApp -Name $appName -ResourceGroupName $rg).CustomDomainVerificationId

$certName = "n8n-cert"

$managedCert = New-AzContainerAppManagedCert `
  -EnvName             $envName `
  -Name                $certName `
  -ResourceGroupName   $rg `
  -Location            $loc `
  -DomainControlValidation "CNAME" `
  -SubjectName         $domain


az containerapp hostname bind `
  --resource-group $rg `
  --name $appName `
  --hostname $domain `
  --certificate $certName `
  --environment $envName





## Version ARM/Bicep


















---
### Supprimer les instances dans le groupe de ressourde : 
```bash
az resource list --resource-group "$rg" --query "[].id" -o tsv | while IFS= read -r id; do
  az resource delete --ids "$id"
done
```


az containerapp list --resource-group "$rg" --query "[?managedEnvironmentId!='null'].{name:name, env:managedEnvironmentId}" -o table

az containerapp list --resource-group "$rg" --query "[?contains(managedEnvironmentId, 'n8n-env')].name" -o tsv | while IFS= read -r app; do
  az containerapp delete --name "$app" --resource-group "$rg" --yes
done

az containerapp env delete --name n8n-env --resource-group "$rg" --yes

az group delete --name "$rg" --yes --no-wait




## Version Azure CLI V2
