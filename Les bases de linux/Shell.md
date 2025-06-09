---
layout: default
title: Shell
parent: Les bases de Linux
nav_order: 30

---

# Shell

Changer /bin/sh vers /bin/bash implique de modifier le shell par défaut utilisé pour l'exécution des scripts qui commencent par #!/bin/sh. C'est une opération qui peut avoir des implications sur la compatibilité des scripts, car bash est plus riche en fonctionnalités que sh (qui est souvent un lien symbolique vers Dash sur Debian/Ubuntu, un shell plus léger et POSIX-compliant).

Changer /bin/sh vers /bin/bash implique de modifier le shell par défaut utilisé pour l'exécution des scripts qui commencent par #!/bin/sh. C'est une opération qui peut avoir des implications sur la compatibilité des scripts, car bash est plus riche en fonctionnalités que sh (qui est souvent un lien symbolique vers Dash sur Debian/Ubuntu, un shell plus léger et POSIX-compliant).

Voici les méthodes pour effectuer ce changement, avec leurs avantages et inconvénients.
1. Changer le shell de l'utilisateur par défaut

C'est la méthode la plus courante pour changer le shell interactif d'un utilisateur.
Méthode 1: Utiliser chsh (change shell)

C'est la méthode recommandée pour modifier le shell de connexion d'un utilisateur.

1 - Ouvrez un terminal.

2 - Exécutez la commande suivante : 

``` bash
chsh -s /bin/bash
```

Si vous voulez changer le shell d'un autre utilisateur (vous devez être root ou utiliser sudo) : 