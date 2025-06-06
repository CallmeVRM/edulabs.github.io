---
layout: default
title: Navigation
parent: Les bases de Linux
nav_order: 2
---

# Navigation

Sur Linux, tout est fichier, et c’est organisé sous forme de dossiers (aussi appelés répertoires). Savoir où vous vous trouvez, comment aller ailleurs et comment revenir en arrière est fondamental pour pouvoir gérer des fichiers, exécuter des scripts ou installer des programmes.

```bash
pwd                       # Affiche votre dossier actuel / Vérifiez votre emplacement
cd /tmp                   # Allez dans le dossier /tmp
cd ..                     # Revenir vers le dossier précédent ( Le point représente le dossier actuel)
ls -l                     # Observez le contenu du répertoire actuel en mode liste
ls -lha                   # Observer le contenu ainsi que les fichiers cachés
ls -l /etc                # Observer le contenu du répertoire /tmp en mode liste
pushd /etc                # Changez pour /etc et sauvegardez /tmp dans une pile
popd                      # Revenez à votre dossier précédent (/tmp)
```


### 1. 📍 Vérifier où vous êtes : pwd


```bash
pwd
```

`pwd` = *print working directory* → affiche le chemin complet du dossier dans lequel vous êtes actuellement.

**Pourquoi c’est utile ?**

Parce que dans un terminal, **vous n’avez pas de fenêtre graphique**. Il est donc essentiel de **savoir où vous vous situez** avant de manipuler des fichiers, et dans certains cas, deux fichiers dans deux dossiers différents peuvent porter le même nom.

### 2. 📁 Se déplacer dans un autre dossier : `cd /tmp`

Avant d’expliquer en détail la commande `cd`, l’une des plus utilisées en ligne de commande, il est essentiel de bien comprendre la notion de **chemin absolu** et de **chemin relatif**.

### 🔹 Chemin absolu

Un **chemin absolu** commence **toujours par une barre oblique `/`**, qui représente la **racine du système de fichiers**.

Ce type de chemin décrit **l’adresse complète** d’un fichier ou d’un dossier, indépendamment de votre position actuelle dans l’arborescence.


Par exemple :
```bash
cd /etc/apt/keyrings/
```

Cette commande vous amène directement dans le dossier keyrings qui se trouve dans le dossier apt et que ce dernier se trouve dans le dossier etc qui lui se trouve dans la racine /

























Contenu ici...

Un exemple de surlignage `texte à surligner`.

<button class="btn js-toggle-dark-mode">Passer en mode nuit</button>

<script>
const toggleDarkMode = document.querySelector('.js-toggle-dark-mode');

jtd.addEvent(toggleDarkMode, 'click', function(){
  if (jtd.getTheme() === 'dark') {
    jtd.setTheme('light');
    toggleDarkMode.textContent = 'Preview dark color scheme';
  } else {
    jtd.setTheme('dark');
    toggleDarkMode.textContent = 'Return to the light side';
  }
});
</script>

{: .note }
Ceci est une note

```scss
ceci est un texte embedded
```
