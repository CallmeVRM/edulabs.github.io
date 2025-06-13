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


-------



## Déploiement :


#### Login sur Azure
```bash
az login
```


#### Créer un groupe de ressource :
```bash
az group create -n n8n -l eastus
```


#### Récupérer les informations dans une variable :
```bash
rg=$(az group show -n n8n --query "name" -o tsv)
loc=$(az group show -n n8n --query "location" -o tsv)
```

#### Créer un container Registries

```bash
az acr create \
  --resource-group $rg \
  --name edulabsn8n2 \
  --sku Standard \
  --location $loc \
  --admin-enabled true
```

#### Login dans la registry

```bash
az acr login --name edulabsn8n2
```

#### télécharger l'image qu'on veut utiliser, et l'upload sur notre ACR
```bash
docker pull docker.n8n.io/n8nio/n8n
docker tag docker.n8n.io/n8nio/n8n edulabsn8n2.azurecr.io/samples/n8n
docker push edulabsn8n2.azurecr.io/samples/n8n
```


#### Créer un environnement de container app
```bash
az containerapp env create \
  --name n8n-env \
  --resource-group $rg \
  --location $loc \
  --enable-workload-profiles false \
  --logs-destination none \
  --infrastructure-subnet-resource-id ""  # Pas de réseau privé, donc accès internet autorisé
```

#### Récuperer le mot de passe 
```bash
acr_password1=$(az acr credential show --name edulabsn8n2 --query "passwords[?name=='password'].value" --output tsv)
```

#### Créer un conteneur app
```bash
az containerapp create \
  --name n8n-app-1 \
  --resource-group $rg \
  --environment n8n-env \
  --image edulabsn8n2.azurecr.io/samples/n8n:latest \
  --target-port 5678 \
  --ingress external \
  --registry-server edulabsn8n2.azurecr.io \
  --registry-username edulabsn8n2 \
  --registry-password $acr_password1 \
  --cpu 0.5 --memory 1.0Gi \
  --min-replicas 1 --max-replicas 3 \
  --env-vars N8N_PORT=5678 \
             N8N_HOST=n8n \
             N8N_PROTOCOL=https \
             WEBHOOK_URL=https://n8n.edulabs.fr \
             GENERIC_TIMEZONE=Europe/Paris \
             N8N_BASIC_AUTH_ACTIVE=true \
             N8N_BASIC_AUTH_USER=admin \
             N8N_BASIC_AUTH_PASSWORD='MotDePasseSur123!'
```



















------










Si vous installer n8n en local modifiez votre fichier hosts que vous trouverez dans ` C:\Windows\System32\drivers\etc\hosts`  à fin d'ajouter la ligne suivante (x.x.x.x correspond à votre ip, par ex *192.168.10.6*)

```
x.x.x.x        n8n.edulabs.fr 
```


- #### Depuis le home de votre utilisateur $USER, créez un dossier :

```
mkdir n8n-dev
cd n8n-dev
```


- #### Dans le dossier `n8n-dev` créez un dossier `local-files` :

Dans ce dossier on va poser des fichiers en local pour pouvoir travailler avec dans le futur

``` bash
mkdir local-files
``` 



- #### Création du volume :
``` bash
podman volume create n8n
``` 

- #### Création et lancement du conteneur sur le port 80 de la machine :
``` bash
  podman run -d \
             --name n8n \
             --restart=always \
             -p 80:5678 \
             -v n8n:/home/node/.n8n \
             -e N8N_HOST=n8n.edulabs.fr \
             -e N8N_PORT=5678 \
             -e N8N_PROTOCOL=http \
             -e NODE_ENV=production \
             -e WEBHOOK_URL=http://n8n.edulabs.fr \
             -e N8N_SECURE_COOKIE=false \
             docker.n8n.io/n8nio/n8n
``` 

``` bash
#!/bin/bash

set -e

### === VARIABLES À PERSONNALISER === ###
DOMAIN="n8n.example.com"
EMAIL="admin@example.com"
N8N_USER="admin"
N8N_PASSWORD="motdepassefort"
N8N_PORT="5678"

### === PRÉPARATION DES DOSSIERS === ###
mkdir -p /opt/n8n/data
mkdir -p /opt/n8n/nginx

### === FICHIER .env === ###
cat > /opt/n8n/.env <<EOF
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=$N8N_USER
N8N_BASIC_AUTH_PASSWORD=$N8N_PASSWORD
N8N_HOST=$DOMAIN
N8N_PORT=$N8N_PORT
N8N_PROTOCOL=https
N8N_LOG_LEVEL=info
NODE_ENV=production
EOF

### === INSTALLATION DES DÉPENDANCES === ###
echo "[*] Installation de NGINX et Certbot..."
if command -v apt >/dev/null; then
    apt update
    apt install -y nginx certbot python3-certbot-nginx
elif command -v dnf >/dev/null; then
    dnf install -y nginx certbot python3-certbot-nginx
else
    echo "Distribution non supportée automatiquement. Installez nginx et certbot manuellement."
    exit 1
fi

systemctl enable --now nginx

### === CONFIGURATION NGINX TEMPORAIRE HTTP === ###
cat > /etc/nginx/sites-available/n8n <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:$N8N_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/n8n
nginx -t && systemctl reload nginx

### === CERTIFICAT LET'S ENCRYPT === ###
echo "[*] Obtention du certificat Let's Encrypt..."
certbot --nginx --non-interactive --agree-tos -m $EMAIL -d $DOMAIN

### === CONFIGURATION NGINX SSL === ###
cat > /etc/nginx/sites-available/n8n <<EOF
server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    location / {
        proxy_pass http://localhost:$N8N_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}
EOF

nginx -t && systemctl reload nginx

### === LANCEMENT DU CONTENEUR N8N === ###
echo "[*] Démarrage du conteneur n8n..."
podman pull docker.io/n8nio/n8n

podman rm -f n8n || true

podman run -d \
    --name n8n \
    --env-file /opt/n8n/.env \
    -v /opt/n8n/data:/home/node/.n8n \
    --network host \
    --restart=always \
    docker.io/n8nio/n8n

### === SERVICE SYSTEMD === ###
echo "[*] Création du service systemd..."
cat > /etc/systemd/system/n8n.service <<EOF
[Unit]
Description=n8n Podman Service
After=network.target

[Service]
Restart=always
ExecStart=/usr/bin/podman start -a n8n
ExecStop=/usr/bin/podman stop -t 10 n8n
TimeoutStartSec=0
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now n8n.service

echo "[✔] Déploiement terminé !"
echo "URL : https://$DOMAIN"
echo "Login : $N8N_USER"
echo "Mot de passe : $N8N_PASSWORD"

``` 

