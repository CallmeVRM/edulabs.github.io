---
layout: default
title: Installation n8n sur Azure ACAazd
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

### Connexion à Azure
```bash
az login
```

### Extension Container Apps :
```bash
az extension add --name containerapp
az extension add --name storage-preview
```

### Variables (à adapter)
```bash
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
```

### Création du groupe de ressources
```bash
az group create \
  --name $rg \
  --location $loc
```

### Création des ressources de stockage
#### Storage Account et File Share

Le stockage Azure Files permet la persistance des données n8n entre les redémarrages, il permet aussi d’offrir à n8n un espace de stockage ou l’on peut upload ou download des fichiers si on veut travailler avec localement

#### Création du Storage Accountaz storage account create 
```bash
az storage account create \
  --name $sa \
  --resource-group $rg \
  --location $loc \
  --sku Standard_LRS
```

#### Création du file share
```bash
az storage share create \
  --account-name $sa \
  --name $share
```
#### Création du file share
```bash
storage_key=$(az storage account keys list \
  --account-name $sa \
  --resource-group $rg \
  --query '[0].value' -o tsv)
```

## Déploiement de la base de données PostgreSQL
### Création du serveur PostgreSQL
```bash
# Vérification du provider PostgreSQL
az provider show -n Microsoft.DBforPostgreSQL
az provider show --namespace Microsoft.DBforPostgreSQL --query registrationState

# Création du serveur flexible PostgreSQL
az postgres flexible-server create \
  --resource-group $rg \
  --name $pg_server \
  --location $loc \
  --admin-user $pg_admin \
  --admin-password $pgpassword \
  --sku-name Standard_B1ms \
  --tier Burstable \
  --storage-size 32
```
### Configuration des règles de pare-feu
```bash
# Autoriser les connexions depuis Azure
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
```bash
az acr create \
  --resource-group "$rg" \
  --name "$acr_name" \
  --sku Standard \
  --location "$loc" \
  --admin-enabled true
```

#### Récupération des identifiants ACR et 
```bash
acr_username=$(az acr credential show --name "$acr_name" --query "username" -o tsv)
acr_password=$(az acr credential show --name "$acr_name" --query "passwords[0].value" -o tsv)
login_server="${acr_name}.azurecr.io"
```

#### Connexion Docker au registre et upload de l'image dans l'ACR
```bash
docker login "$login_server" --username "$acr_username" --password "$acr_password"

#### Pull, tag et push de l'image n8n
docker pull docker.n8n.io/n8nio/n8n
docker tag docker.n8n.io/n8nio/n8n "$login_server/sample:n8n"
docker push "${acr_name}.azurecr.io/sample:n8n"
```


### Création de l'environnement Container Apps
#### Création de l'environnement Container Apps
```bash
az containerapp env create \
  --name $env_name \
  --resource-group $rg \
  --logs-destination none \
  --location $loc
```

### Configuration de l'identité managée
#### Création de l'identité managée
```bash
az identity create \
  --resource-group $rg \
  --name n8n-identity
```

#### Récupération des informations d'identité
```bash
mi_principal_id=$(az identity show \
  --resource-group $rg \
  --name n8n-identity \
  --query 'principalId' -o tsv)
mi_resource_id=$(az identity show \
  --resource-group $rg \
  --name n8n-identity \
  --query 'id' -o tsv)
```

#### Attribution du rôle de contributeur sur le stockage
```bash
az role assignment create \
  --assignee-object-id $mi_principal_id \
  --assignee-principal-type ServicePrincipal \
  --role "Storage File Data SMB Share Contributor" \
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$rg/providers/Microsoft.Storage/storageAccounts/$sa"
```

#### Ajout du volume de stockage à l'environnement
```bash
az containerapp env storage set \
  --name n8n-env \
  --resource-group $rg \
  --storage-name $shareenv \
  --access-mode ReadWrite \
  --azure-file-account-name $sa \
  --azure-file-account-key $storage_key \
  --azure-file-share-name $share
```

### Déploiement de l'application n8n
#### Création de l'application Container Apps
```bash
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
```

#### Attribution de l'identité managée à l'application
```bash
az containerapp identity assign \
  --name "$app_name" \
  --resource-group "$rg" \
  --user-assigned "$mi_resource_id"
```

#### Configuration des secrets et identité
```bash
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

### Configuration du stockage persistant
# Export de la configuration actuelle
```bash
az containerapp show \
  --name "$app_name" \
  --resource-group "$rg" \
  --output yaml > n8n-app.yaml
```

Modifiez le fichier `n8n-app.yaml` pour ajouter le volume mount :
Attention n’ajoutez pas la dernière partie `volumes:` n’importe où, il y a un bloc spécifique.

```yaml
template:
  containers:
    - name: n8n-app
      image: n8nio/n8n:latest
      env:
        # ... variables existantes ...
        - name: DB_POSTGRESDB_PASSWORD
	        secretRef: pgpassword
	      - name: N8N_BASIC_AUTH_PASSWORD
		      secretRef: n8nadminpas
        - name: N8N_USER_FOLDER
          value: /data
      # Ajout du volumeMounts
      volumeMounts:
        - mountPath: /data
          volumeName: n8n-vol
  # Configuration des volumes
  volumes:
    - name: n8n-vol
      storageType: AzureFile
      storageName: n8nshare
```

#### Application de la nouvelle configuration
```bash
az containerapp update \
        --name "$app_name" \
        --resource-group "$rg" \
        --yaml n8n-app.yaml
```

### Configuration du domaine personnalisé
#### Récupération des informations de l'application

# FQDN de l'application
```bash
fqdn=$(az containerapp show \
  --name "$app_name" \
  --resource-group "$rg" \
  --query "properties.configuration.ingress.fqdn" \
  -o tsv)
echo "FQDN: $fqdn"

# ID de vérification du domaine personnalisé
verification_id=$(az containerapp show \
  --name "$app_name" \
  --resource-group "$rg" \
  --query "properties.customDomainVerificationId" \
  -o tsv)
echo "Verification ID: $verification_id"
```

### Configuration DNS
Avant de continuer, configurez les enregistrements DNS suivants chez votre registraire :
1. **Enregistrement CNAME** : `n8n.edulabs.fr` → `$fqdn`
2. **Enregistrement TXT** : `asuid.n8n.edulabs.fr` → `$verification_id`

#### Ajout du domaine personnalisé
```bash
az containerapp hostname add \
  --resource-group "$rg" \
  --name "$app_name" \
  --hostname "$custom_domain"
```

#### Configuration SSL
Avant de lié le certificat au domaine, il faut patienter le temps de création environs (~ 5 min)
```bash
# Création du certificat SSL managé
az containerapp env certificate create \
  --resource-group "$rg" \
  --name "$env_name" \
  --hostname "$custom_domain" \
  --validation-method CNAME \
  --certificate-name "$cert_name"

# Liaison du certificat au domaine
az containerapp hostname bind \
  --resource-group "$rg" \
  --name "$app_name" \
  --hostname "$custom_domain" \
  --certificate "$cert_name" \
  --environment "$env_name"
```

### Proof of Concept
Après avoir fait l’enregistrement classique de n8n avec le mail…
On va créer un workflow pour vérifier le bon fonctionnement de mon intégration AzureFile
Au niveau du AzureFile j’ai créé un dossier `uploads`
```bash
az storage directory create \
  --account-name "$sa" \
  --share-name "$share" \
  --name uploads \
  --account-key $storage_key \
  --enable-file-backup-request-intent
```

- Voici le schéma simple du workflow :

- Configuration du module HTTP Request :

- Configuration du module Read/Write Files from Disk :

- Exécution du workflow


#### On a bien notre fichier dans le dossier uploads :


airg="openai-rg"

# Déploiement Azure OPEN AI 
### Déploiement de Azure Foundry AI :
#### Création d’un nouveau groupe de ressource
az group create \
  --name $airg \
  --location $loc


#### Enregistrer le provider OpenAI
az provider register --namespace Microsoft.CognitiveServices
az provider show --namespace Microsoft.CognitiveServices --query "registrationState"


#### Création d’un compte cognitive service
az cognitiveservices account create \
  --name edulabseu-openai-service \
  --resource-group openai-rg \
  --kind OpenAI \
  --sku S0 \
  --location $loc \
  --yes \
  --custom-domain edulabseu-openai-service \
  --api-properties '{"DisableLocalAuth": false}'

#### Déployer un modèle depuis le CLI :
az cognitiveservices account deployment create \
  --resource-group "openai-rg" \
  --name "edulabseu-openai-service" \
  --deployment-name "n8n-gpt4o" \
  --model-name "gpt-4o" \
  --model-version "2024-11-20" \
  --model-format "OpenAI" \
  --sku-name "Standard" \
  --capacity "100"

Parmi les 37 modèles disponible, notre choix s’est porté sur modèle gpt-4o qui représente le meilleur rapport qualité prix pour notre projet.


#### Récupérer les identifiants pour la connexion depuis n8n :



















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
