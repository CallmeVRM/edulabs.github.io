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



## Version Azure CLI : N8N + FileStorage + Certificat + postgreSQL : ChatGPT o4 mini high


#### Connexion à Azure
az login

### Extension Container Apps :
az extension add --name containerapp
az extension add --name storage-preview

### Variables (à adapter)

# Groupe de ressources et région
rg="n8n-rg"
loc="francecentral"
# Storage pour le file share
sa="n8nstorageedu"
share="n8nshare"
# Postgres flexible server
pg_server="n8n-pg-edulabs"
pg_admin="n8nadmin"
pgpassword="S3cur3P@ssw0rd!"  
pg_db_name="n8n"
# Container Apps
env_name="n8n-env"
app_name="n8n-app"
shareenv="n8nshare"
# Domaine personnalisé
custom_domain="n8n.edulabs.fr" 
# Azure Container Registry
acr_name="n8nedulabs"
# Nom du certificat SSL
cert_name="n8n-cert"

### Création du groupe de ressources
az group create \
  --name $rg \
  --location $loc

### Création des ressources de stockage

#### Storage Account et File Share

Le stockage Azure Files permet la persistance des données n8n entre les redémarrages, il permet aussi d’offrir à n8n un espace de stockage ou l’on peut upload ou download des fichiers si on veut travailler avec localement

#### Création du Storage Accountaz storage account create 
az storage account create \
  --name $sa \
  --resource-group $rg \
  --location $loc \
  --sku Standard_LRS

#### Création du file share
az storage share create \
  --account-name $sa \
  --name $share

#### Création du file share
storage_key=$(az storage account keys list \
  --account-name $sa \
  --resource-group $rg \
  --query '[0].value' -o tsv)

## Déploiement de la base de données PostgreSQL
### Création du serveur PostgreSQL
#### Vérification du provider PostgreSQL
az provider show -n Microsoft.DBforPostgreSQL
az provider show --namespace Microsoft.DBforPostgreSQL --query registrationState

#### Création du serveur flexible PostgreSQL
az postgres flexible-server create \
  --resource-group $rg \
  --name $pg_server \
  --location $loc \
  --admin-user $pg_admin \
  --admin-password $pgpassword \
  --sku-name Standard_B1ms \
  --tier Burstable \
  --storage-size 32

### Configuration des règles de pare-feu
#### Autoriser les connexions depuis Azure
```bash
az postgres flexible-server firewall-rule create \
  --resource-group "$rg" \
  --name "$pg_server" \
  --rule-name AllowAzureIPs \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0

#Remplacer par votre ip publique
az postgres flexible-server firewall-rule create \
  --resource-group "$rg" \
  --name "$pg_server" \
  --rule-name AllowMyIP \
  --start-ip-address 82.123.x.x \
  --end-ip-address 82.123.x.x
```

#### Création de la base de données n8n
```bash
# Connexion à la base de données
psql -h n8n-pg-edulabs.postgres.database.azure.com -U n8nadmin -d postgres -p 5432

# Dans psql, créer la base de données n8n
CREATE DATABASE n8n;

# Quitter psql
\q
```
### Configuration d'Azure Container Registry
#### Création de l'Azure Container Registry

az acr create \
  --resource-group "$rg" \
  --name "$acr_name" \
  --sku Standard \
  --location "$loc" \
  --admin-enabled true

#### Récupération des identifiants ACR
acr_username=$(az acr credential show --name "$acr_name" --query "username" -o tsv)
acr_password=$(az acr credential show --name "$acr_name" --query "passwords[0].value" -o tsv)
login_server="${acr_name}.azurecr.io"

#### Connexion Docker au registre
docker login "$login_server" --username "$acr_username" --password "$acr_password"

#### Pull, tag et push de l'image n8n
docker pull docker.n8n.io/n8nio/n8n
docker tag docker.n8n.io/n8nio/n8n "$login_server/sample:n8n"
docker push "${acr_name}.azurecr.io/sample:n8n"

### Création de l'environnement Container Apps
#### Création de l'environnement Container Apps
az containerapp env create \
  --name $env_name \
  --resource-group $rg \
  --logs-destination none \
  --location $loc

### Configuration de l'identité managée
#### Création de l'identité managée
az identity create \
  --resource-group $rg \
  --name n8n-identity

#### Récupération des informations d'identité
mi_principal_id=$(az identity show \
  --resource-group $rg \
  --name n8n-identity \
  --query 'principalId' -o tsv)
mi_resource_id=$(az identity show \
  --resource-group $rg \
  --name n8n-identity \
  --query 'id' -o tsv)

#### Attribution du rôle de contributeur sur le stockage
az role assignment create \
  --assignee-object-id $mi_principal_id \
  --assignee-principal-type ServicePrincipal \
  --role "Storage File Data SMB Share Contributor" \
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$rg/providers/Microsoft.Storage/storageAccounts/$sa"

#### Ajout du volume de stockage à l'environnement

az containerapp env storage set \
  --name n8n-env \
  --resource-group $rg \
  --storage-name $shareenv \
  --access-mode ReadWrite \
  --azure-file-account-name $sa \
  --azure-file-account-key $storage_key \
  --azure-file-share-name $share

### Déploiement de l'application n8n
#### Création de l'application Container Apps
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
              DB_POSTGRESDB_SSL=true \
              DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED=false \
              N8N_BASIC_AUTH_ACTIVE=true \
              N8N_BASIC_AUTH_USER=admin \
              N8N_HOST=n8n.edulabs.fr \
              N8N_PROTOCOL=https \
              WEBHOOK_TUNNEL_URL=https://n8n.edulabs.fr/

#### Configuration des secrets et identité
```bash
# Attribution de l'identité managée à l'application
az containerapp identity assign \
  --name "$app_name" \
  --resource-group "$rg" \
  --user-assigned "$mi_resource_id"

# Configuration des secrets
az containerapp secret set \
  --name "$app_name" \
  --resource-group "$rg" \
  --secrets pgpassword=S3cur3P@ssw0rd!
  
az containerapp secret set \
  --name "$app_name" \
  --resource-group "$rg" \
  --secrets n8nadminpass=S3cur3P@ssw0rd!
```




















### Base de données PostgreSQL
az provider show -n Microsoft.DBforPostgreSQL
az provider show --namespace Microsoft.DBforPostgreSQL --query registrationState

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

az containerapp env storage set \
  --name n8n-env \
  --resource-group $rg \
  --storage-name $shareenv \
  --access-mode ReadWrite \
  --azure-file-account-name $sa \
  --azure-file-account-key $storage_key \
  --azure-file-share-name $share

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
              N8N_BASIC_AUTH_PASSWORD=secretref:n8nBasicAuthPass

# Assigner une identité à l'application
az containerapp identity assign \
  --name "$app_name" \
  --resource-group "$rg" \
  --user-assigned "$mi_resource_id"

# Création d'un secret dans l'application
az containerapp secret set \
  --name "$app_name" \
  --resource-group "$rg" \
  --secrets pgpassword=S3cur3P@ssw0rd!

az containerapp secret set \
  --name "$app_name" \
  --resource-group "$rg" \
  --secrets n8nBasicAuthPass=S3cur3P@ssw0rd!


# Ajouter le share en mode volume dans l'application
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
      # Ajouter le volumeMounts
      volumeMounts:
        - mountPath: /data
          volumeName: n8n-vol
      ...
  # modifier la partie volumes: 
  volumes:
    - name: n8n-vol
      storageType: AzureFile
      storageName: n8nshare
  ...

# Sauvegarder et mettez à jour le conteneur :   

az containerapp update \
        --name "$app_name" \
        --resource-group "$rg" \
        --yaml n8n-app.yaml


# Vérification :
az containerapp show \
  --name "$app_name" \
  --resource-group "$rg" \
  -o jsonc


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
echo $verification_id

# 10. Attendre que le DNS TXT soit propagé, puis :
az containerapp hostname add \
  --resource-group "$rg" \
  --name "$app_name" \
  --hostname "$custom_domain"

# 11. Créer un certificat SSL managé
az containerapp env certificate create \
  --resource-group "$rg" \
  --name "$env_name" \
  --hostname "$custom_domain" \
  --validation-method CNAME \
  --certificate-name "$cert_name"

# 12. Lier le certificat SSL au domaine
az containerapp hostname bind \
  --resource-group "$rg" \
  --name "$app_name" \
  --hostname "$custom_domain" \
  --certificate "$cert_name" \
  --environment "$env_name"


# Déploiement Azure OPEN AI 




# Déploiement Azure OPEN AI 
# Vérifier l’accès à Azure OpenAI:
az provider register --namespace Microsoft.CognitiveServices
az provider show --namespace Microsoft.CognitiveServices --query "registrationState"



# ########################## A FINIR #############

# Création groupe de ressource pour l'IA
az group create --name openai-rg --location westus

# Création de la ressource open AI :
az cognitiveservices account create \
  --name edulabs-openai-service \
  --resource-group openai-rg \
  --kind OpenAI \
  --sku S0 \
  --location $loc \
  --yes \
  --custom-domain edulabs-openai-service \
  --api-properties '{"DisableLocalAuth": false}'

# Déployer le modèle Open AI :
az cognitiveservices account deployment create \
  --resource-group openai-rg \
  --name edulabs-openai-service \
  --deployment-name gpt4o-deploy \
  --model-name gpt-4o \
  --model-format OpenAI \
  --model-version 2024-11-20 \
  --sku standard \
  --capacity 450























# Créer un fichier n8n_volume.yaml :
id: /subscriptions/d79cc050-a650-4718-9b4d-b0d305a43866/resourceGroups/n8n-rg/providers/Microsoft.App/containerapps/n8n-app
identity:
  type: UserAssigned
  userAssignedIdentities:
    ? /subscriptions/d79cc050-a650-4718-9b4d-b0d305a43866/resourcegroups/n8n-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/n8n-identity
    : clientId: 343ef257-0835-4600-8ddf-8103a1ad014f
      principalId: 9028d3bd-1f14-40dc-a4fb-58079b0f26c1
location: West US
name: n8n-app
properties:
  configuration:
    activeRevisionsMode: Single
    dapr: null
    identitySettings: []
    ingress:
      additionalPortMappings: null
      allowInsecure: false
      clientCertificateMode: null
      corsPolicy: null
      customDomains: null
      exposedPort: 0
      external: true
      fqdn: n8n-app.thankfulmushroom-9894101b.westus.azurecontainerapps.io
      ipSecurityRestrictions: null
      stickySessions: null
      targetPort: 5678
      targetPortHttpScheme: null
      traffic:
      - latestRevision: true
        weight: 100
      transport: Auto
    maxInactiveRevisions: 100
    registries: null
    revisionTransitionThreshold: null
    runtime: null
    secrets:
    - name: pgpassword
    - name: storagekey
    service: null
    targetLabel: ''
  customDomainVerificationId: 4C7F8FEC8D96840F7B333254A1E5129CBCB51DE90F643B2F29C294F7C0EB1A28
  delegatedIdentities: []
  environmentId: /subscriptions/d79cc050-a650-4718-9b4d-b0d305a43866/resourceGroups/n8n-rg/providers/Microsoft.App/managedEnvironments/n8n-env
  eventStreamEndpoint: https://westus.azurecontainerapps.dev/subscriptions/d79cc050-a650-4718-9b4d-b0d305a43866/resourceGroups/n8n-rg/containerApps/n8n-app/eventstream
  latestReadyRevisionName: n8n-app--1z4qwhj
  latestRevisionFqdn: n8n-app--1z4qwhj.thankfulmushroom-9894101b.westus.azurecontainerapps.io
  latestRevisionName: n8n-app--1z4qwhj
  managedEnvironmentId: /subscriptions/d79cc050-a650-4718-9b4d-b0d305a43866/resourceGroups/n8n-rg/providers/Microsoft.App/managedEnvironments/n8n-env
  outboundIpAddresses:
  - 13.87.246.93
  - 13.87.246.131
  - 13.87.246.102
  - 13.87.246.100
  - 13.93.214.71
  - 13.91.44.183
  - 13.91.98.58
  - 13.91.96.202
  - 13.91.40.31
  - 13.91.45.140
  - 20.253.254.228
  - 20.253.254.247
  - 20.253.254.64
  - 20.253.254.235
  - 104.210.49.205
  - 104.210.49.250
  - 104.210.49.206
  - 104.210.55.200
  - 104.210.49.225
  - 104.210.49.214
  - 172.184.137.142
  patchingMode: Automatic
  provisioningState: Succeeded
  runningStatus: Running
  template:
    containers:
    - env:
      - name: N8N_USER_FOLDER
        value: /data
      - name: DB_TYPE
        value: postgresdb
      - name: DB_POSTGRESDB_HOST
        value: n8n-pg-edulabs.postgres.database.azure.com
      - name: DB_POSTGRESDB_PORT
        value: '5432'
      - name: DB_POSTGRESDB_DATABASE
        value: n8n
      - name: DB_POSTGRESDB_USER
        value: n8nadmin
      - name: DB_POSTGRESDB_PASSWORD
        secretRef: pgpassword
      - name: DB_POSTGRESDB_SSL
        value: 'true'
      - name: DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED
        value: 'false'
      - name: N8N_BASIC_AUTH_ACTIVE
        value: 'true'
      - name: N8N_BASIC_AUTH_USER
        value: admin
      - name: N8N_BASIC_AUTH_PASSWORD
        value: Kawthar2012
      volumeMounts:
        - mountPath: /data
          volumeName: n8nshare
      image: n8nio/n8n:latest
      imageType: ContainerImage
      name: n8n-app
      resources:
        cpu: 0.5
        ephemeralStorage: 2Gi
        memory: 1Gi
    volumes:
      - name: n8nshare
        storageType: AzureFile
        storageName: n8nshare
    initContainers: null
    revisionSuffix: ''
    scale:
      cooldownPeriod: 300
      maxReplicas: 3
      minReplicas: 1
      pollingInterval: 30
      rules: null
    serviceBinds: null
    terminationGracePeriodSeconds: null
  workloadProfileName: Consumption
resourceGroup: n8n-rg
systemData:
  createdAt: '2025-06-18T13:19:32.8330683'
  createdBy: lotfi.hamadene@social.aston-ecole.com
  createdByType: User
  lastModifiedAt: '2025-06-18T13:21:28.4085398'
  lastModifiedBy: lotfi.hamadene@social.aston-ecole.com
  lastModifiedByType: User
type: Microsoft.App/containerApps



# Check log de container app :
az containerapp logs show   --name "$app_name"   --resource-group "$rg"   --follow

az containerapp revision list   --name "$app_name"   --resource-group "$rg"   --query "[].{Name:name, Active:active, Health:properties.healthState}"   -o table

az containerapp show   --name "$app_name"   --resource-group "$rg"   --query "properties.provisioningState"



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
