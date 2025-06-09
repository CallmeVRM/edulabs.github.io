---
layout: default
title: Navigation
parent: Les bases de Linux
nav_order: 23



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

Sur Linux, tout est fichier, et c’est organisé sous forme de dossiers (aussi appelés *répertoires*). Savoir où vous vous trouvez, comment aller ailleurs et comment revenir en arrière est **fondamental** pour pouvoir gérer des fichiers, exécuter des scripts ou installer des programmes.

🔹 **Commandes à retenir :**

```
pwd                       # Affiche votre dossier actuel / Vérifiez votre emplacement
cd /tmp                   # Allez dans le dossier /tmp
cd ..                     # Revenir vers le dossier précédent ( Le point représente le dossier actuel)
ls -l                     # Observez le contenu du répertoire actuel en mode liste
ls -lha                   # Observer le contenu ainsi que les fichiers cachés
ls -l /etc                # Observer le contenu du répertoire /tmp en mode liste
pushd /etc                # Changez pour /etc et sauvegardez /tmp dans une pile
popd                      # Revenez à votre dossier précédent (/tmp)

```

## 1. Position actuelle, vérifier où vous êtes {#position}
```bash
pwd
```

`pwd` = *print working directory* → affiche le chemin complet du dossier dans lequel vous êtes actuellement.

**Pourquoi c’est utile ?**

Parce que dans un terminal, vous n’avez pas de fenêtre graphique. Il est donc essentiel de savoir où vous vous situez avant de manipuler des fichiers, et dans certains cas, deux fichiers dans deux dossiers différents peuvent porter le même nom.

## 2. Se déplacer dans l'environnement Linux {#deplacement}
La commande cd (change directory) est l'une des plus couramment utilisées en ligne de commande.
Avant d'apprendre à l'utiliser efficacement, il est crucial de bien comprendre deux notions fondamentales : le chemin absolu et le chemin relatif.

**🔹 Chemin absolu**

Un chemin absolu commence toujours par une barre oblique /, qui représente la racine du système de fichiers. Il indique l'emplacement exact d’un dossier ou d’un fichier, quel que soit l’endroit où vous vous trouvez dans l’arborescence.

Par exemple :

```bash
cd /etc/apt/keyrings/
```

Cette commande vous amène directement dans le dossier `keyrings`, situé dans `apt`, lui-même dans `etc`, qui se trouve à la racine `/`.

En d’autres termes, avec un chemin absolu, vous indiquez à Linux :

*« Va chercher ce dossier en partant de tout en haut de l’arborescence. »*

**🔹 Chemin relatif**

Le chemin relatif dépend de votre position actuelle dans l’arborescence du système de fichiers.
Contrairement au chemin absolu, il ne commence jamais par une barre oblique `/`.

Il sert à indiquer un chemin à partir du dossier dans lequel vous vous trouvez actuellement.

 Si vous exécutez la commande suivante :

```bash
cd /etc
```

Vous vous trouvez maintenant dans le dossier `/etc`.

À partir de là, pour accéder au dossier `keyrings` situé dans le sous-dossier `apt`, vous pouvez simplement taper :

```bash
cd apt/keyrings/
```

Inutile donc de préciser le chemin complet (`/etc/apt/keyrings`) car vous êtes déjà dans `/etc`. Le chemin relatif vous permet donc d’aller plus loin depuis votre position actuelle, sans repartir de la racine

🔁 **Revenir en arrière avec `cd ..`**

Maintenant que vous savez comment accéder à un dossier à l’aide d’un **chemin absolu** ou **relatif**, il est tout aussi important de savoir **comment remonter dans l’arborescence**.

Pour cela, Linux utilise deux symboles simples mais essentiels :

- `.` → représente le **dossier actuel**
- `..` → représente le **dossier parent**, c’est-à-dire le dossier **au-dessus** de celui où vous vous trouvez

La commande :

```
cd ..
```

vous permet de **remonter d’un niveau** dans la hiérarchie des dossiers.

💡 **Exemple :**

Si vous êtes actuellement dans le dossier :

```
/etc/apt/keyrings
```

et que vous exécutez :

```bash
cd ..
```

vous remontez dans :

```bash
/etc/apt
```

Et si vous tapez à nouveau :

```bash
cd ..
```

vous vous retrouvez dans :

```bash
/etc
```

En résumé, `cd ..` signifie littéralement :

**« Change de dossier vers le dossier parent. »**

👉 Il existe d’autres moyens de naviguer plus rapidement dans l’arborescence, mais cela dépasse le cadre de ce chapitre.

## 3. Explorer le contenu d’un dossier avec ls {#liste}

Une fois que vous savez **où vous êtes** (`pwd`) et **vous déplacer** (`cd`), il est essentiel de savoir **ce qu’il y a autour de vous**.

C’est là que la commande `ls` entre en jeu : elle permet de **lister le contenu** d’un répertoire.

🔹 `ls -l` : afficher les fichiers en mode liste détaillée

```bash
ls -l
```

Cette commande affiche le contenu du répertoire courant en mode liste détaillée, utile pour analyser en détail la structure d’un répertoire.

Cela vous donne plus d’informations que la commande `ls` simple, notamment :

- les **droits** d’accès (lecture, écriture, exécution)
- le **nombre de liens**
- le **propriétaire**
- le **groupe**
- la **taille**
- la **date de dernière modification**
- et bien sûr, le **nom du fichier ou dossier**

🔹 `ls -lha` : tout voir, y compris les fichiers cachés

```bash
ls -lha
```

Cette version combine plusieurs options :

- `l` : mode liste détaillée (comme vu plus haut)
- `h` : format "lisible par un humain" (affiche par exemple `2.5K` au lieu de `2560`)
- `a` : affiche **tous les fichiers**, y compris les **fichiers cachés** (ceux qui commencent par un `.`)

> ⚠️ Par défaut, ls ne montre pas les fichiers cachés.
> 
> 
> Cette option est donc précieuse pour explorer un dossier en profondeur, notamment les configurations (`.bashrc`, `.gitignore`, etc.).
> 

🔹 `ls -l /etc` : lister un autre dossier sans s’y déplacer

```bash
ls -l /etc
```

Cette commande vous permet de **consulter le contenu d’un répertoire spécifique**, ici `/etc`, **sans avoir besoin d’y entrer avec `cd`**.

Vous pouvez utiliser cette méthode pour jeter un œil rapide à n’importe quel dossier du système.

>  Pratique quand on veut juste consulter le contenu d’un répertoire sans quitter celui où l’on est.

En résumé :

| Commande | Effet |
| --- | --- |
| `ls -l` | Affiche le contenu détaillé du dossier actuel |
| `ls -lha` | Affiche tout, y compris les fichiers cachés, avec des tailles lisibles |
| `ls -l /etc` | Affiche le contenu détaillé d’un dossier spécifique (ici `/etc`) |

## 4. Astuce pour aller plus vite {#pushdpopd}
Lorsque vous travaillez dans le terminal, il est courant de devoir passer temporairement d’un dossier à un autre, puis de revenir exactement là où vous étiez.

Plutôt que de mémoriser votre position actuelle ou de retaper manuellement le chemin, Linux vous propose deux commandes très pratiques : `pushd` et `popd`.

🔹 `pushd /etc` : aller dans un dossier et mémoriser l’actuel

```bash
pushd /etc
```

Cette commande vous permet de :

1. Aller dans le dossier `/etc`
2. Enregistrer automatiquement votre dossier actuel (par exemple `/tmp`) dans une pile de navigation

Une pile est une structure de données qui fonctionne en mode dernier entré, premier sorti (LIFO – Last In, First Out). C’est comme une pile d’assiettes : vous empilez, puis vous dépilez dans l’ordre inverse.

🔹 `popd` : revenir au dossier précédent

```
popd
```

Cette commande vous ramène automatiquement dans le dossier que vous aviez visité juste avant le `pushd`.

C’est la manière la plus rapide et propre de revenir en arrière sans avoir à retaper le chemin d’origine.

**Exemple concret d’utilisation de `pushd` et `popd` en situation réelle**

Imaginons que vous êtes en train de travailler sur la configuration de votre serveur **Apache2**, plus précisément dans le répertoire `/etc/apache2/sites-available`

Vous y modifiez un fichier de configuration, par exemple `000-default.conf`.

Et puis vous avez besoin de **consulter les logs** pour vérifier si Apache a bien pris en compte vos modifications. Ces fichiers se trouvent dans le répertoire `/var/log/`

Plutôt que de faire :

```bash
cd /var/log
# puis plus tard...
cd /etc/apache2/sites-available
```

Vous pouvez utiliser `pushd` et `popd` pour simplifier le tout :

- Vous êtes dans `/etc/apache2/sites-available`

 Tapez :

```bash
pushd /var/log
```

👉 Cela vous déplace dans `/var/log`

👉 Et **mémorise** automatiquement votre position précédente dans une pile (ici `/etc/apache2/sites-available`)

📝 Vous consultez les logs, par exemple :

```bash
cat apache2/error.log
```

- Une fois terminé, pour revenir à votre dossier Apache :

tapez :

```bash
popd
```

Et vous voilà de retour directement dans `/etc/apache2/sites-available`

Cette méthode est bien plus rapide et plus propre que de devoir retaper manuellement les chemins complets. Elle est idéale lorsque vous alternez fréquemment entre deux répertoires.

L’une des grandes forces de `pushd` et `popd`, c’est que **vous pouvez empiler plusieurs répertoires**, puis les **retrouver dans l’ordre inverse**, comme une pile d’assiettes.

- Empiler les couches :

```bash
pushd /var/www/html
pushd /etc/apache2/
pushd /var/log/
```

À ce stade, tu es dans**`/var/log/`**. Les anciens dossiers sont mémorisés dans la pile.

- Revenir en arrière :

```bash
popd   # Tu reviens dans /etc/apache2/
popd   # Tu reviens dans /var/www/html
```

----------------------------------



