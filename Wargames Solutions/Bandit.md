---
layout: default
title: Bandit
parent: Wargames Solutions
nav_order: 81

---

# Bandit

ssh -p 2220 bandit@bandit.labs.overthewire.org

### Level 0 > 1
Connexion : 

```ssh bandit0@bandit.labs.overthewire.org -p 2220```

**Solution** : ```cat readme```

Mot de passe bandit1 : ZjLjTmM6FvvyRnrb2rfNWOZOTa6ip5If

### Level 1 > 2

```ssh bandit1@bandit.labs.overthewire.org -p 2220```

Le niveau deux, est un peu tricky, le mot de passe se trouve dans un fichier avec comme nom (-), ce qui fait qu'on ne peut pas utilisé cat, du fait que cette dernière attend un paramètre après le dash (-).

Pour résoudre ce problème vous avez plusieurs approches, la première et la plus rapide, consiste à utiliser la commande ```more```

L'autre solution, c'est l'utilisation de la commande ```cat``` mais en indiquant le chemin absolu
```cat ./-```

**Solution** : ```cat ./-```

Mot de passe bandit2 : 263JGJPfgU6LtdEvgfWU1XP5yac29mFx

### Level 2 > 3

```ssh bandit2@bandit.labs.overthewire.org -p 2220```

Toujours dans la même la logique que le précédent, sauf que cette fois il y à des espaces qui rajoute une difficulté.

Si vous avez pratiquer un peu de scripting ou de programmation vous connaissez certainement le principe du double quote "" pour contenir un string. Eh bien on va utiliser cette méthode combiner à un chemin absolu pour résoudre le challenge.

**Solution** : ```cat ./"--spaces in this filename--"```

Si on veut travailler avec le chemin relatif (valable pour la précédente), on peut utiliser la commande ```cat -- "--spaces in this filename--"``` *On utilise le double dash ```--``` pour indiquier la fin d’options*

Mot de passe bandit3 : MNk8KNH3Usiio41PRUEoDFPqfxLPlSmx


### Level 3 > 4

```ssh bandit3@bandit.labs.overthewire.org -p 2220```

Dans ce challenge, nous avons affaire à un fichier caché dans le répertoire inhere.
Les fichiers cachés sont plus au moins fréquents sous Linux : tout nom de fichier qui commence par un . (point) n’apparaît pas dans un simple ls.
On les retrouve par exemple dans les répertoires personnels (comme .bashrc, .ssh/, .config/)...


Pour afficher les fichiers cachés, on utilise la commande ls avec le paramètre -a :

- ```-a``` = all files (inclut les fichiers cachés qui commencent par .)

**Solution** :

```ls -a inhere```

On remarque alors la présence d’un fichier caché nommé  ```...Hiding-From-You```

Il ne reste plus qu’à lire son contenu pour obtenir le mot de passe :

```cat inhere/...Hiding-From-You```

Mot de passe bandit4 : 2WmrDFRmJIq3IPxneAaMGhap0pFhF3NJ

### Level 4 > 5
```ssh bandit4@bandit.labs.overthewire.org -p 2220```

Le répertoire inhere contient plusieurs fichiers aux noms un peu particuliers.
Ils ne sont pas tous du même type : la majorité sont des fichiers binaires donc illisibles pour un être humain.
Cependant, un seul de ces fichiers est en ASCII text, donc lisible.

Bien sûr, vous pourriez tester manuellement avec :

 ```cat -- inhere/-file00 inhere/-file01 ...``` 
 
Cela fonctionnerait, mais ce serait fastidieux. Le but ici est justement de découvrir et d’utiliser de nouvelles commandes qui facilitent la vie.

**Solution** :

Pour résoudre ce challenge, on procède en deux étapes :

Identifier le fichier lisible par un humain avec :
```file ./inhere/*```

On remarque alors la présence d’un fichier de type ```ASCII text```, et il ne reste plus qu’à lire son contenu pour obtenir le mot de passe :

```cat -- ./inhere/-file07```

Mot de passe bandit5 : 4oQYVPkxZOOEOO5pTW81FB8j8lxXGUQw

### Level 5 > 6
```ssh bandit5@bandit.labs.overthewire.org -p 2220```

Le mot de passe du prochain niveau est caché quelque part dans le répertoire inhere, et pour ne pas nous faciliter la tâche il y a une vingtaine de répertoires, et chacun peut potentiellement abriter le fichier recherché.

Ce fameux fichier à trouver possède les caractéristiques suivantes :
- Il est lisible par un humain.
- Sa taille est exactement 1033 octets.
- Il n’est pas exécutable.

Vous avez envie de parcourir chaque dossier, ouvrir chaque fichier et vérifier manuellement ?
Avant de perdre au moins une heure de votre vie, essayez plutôt la commande :
```ls -lR inhere```

Vous réaliserez alors l’ampleur de la tâche... et pourquoi il faut absolument simplifier la recherche.


**Solution** :

Dans ce type de scénario, la commande find est votre meilleure alliée.
Elle permet de combiner plusieurs critères (type, taille, permissions…) pour cibler très rapidement le bon fichier selon les critères qu'on possède.
Voici la commande magique :

```find inhere -type f -size 1033c ! -executable```

**Décomposition**

- ```find inhere``` : parcourt récursivement tout le répertoire inhere.

- ```-type f``` : premier filtre → on ne garde que les fichiers (pas les répertoires).

- ```-size 1033c``` : second filtre → on ne garde que les fichiers dont la taille est exactement 1033 octets (c = bytes).

- ```! -executable``` : troisième filtre → on exclut tous les fichiers exécutables.

Une fois le fichier trouvé on exécute la commande : 

```cat inhere/maybehere07/.file2```

Mot de passe bandit6 : HWasnPhtq9AVKe0dmk45nxy20cvUa6EG

**## Level 6 > 7**

```ssh bandit6@bandit.labs.overthewire.org -p 2220```

Le mot de passe du prochain niveau n’est pas dans un dossier bien identifié cette fois-ci : il est caché quelque part sur tout le serveur.
Et pour corser l’affaire, le fichier à trouver n’est pas unique par son nom, mais par ses propriétés :

- Il est possédé par l’utilisateur bandit7.
- Il est possédé par le groupe bandit6.
- Sa taille est exactement 33 octets.

Autrement dit, si vous comptez fouiller chaque répertoire à la main avec ls, vous n'avez pas fini ta soirée. Il faut donc une méthode rapide et intelligente.

### Solution

On va réutiliser la commande ```find```, mais cette fois ci on va la combiner avec d'autres conditions (taille, propiétaire, groupe,...)

```find / -user bandit7 -group bandit6 -size 33c 2>/dev/null```

**Décomposition**

- ```find /``` : lance la recherche à partir de la racine /, donc sur tout le système.

- ```-user bandit7``` : filtre → fichiers appartenant à l’utilisateur bandit7.

- ```-group bandit6``` : filtre → fichiers appartenant au groupe bandit6.

- ```-size 33c``` : filtre → fichiers dont la taille est exactement 33 octets (c = bytes).

- ```2>/dev/null``` : redirige les erreurs (permissions refusées) vers /dev/null pour ne pas polluer l’affichage, elle affichera uniquement si le fichier est trouvé.

Une fois le fichier identifié, il suffit de lire son contenu avec cat :

```cat /var/lib/dpkg/info/bandit7.password```

Mot de passe bandit7 : morbNTDkSW6jIlUc0ymOdMaLnOlFVAaj


**## Level 7 > 8**

```ssh bandit7@bandit.labs.overthewire.org -p 2220```

Cette fois, pas besoin de fouiller tout le serveur, le challenge nous dit simplement :

👉 Le mot de passe du prochain niveau est stocké dans le fichier ```data.txt```, juste à côté du mot ```millionth```.

Autrement dit, quelque part dans le fichier ```data.txt```, une ligne contient ce mot-clé et juste après le mot ```millionth``` se trouve le précieux sésame.

### Solution

Ici, pas besoin de réinventer la roue. La commande grep est parfaite pour rechercher un mot précis dans un fichier.

```grep millionth .data.txt```

Mot de passe bandit8 : dfwvzFQi4mU0wfNbFOe9RoWskMLg7eEc

## Level 8 > 9

Cette fois, le challenge est un peu plus subtil.
Le mot de passe du prochain niveau est caché dans le fichier data.txt… mais il n’est pas marqué par un mot-clé particulier.

La consigne dit simplement :

Le mot de passe est la seule ligne du fichier qui apparaît une seule fois.
Toutes les autres lignes apparaissent plusieurs fois.

On doit donc :

1. Trier le fichier (pour que les doublons soient regroupés).
2. Identifier la ligne unique (qui apparaît une seule fois).

### Solution

C’est typiquement un cas où ```sort``` et ```uniq``` font le job, et on peut enchaîner les commandes grâce aux pipes (|) :

```sort data.txt | uniq -u```

- ```sort data.txt``` → trie les lignes du fichier par ordre alphabétique, ce qui regroupe les doublons.

- ```uniq -u``` → affiche uniquement les lignes uniques (celles qui apparaissent une seule fois).

Résultat : on obtient directement la ligne contenant le mot de passe.

Mot de passe bandit9 : 4CKMh1JI91bUIZZPXDqGanal4xvAg0JM

## Level 9 > 10

Dans ce challenge, le mot de passe est caché dans le fichier ```data.txt```, mais ce fichier contient surtout des données illisibles à l'humain.

Les seules indication donnée :

- Le mot de passe est dans une des rares chaînes lisibles par un humain.
- Cette chaîne est précédée par plusieurs caractères ```=```.

Donc, notre stratégie va être de filtrer uniquement ce qui est lisible et de chercher les ```=``` pour repérer la bonne ligne.


### Solution

Bien sûr, on est automatiquement tenté de lancer un ```cat data.txt``` ! Mais non, trop simple sinon ! Et surtout, la commande nous renvoie un tas de caractères illisibles : du charabia incompréhensible pour un humain.

La commande idéale ici est ```strings```, qui extrait toutes les séquences lisibles (ASCII) d’un fichier binaire.

Ensuite, on peut chaîner sa sortie avec la commande ```grep``` en utilisant un pipe (|), pour ne garder que les lignes contenant le caractère ```=``` en plusieurs fois.

```strings data.txt | grep "==="```

Mot de passe bandit10 : FGUW5ilLVJrxX9kMYMmlN4MgbpfMiqey


## Level 10 > 11

Le challenge nous dit que le mot de passe du prochain niveau est stocké dans le fichier ```data.txt```, mais cette fois-ci il ne s’agit pas de texte en clair ni de binaire incompréhensible.

👉 Le contenu du fichier est encodé en ```Base64```, qui est un système d’encodage qui transforme des données binaires en caractères lisibles

### Solution

La commande adaptée est base64, avec l’option ```-d``` (decode), qui permet de décoder une chaîne Base64 vers son contenu original.

```base64 -d data.txt```

Mot de passe bandit11 : dtR173fZKb0RRsDFSGsg2RWnpNVj3qRr

## Level 11 > 12

Cette fois, le mot de passe est caché dans le fichier data.txt, mais il n’est pas en clair ni en Base64.

👉 Le contenu a été transformé avec un chiffrement très simple : ROT13.

ROT13 est une forme très basique de chiffrement par substitution. dzChaque lettre est remplacée par celle qui se trouve 13 positions plus loin dans l’alphabet.

### Solution

Pour décoder ROT13 sous Linux, on peut utiliser la commande tr (translate), qui permet de remplacer des ensembles de caractères par d’autres.

```cat data.txt | tr 'A-Za-z' 'N-ZA-Mn-za-m'```

- ```cat data.txt``` → affiche le contenu du fichier.

- ```|``` → envoie ce contenu à la commande suivante.

- ```tr 'A-Za-z' 'N-ZA-Mn-za-m'``` → traduit chaque lettre majuscule et minuscule en la décalant de 13 positions.

Mot de passe bandit12 : 7x16WNeHIi5YkIhWsfFIqoognUTyj9Q4

## Level 12 > 13

Dans ce challenge, le mot de passe est stocké dans le fichier data.txt.
Mais attention, il ne s’agit pas d’un texte encodé comme en Base64 ou ROT13.

👉 Cette fois, data.txt est un hexdump d’un fichier qui a été compressé plusieurs fois (gzip, bzip2, tar, etc.). Il va donc falloir :

- Reconstituer le fichier original à partir de son hexdump.
- Décompresser étape par étape jusqu’à retrouver le fichier final qui contient le mot de passe.

### Solution

Comme on ne sait pas ce qui se trouve dans le fichier ```data.txt``` on va opter pour un travail propre dans le dossier /tmp a fin d'éviter de polluer l'environnement du serveur.

```mktemp -d```

Il nous retournera un dossier du type : ```/tmp/tmp.AvSiTzLTY8``` son nom peut être différent chez vous

```cd /tmp/tmp.AvSiTzLTY8```

Copier le fichier data.txt dans ce dossier :

```cp ~/data.txt .```

Convertir le hexdump en fichier binaire avec xxd -r :

```xxd -r data.txt > data.hex```

Identifier le type du fichier avec file, puis le décompresser avec l’outil approprié (gzip, bzip2, tar, etc.) :

```file data.bin```

On remarque que notre fichier ```data.bin``` est un fichier compressé avec gzip, on va le renommer :

```mv data.bin data.gz```

Et le décompresser avec la commande :

```gunzip data.gz```

On vérifie le type de notre nouveau fichier :
```file data```dddddddddddddd

