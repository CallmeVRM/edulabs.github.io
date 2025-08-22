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

### Ticket 1 — Onboarding d’Alice Dupont
Les tâches à faire :
1. Créer un compte `alice.dupont` (avec son propre /home et un shell /bin/bash).
2. Son groupe primaire doit être : marketing.
3. Pour des besoins de sécurité, forcez Alice a changer son mot de passe lors de son premier login.

Astuces : ```useradd``` ```usermod``` ```passwd``` ```chage```

### Ticket 2 — Groupe transverse com

1. Vérifier ou créer le groupe com.
2. Ajouter alice.dupont en groupe secondaire com.

Astuces :
Hint 1 : ```groupadd```
Hint 2 : ```usermod```

T3 — Partage Marketing (setgid)

1. Sur /srv/depts/marketing/share, activer setgid et les droits d’équipe.
Attendu : répertoire en 2770 ; un fichier créé hérite du groupe marketing.


Hints :
Hint 1 : Le 2 active le setgid
Hint 2 : owner/groupe du dossier doivent être cohérents.
Hint 3 : testez avec sudo -u 


T4 — Squelette & Bob Martin (Dev)

1. S’assurer que /etc/skel contient :
Documents/
.bash_aliases avec alias ll='ls -alF'

2. Créer bob.martin (groupe primaire dev) et vérifier que son home inclut ces éléments.


Hints
Hint 1 : install -d ...
Hint 2 : pensez à créer Bob après la mise à jour de /etc/skel


Incidents débutant (INC-01 → 04)
Les incidents sont déclenchés par des commandes très simples :

# Déclenchement
sudo go-incident01
sudo go-incident02
sudo go-incident03   # ⚠️ bloque *tous* les `passwd` tant qu’actif
sudo go-incident04


# Correction
sudo stop-incident01
sudo stop-incident02
sudo stop-incident03
sudo stop-incident04


INC-01 — « Je suis dans le groupe mais je ne peux pas écrire »
Contexte : un membre marketing ne peut pas créer dans …/marketing/share.
Attendu : dossier en 2770 (setgid), écriture OK, héritage groupe marketing.

Hints
Hint 1 : droits g+w et setgid.
Hint 2 : vérifiez owner/groupe du répertoire.
Hint 3 : testez avec un utilisateur du groupe (alice.dupont).

INC-02 — « Suppression croisée non souhaitée »
Contexte : un membre peut supprimer le fichier d’un autre dans …/marketing/share.
Attendu : sticky-bit actif (le t), seuls propriétaires/root suppriment.

Hints
Hint 1 : sticky-bit sur le répertoire (pas sur les fichiers).
Hint 2 : le mode attendu doit montrer un t dans ls -ld.

INC-03 — passwd: Authentication token manipulation error
Contexte : la modification de mot de passe échoue (ex. /etc/shadow immutable).
Attendu : /etc/shadow non immutable, 0640 root:shadow ; /etc/passwd 0644 root:root ; passwd refonctionne.

Hints
Hint 1 : regardez les attributs de /etc/shadow.
Hint 2 : vérifiez owner/groupe/mode de /etc/shadow et /etc/passwd.
Hint 3 : les logs PAM sont bavards (auth.log / journalctl).

⚠️ Attention : tant que l’incident est actif, tous les passwd échouent.

INC-04 — Clé SSH ignoré
Contexte : la connexion par clé est refusée, on retombe sur un mot de passe.
Attendu : $HOME ≤ 755, ~/.ssh = 700, authorized_keys = 600, owner correct.

Hints
Hint 1 : StrictModes yes refuse les permissions trop ouvertes.
Hint 2 : vérifiez les 3 niveaux : $HOME, ~/.ssh, authorized_keys.
Hint 3 : attention au propriétaire des chemins (pas root).
