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

**Décomposition logique**

- ```find inhere``` : parcourt récursivement tout le répertoire inhere.

- ```-type f``` : premier filtre → on ne garde que les fichiers (pas les répertoires).

- ```-size 1033c``` : second filtre → on ne garde que les fichiers dont la taille est exactement 1033 octets (c = bytes).

- ```! -executable``` : troisième filtre → on exclut tous les fichiers exécutables.

Une fois le fichier trouvé on exécute la commande : 

```cat inhere/maybehere07/.file2```

Mot de passe bandit6 : HWasnPhtq9AVKe0dmk45nxy20cvUa6EG