# Azure Lab PoC – VM Debian en un clic

> **Attention : ce PoC est volontairement *non sécurisé*.  
> Utilisez-le uniquement sur un abonnement de test.**

## Prérequis

| Outil | Version minimale | Notes |
|-------|------------------|-------|
| **Node.js** | 18 .x | `npm` inclus |
| **Azure CLI** | 2.60+ | `az login` réalisé et abonnement sélectionné |
| **SSH** | client standard | pour tester la connexion |

## Installation

```bash
git clone <ce-repo> && cd azure-lab-poc      # ou copier/coller fichiers
npm install