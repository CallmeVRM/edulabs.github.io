---
layout: default
title: Shell
parent: Les bases de Linux
nav_order: 30

---

# Shell

Changer `/bin/sh` vers `/bin/bash` implique de modifier le shell par défaut utilisé pour l'exécution des scripts qui commencent par `#!/bin/sh`. C'est une opération qui peut avoir des implications sur la compatibilité des scripts, car bash est plus riche en fonctionnalités que sh (qui est souvent un lien symbolique vers Dash sur Debian/Ubuntu, un shell plus léger et POSIX-compliant).

Changer `/bin/sh` vers `/bin/bash` implique de modifier le shell par défaut utilisé pour l'exécution des scripts qui commencent par `#!/bin/sh`. C'est une opération qui peut avoir des implications sur la compatibilité des scripts, car bash est plus riche en fonctionnalités que sh (qui est souvent un lien symbolique vers Dash sur Debian/Ubuntu, un shell plus léger et POSIX-compliant).

Voici les méthodes pour effectuer ce changement, avec leurs avantages et inconvénients.

#### Changer le shell de l'utilisateur par défaut

C'est la méthode la plus courante pour changer le shell interactif d'un utilisateur.
Méthode 1: Utiliser chsh (change shell)

C'est la méthode recommandée pour modifier le shell de connexion d'un utilisateur.

1 - Ouvrez un terminal.

2 - Exécutez la commande suivante : 

``` bash
chsh -s /bin/bash
```

Si vous voulez changer le shell d'un autre utilisateur (vous devez être root ou utiliser sudo) : 
``` bash
sudo chsh -s /bin/bash nom_utilisateur
```

3 - Vous devrez entrer votre mot de passe (ou celui de l'utilisateur nom_utilisateur).

4 - Pour que le changement prenne effet, déconnectez-vous et reconnectez-vous à votre session.

Vous pouvez bien évidemment changer le lien symbolique `/bin/sh`, mais cette méthode est fortement déconseillée sur les systèmes Debian/Ubuntu like, car elle peut casser des scripts système qui s'attendent à ce que `/bin/sh` pointe vers Dash pour des raisons de performance et de conformité POSIX.

Si vous voulez simplement que votre shell interactif soit Bash lorsque vous ouvrez un terminal, utilisez chsh -s /bin/bash. C'est la méthode la plus sûre et la plus appropriée pour la plupart des utilisateurs.

Si vous écrivez vos propres scripts, la meilleure pratique est de spécifier explicitement le shell que vous souhaitez utiliser dans le shebang :

- Pour un script Bash pur : `#!/bin/bash`

- Pour un script compatible POSIX (qui fonctionnera avec n'importe quel shell POSIX, y compris        

- Dash ou Bash en mode sh): `#!/bin/sh`

Évitez de changer le lien symbolique `/bin/sh` à moins d'avoir une raison impérieuse et de comprendre les risques associés.

En résumé, pour votre utilisation personnelle, `chsh` est la voie à suivre. Si l'erreur que vous rencontrez est due à un script qui ne s'exécute pas correctement avec sh alors qu'il a besoin de fonctionnalités Bash, la meilleure solution est de modifier le shebang de ce script en `#!/bin/bash`.