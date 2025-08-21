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

## 🧪 Scénario du Lab

Vous rejoignez l’équipe IT d’une PME "Edulabs" qui compte environs 30 collaborateurs.  
Les départements principaux sont : `marketing`, `dev`, `hr`, `ops`, plus un groupe transverse `com`.

Arborescence de référence :
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