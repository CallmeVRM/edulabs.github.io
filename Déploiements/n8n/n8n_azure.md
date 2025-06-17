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
docker tag docker.n8n.io/n8nio/n8n "$login_server/sample:n8n"
docker push "${acr_name}.azurecr.io/sample:n8n"

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
# Resource Group
az group create --name n8n-rg --location eastus

# PostgreSQL Database
az postgres flexible-server create \
  --resource-group n8n-rg \
  --name n8n-postgres \
  --location eastus \
  --admin-user n8nadmin \
  --admin-password <STRONG_PASSWORD> \
  --sku-name Standard_B1ms \
  --public-access 0.0.0.0-255.255.255.255 \
  --version 14

az postgres flexible-server db create \
  --resource-group n8n-rg \
  --server-name n8n-postgres \
  --database-name n8ndb

# Storage Account
az storage account create \
  --name n8nstorage<UNIQUE_SUFFIX> \
  --resource-group n8n-rg \
  --location eastus \
  --sku Standard_LRS

az storage share create \
  --name n8n-data \
  --account-name n8nstorage<UNIQUE_SUFFIX>

STORAGE_KEY=$(az storage account keys list \
  --account-name n8nstorage<UNIQUE_SUFFIX> \
  --resource-group n8n-rg \
  --query "[0].value" -o tsv)

# Container Apps Environment
az containerapp env create \
  --name n8n-env \
  --resource-group n8n-rg \
  --location eastus

az containerapp create \
  --name n8n-app \
  --resource-group n8n-rg \
  --environment n8n-env \
  --image docker.io/n8nio/n8n:latest \
  --target-port 5678 \
  --ingress external \
  --env-vars \
    DB_TYPE=postgresdb \
    DB_POSTGRESDB_HOST=n8n-postgres.postgres.database.azure.com \
    DB_POSTGRESDB_PORT=5432 \
    DB_POSTGRESDB_DATABASE=n8ndb \
    DB_POSTGRESDB_USER=n8nadmin \
    DB_POSTGRESDB_SCHEMA=public \
    DB_POSTGRESDB_PASSWORD=<POSTGRES_PASSWORD> \
  --secrets "storage-key=$STORAGE_KEY" \
  --volumes name=n8n-volume storage-type=AzureFile \
            storage-name=n8n-data \
            storage-account-name=n8nstorage<UNIQUE_SUFFIX> \
  --mounts name=n8n-volume mount-path=/home/node/.n8n

# Create temporary container to fix permissions
az container create \
  --resource-group n8n-rg \
  --name permissions-fixer \
  --image alpine:latest \
  --command-line "chown -R 1000:1000 /mnt/data" \
  --azure-file-volume-account-name n8nstorage<UNIQUE_SUFFIX> \
  --azure-file-volume-account-key $STORAGE_KEY \
  --azure-file-volume-share-name n8n-data \
  --azure-file-volume-mount-path /mnt/data

# Delete temporary container
az container delete --name permissions-fixer --resource-group n8n-rg --yes


Check n8n logs:
az containerapp logs show -n n8n-app -g n8n-rg





# N8N + FileStorage + Certificat + postgreSQL : ChatGPT o4 mini high
### Extension Container Apps :
az extension add --name containerapp

### Variables (à adapter)
# Groupe de ressources et région
rg="n8n-rg"
loc="westus"

# Storage pour le file share
sa="n8nstorageedulabs"
share="n8nshare"

# Postgres flexible server
pg_server="n8n-pg-edulabs"
pg_admin="n8nadmin"
pgpassword="S3cur3P@ssw0rd!"
pg_db_name="n8n"

# Container Apps
env_name="n8n-env"
app_name="n8n-app"

# Domaine à lier
custom_domain="n8n.edulabs.fr"

# ACR 
acr_name="n8nedulabs"

### Création du groupe de ressources
az group create \
  --name $rg \
  --location $loc

### Stockage Azure Files (file share)
# Création du Storage Account + file share
az storage account create \
  --name $sa \
  --resource-group $rg \
  --location $loc \
  --sku Standard_LRS

az storage share create \
  --account-name $sa \
  --name $share

# Récupération de la clé du storage (on la stocke comme secret pour le Container App)
storage_key=$(az storage account keys list \
  --account-name $sa \
  --resource-group $rg \
  --query '[0].value' -o tsv)

### Base de données PostgreSQL
az provider show -n Microsoft.DBforPostgreSQL
az provider show --namespace Microsoft.DBforPostgreSQL --query registrationState

### Attention il faut la changer après, pas de flexible server en east en mode student.
az postgres flexible-server create \
  --resource-group $rg \
  --name $pg_server \
  --location $loc \
  --admin-user $pg_admin \
  --admin-password $pgpassword \
  --sku-name Standard_D2s_v3 \
  --tier GeneralPurpose \
  --storage-size 32

# Fonctionne dans la région westus, avec l'abonnement Student (Instance pas cher)
az postgres flexible-server create \
  --resource-group $rg \
  --name $pg_server \
  --location $loc \
  --admin-user $pg_admin \
  --admin-password $pgpassword \
  --sku-name Standard_B1ms \
  --tier Burstable \
  --storage-size 32


# Autoriser les IP Azure (0.0.0.0) pour que Container Apps puisse se connecter
az postgres flexible-server firewall-rule create \
  --resource-group "$rg" \
  --name "$pg_server" \
  --rule-name AllowAzureIPs \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0

export PGHOST=n8n-pg-edulabs.postgres.database.azure.com
export PGUSER=n8nadmin
export PGPORT=5432
export PGDATABASE=postgres

# Installer postgresql en local (le client)
sudo apt install postgresql-client postgresql-contrib

# Se connecter à loa base de donnée
psql -h n8n-pg-edulabs.postgres.database.azure.com -U n8nadmin -d postgres -p 5432

# Créer la base de donnée :
CREATE DATABASE n8n;

# Quitter 
\q

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
docker tag docker.n8n.io/n8nio/n8n "$login_server/sample:n8n"
docker push "${acr_name}.azurecr.io/sample:n8n"

### Environnement Azure Container Apps
az containerapp env create \
  --name $env_name \
  --resource-group $rg \
  --logs-destination none \
  --location $loc

### Identité managée & rôle Storage
az identity create \
  --resource-group $rg \
  --name n8n-identity

mi_principal_id=$(az identity show \
  --resource-group $rg \
  --name n8n-identity \
  --query 'principalId' -o tsv)
mi_resource_id=$(az identity show \
  --resource-group $rg \
  --name n8n-identity \
  --query 'id' -o tsv)

### Assignez-lui le rôle Storage File Data SMB Share Contributor sur votre storage account :
az role assignment create \
  --assignee-object-id $mi_principal_id \
  --assignee-principal-type ServicePrincipal \
  --role "Storage File Data SMB Share Contributor" \
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$rg/providers/Microsoft.Storage/storageAccounts/$sa"

# Update de l'environnement avec le nouveau volume :
Nom et StorageKey + Read/Write

snenv="n8nstorageedulabs"

az containerapp env storage set \
  --name n8n-env \
  --resource-group $rg \
  --storage-name $snenv \
  --access-mode ReadWrite \
  --azure-file-account-name $sa \
  --azure-file-account-key $storage_key \
  --azure-file-share-name $share


az containerapp secret set \
  --name "$app_name" \
  --resource-group "$rg" \
  --secrets pgpassword=S3cur3P@ssw0rd!

# Création de la Container App n8n
az containerapp create \
  --name "$app_name" \
  --resource-group "$rg" \
  --environment "$env_name" \
  --image n8nio/n8n:latest \
  --ingress external \
  --target-port 5678 \
  --min-replicas 1 \
  --max-replicas 3 \
  --cpu 0.5 \
  --memory 1.0Gi \
  --secrets pgpassword="$pgpassword" storagekey="$storage_key" \
  --env-vars  DB_TYPE=postgresdb \
              DB_POSTGRESDB_HOST="$pg_server.postgres.database.azure.com" \
              DB_POSTGRESDB_PORT=5432 \
              DB_POSTGRESDB_DATABASE="$pg_db_name" \
              DB_POSTGRESDB_USER="$pg_admin" \
              DB_POSTGRESDB_PASSWORD=secretref:pgpassword \
              DB_POSTGRESDB_SSL=true \
              DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED=false \
              N8N_BASIC_AUTH_ACTIVE=true \
              N8N_BASIC_AUTH_USER=admin \
              N8N_BASIC_AUTH_PASSWORD="Kawthar2012"


az containerapp identity assign \
  --name "$app_name" \
  --resource-group "$rg" \
  --user-assigned "$mi_resource_id"

az containerapp secret set \
  --name "$app_name" \
  --resource-group "$rg" \
  --secrets pgpassword=S3cur3P@ssw0rd!

# Ajkouter le share en mode volume dans l'application
# # Le volumeName = le nom du share dans l'environnement pas dans le compte de stockage :
az containerapp update \
  --name "$app_name" \
  --resource-group "$rg" \
  --set \
    configuration.volumes="[{'name':'n8nshare','storageType':'AzureFile','storageName':'n8nshare'}]"



# Montage du share dans l'application (le conteneur)
 :
az containerapp update \
  --name "$app_name" \
  --resource-group "$rg" \
  --set \
    template.containers[0].volumeMounts="[{'mountPath':'/home/node/.n8n','volumeName':'n8nstorageedulabs'}]"


# Vérification :
az containerapp show \
  --name "$app_name" \
  --resource-group "$rg" \
  --query "template.containers[0].volumeMounts"


# Exporter le template actuel de container app :
az containerapp show \
  --name "$app_name" \
  --resource-group "$rg" \
  --output yaml > n8n-app.yaml

# modifier le fichier yaml et ajouter le volumeMounts et volumes :

template:
  containers:
    - name: n8n-app
      image: n8nio/n8n:latest
      env:
        ...
        - name: N8N_USER_FOLDER
          value: /data
      ...
      volumeMounts:
        - mountPath: /data
          volumeName: n8n-vol
      ...
  volumes:
    - name: n8n-vol
      storageType: AzureFile
      storageName: n8nstorageedulabs
  ...

# Sauvegarder et mettez à jour le conteneur :   

az containerapp update   --name "$app_name"   --resource-group "$rg"   --yaml n8n-app.yaml














# Créer un fichier n8n_volume.yaml :

template:
  containers:
    - name: n8n-app
      image: n8nedulabs.azurecr.io/samples/n8n:latest
      resources:
        cpu: 0.5
        memory: 1.0Gi
      env:
        - name: DB_TYPE
          value: postgresdb
        - name: DB_POSTGRESDB_HOST
          value: n8n-pg-edulabs.postgres.database.azure.com
        - name: DB_POSTGRESDB_PORT
          value: "5432"
        - name: DB_POSTGRESDB_DATABASE
          value: n8n
        - name: DB_POSTGRESDB_USER
          value: n8nadmin@n8n-pg-edulabs
        - name: DB_POSTGRESDB_PASSWORD
          secretRef: pgpassword
        - name: DB_POSTGRESDB_SSL
          value: true
        - name: DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED	
          value: false




        - name: N8N_BASIC_AUTH_ACTIVE
          value: "true"
        - name: N8N_BASIC_AUTH_USER
          value: admin
        - name: N8N_BASIC_AUTH_PASSWORD
          value: Kawthar2012
      volumeMounts:
        - volumeName: n8nvolume
          mountPath: /home/node/.n8n
  volumes:
    - name: n8nvolume
      storageType: AzureFile
      storageName: n8nstorageedulabs


template:
  containers:
    - name: n8n-app
      image: n8nedulabs.azurecr.io/samples/n8n:latest
      volumeMounts:
        - volumeName: n8nvolume
          mountPath: /home/node/.n8n
  volumes:
    - name: n8nvolume
      storageType: AzureFile
      storageName: n8nstorageedulabs


# Faire l'update via le fichier yaml
az containerapp update \
  --name "$app_name" \
  --resource-group "$rg" \
  --yaml n8n_volume.yaml




              

## update du container app avec le nouveau volume
ajout du volume déclaré dans env
ajout montage dans le conteneur


### Configuration du domaine personnalisé & certificat géré
az containerapp ingress update \
  --name $APP_NAME \
  --resource-group $RG \
  --ingress external \
  --custom-domains "$CUSTOM_DOMAIN=managedCertificate"




# Les boins paramètres :
DB_TYPE	postgresdb
DB_POSTGRESDB_HOST	n8n-pg-edulabs.postgres.database.azure.com
DB_POSTGRESDB_PORT	5432
DB_POSTGRESDB_DATABASE	n8n
DB_POSTGRESDB_USER	n8nadmin@n8n-pg-edulabs






# Check log de container app :
az containerapp logs show   --name "$app_name"   --resource-group "$rg"   --follow

az containerapp revision list   --name "$app_name"   --resource-group "$rg"   --query "[].{Name:name, Active:active, Health:properties.healthState}"   -o table

az containerapp show   --name "$app_name"   --resource-group "$rg"   --query "properties.provisioningState"