---
layout: page
title: "Scénario du Lab Linux — Sprint 1"
nav_order: 501
has_children: true
---
# Lab Linux — Utilisateurs, Groupes & Troubleshooting (Sprint 1)


## 🎯 Objectifs pédagogiques

- Créer et administrer des **comptes utilisateurs** (homes, shells, expiration de mot de passe).
- Gérer des **groupes** (primaire vs secondaires) et des **droits POSIX**.
- Mettre en place un **partage d’équipe** efficace (setgid, sticky-bit).
- Diagnostiquer et corriger des **pannes reproductibles** (écriture refusée, `passwd` KO, clé SSH non acceptée).

---

## ⚙️ Lancement (ISO ou Docker)

> *Cette section est indicative ; adaptez les URLs/tags à votre image publique.*

### Option A — ISO (VM)
1. Créez une VM (2 vCPU, 2 Go RAM, 15 Go disque).
2. Démarrez sur l’ISO préparée, terminez l’installation.
3. Connectez-vous en root (ou via `sudo`).

### Option B — Docker (image tout-en-un)
```bash
docker run -it --name lab-linux \
  --hostname Lab-scen1 \
  --privileged \
  -v lab_data:/srv \
  ghcr.io/<votre-org>/<votre-image>:<tag>
```

### Option C (Privé) — Cloud/Proxmox (VM) :
Loremipsum Loremipsum Loremipsum Loremipsum
Loremipsum Loremipsum Loremipsum Loremipsum
Loremipsum Loremipsum Loremipsum Loremipsum

---
## 🧪 Scénario du Lab

Vous rejoignez l’équipe IT d’une PME "Edulabs" qui compte environs 30 collaborateurs.  
Les départements principaux sont : `marketing`, `dev`, `hr`, `ops`, plus un groupe transverse `com`.

Arborescence de référence :
```bash
/srv/
└── depts/
├── marketing/
│ └── share/ (collaboration interne)
├── dev/
│ └── share/
├── hr/
│ └── share/
└── ops/
└── share/
```

Pendant le sprint 1 vous recevez **4 tickets pour des tâche divers** (T1→T4) et **4 incidents** (INC-01→04).  

Etant donnée que le lab est destiné à un public débutant à intérmédaire, 
vous pouvez restez avec le compte root. (chose à ne pas faire en production)

Les incidents sont **déclenchés à la demande** via des commandes simples (voir plus bas).


## Débuts des tickets Sprint 1 : 

*Règle d’or : réaliser les tickets dans l’ordre.*

### Ticket 1 - Onboarding d’Alice Dupont
Les tâches à faire :
1. Créer un compte `alice.dupont` (avec son propre /home et un shell /bin/bash).
2. Son groupe primaire doit être : marketing.
3. Pour des besoins de sécurité, forcez Alice a changer son mot de passe lors de son premier login.

Astuces : ```useradd``` ```usermod``` ```passwd``` ```chage```

### Ticket 2 - Groupe transverse com

1. Vérifier ou créer le groupe com.
2. Ajouter alice.dupont en groupe secondaire com.

Astuces : ```groupadd``` ```usermod```

### Ticket 3 - Partage Marketing (setgid)

1. Sur /srv/depts/marketing/share, activer setgid et les droits d’équipe.

Résultat attendu : répertoire en 2770 ; lorsqu'un fichier est créé il héritera des permissions du groupe marketing.

Astuces : `Le 2 active le setgid` `owner/groupe du dossier doivent être cohérents`.


### Ticket 4 — Squelette & Bob Martin (Dev)

Le squelette utilisateur doit être mis à jour pour correspondre aux conventions internes actuelles. 

On attend qu’il contienne :
- Un dossier Documents/
- Un fichier .bash_aliases avec l’alias : `ll='ls -alF'`

Une fois que c’est en place, tu peux créer l’utilisateur `bob.martin`, dans le groupe `dev`. 

Son environnement (/home, shell) doit refléter automatiquement ce qui a été défini dans le squelette.

Astuces : `install -d ... `. 

L’ordre des opérations est important : le squelette doit être prêt avant toute création de compte. L’objectif est que Bob Martin dispose, dès sa première connexion, d’un environnement cohérent avec nos pratiques.

---
---

# Troubleshooting incidents 

### Initialisation : Les incidents sont déclenchés par des commandes très simples :

**Déclenchement**

- go-incident01
- go-incident02
- go-incident03   # ⚠️ bloque *tous* les `passwd` tant qu’actif
- go-incident04


**Correction**
- stop-incident01
- stop-incident02
- stop-incident03
- stop-incident04


### INC-01 — « Je suis dans le groupe mais je ne peux pas écrire - alice.dupont»

**Contexte** : - Alice (groupe `marketing`) essaye de créer un fichier dans `/srv/depts/marketing/share` mais obtient « *Permission denied* ».

**Attendu** : 
- Alice peut créer un fichier.
- Le fichier appartient bien au **groupe** `marketing`.
- Les permissions finales du dossier sont `rwxrws---` (`2770`, owner `root:marketing`).

### INC-02 — « Oups, j'ai supprimé par erreur le fichier d'un collègue - alice.dupont »

**Contexte** : 

Dans le répertoire partagé `/srv/depts/marketing/share`, Alice vient de supprimer par erreur un fichier appartenant à Bob (`rapport_bob.txt`).

Or, selon la politique interne, chaque membre du groupe `marketing` doit pouvoir **gérer ses propres fichiers uniquement**, mais ne doit pas avoir la possibilité de supprimer ceux des autres.

**Détails** :

- Bob crée un fichier `rapport_bob.txt` dans le répertoire `share`.
- Alice exécute `rm rapport_bob.txt` → la commande réussit alors qu’elle ne devrait pas.
- Ce comportement expose le répertoire partagé à des suppressions accidentelles ou malveillantes.

**Attendu** : Seuls les propriétaires peuvent supprimer leur propres fichiers (le root aussi, et ce n'est pas un piège).


### INC-03 — « Je n'arrive plus à changer mon mot de passe : Authentication token manipulation error - camel.chalal »

**Contexte** : 

Camel Chalal (groupe dev) tente de changer son mot de passe et obtient immédiatement l’erreur :

`passwd: Authentication token manipulation error`

**Attendu** : 

passwd `camel.chalal` fonctionne normalement, l'utilisateur pourra donc modifier son mot de passe sans problème.

⚠️ Attention : tant que l’incident est actif, tous les passwd échouent.

### INC-04 — « Je n'arrive pas à me connecter en ssh avec la nouvelle clé  - camel.chalal »

**Contexte** : 

Le stagiaire sylvain.morel a ajouté une clé publique dans le fichier `~/.ssh/authorized_keys` du compte camel.chalal, afin de permettre une connexion SSH sans mot de passe. Pourtant, malgré cette configuration, le serveur continue de demander une authentification par mot de passe : la clé est ignorée.

Il semble que seul le fichier ait été créé, sans vérification des droits d’accès.

Le manager te demande de contrôler les permissions et les propriétaires des fichiers et répertoires liés à SSH, car une mauvaise configuration peut empêcher le serveur d’utiliser la clé.

**Attendu** : 

Une fois les bons droits appliqués, la connexion SSH par clé doit fonctionner sans basculer vers le mot de passe. Les permissions doivent être strictes :

- $HOME : 0755
- ~/.ssh : 0700
- authorized_keys : 0600

Tous les fichiers doivent appartenir à l’utilisateur camel.chalal.