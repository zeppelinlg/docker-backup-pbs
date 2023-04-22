# README

Ce projet fournit un Dockerfile et un script de sauvegarde pour effectuer des sauvegardes de conteneurs Docker avec Proxmox Backup Server.

Le Dockerfile contient l'installation de Proxmox Backup Client et Docker CLI, ainsi que la configuration de l'environnement pour le script de sauvegarde.

Le script de sauvegarde permet de sauvegarder tous les conteneurs en cours d'exécution sur la machine hôte. Il utilise Proxmox Backup Client pour effectuer la sauvegarde et stocke les sauvegardes sur le serveur de sauvegarde Proxmox.

## Utilisation

Pour utiliser ce projet, vous devez d'abord construire l'image Docker à l'aide du Dockerfile fourni :

```bash
docker build -t docker-backup-pbs .
```

Ensuite, vous pouvez exécuter le script de sauvegarde en utilisant la commande suivante :

```bash
docker run -it --rm \
  -e PBS_SERVER=<serveur_proxmox_backup> \
  -e PBS_USER=<nom_utilisateur_proxmox_backup> \
  -e PBS_PASSWORD=<mot_de_passe_proxmox_backup> \
  -e PBS_DATASTORE=<stockage_proxmox_backup> \
  -e PBS_NAMESPACE=<namespace_proxmox_backup> \
  -e IMAGE_NAME=docker-backup-pbs \
  -v /var/lib/docker.sock:/var/lib/docker.sock \
  docker-backup-pbs backup
```

Vous devez remplacer les variables d'environnement par les valeurs appropriées pour votre environnement.

Il est également possible de sauvegarder un conteneur spécifique en utilisant la commande suivante :

```bash
docker run -it --rm \
  -e PBS_SERVER=<serveur_proxmox_backup> \
  -e PBS_USER=<nom_utilisateur_proxmox_backup> \
  -e PBS_PASSWORD=<mot_de_passe_proxmox_backup> \
  -e PBS_DATASTORE=<stockage_proxmox_backup> \
  -e PBS_NAMESPACE=<namespace_proxmox_backup> \
  -e IMAGE_NAME=docker-backup-pbs \
  -v /var/lib/docker.sock:/var/lib/docker.sock \
   docker-backup-pbs backupContainer <nom_conteneur>
```

Pour restaurer un conteneur à partir d'une sauvegarde, vous pouvez utiliser la commande suivante :

```bash
docker run -it --rm \
  -e PBS_SERVER=<serveur_proxmox_backup> \
  -e PBS_USER=<nom_utilisateur_proxmox_backup> \
  -e PBS_PASSWORD=<mot_de_passe_proxmox_backup> \
  -e PBS_DATASTORE=<stockage_proxmox_backup> \
  -e PBS_NAMESPACE=<namespace_proxmox_backup> \
  -e IMAGE_NAME=docker-backup-pbs \
  -v /var/lib/docker.sock:/var/lib/docker.sock \
  docker-backup-pbs restoreContainer <nom_conteneur> <nom_sauvegarde>
```

Enfin, vous pouvez planifier des sauvegardes automatiques à l'aide de la commande suivante :

```bash
docker run -d \
  -e PBS_SERVER=<serveur_proxmox_backup> \
  -e PBS_USER=<nom_utilisateur_proxmox_backup> \
  -e PBS_PASSWORD=<mot_de_passe_proxmox_backup> \
  -e PBS_DATASTORE=<stockage_proxmox_backup> \
  -e PBS_NAMESPACE=<namespace_proxmox_backup> \
  -e IMAGE_NAME=docker-backup-pbs \
  -v /var/lib/docker.sock:/var/lib/docker.sock \
  docker-backup-pbs autoBackupDaily <heure>
```

Cette commande exécutera automatiquement une sauvegarde quotidienne à l'heure spécifiée.
## Variables d'environnements

- `PBS_SERVER` : l'adresse IP ou le nom d'hôte du serveur Proxmox Backup Server
- `PBS_USER` : le nom d'utilisateur pour se connecter au serveur Proxmox Backup Server
- `PBS_PASSWORD` : le mot de passe pour se connecter au serveur Proxmox Backup Server
- `PBS_DATASTORE` : le nom du datastore sur le serveur Proxmox Backup Server
- `PBS_NAMESPACE` : le namespace pour stocker les sauvegardes sur le serveur Proxmox Backup Server


## Exemple avec docker-compose.yml

Voici un exemple de fichier docker-compose.yml pour exécuter automatiquement des sauvegardes quotidiennes à 2h du matin :

```yml
version: '3'

services:
  backup:
    image: docker-backup-pbs
    environment:
      - PBS_SERVER=<serveur_proxmox_backup>
      - PBS_USER=<nom_utilisateur_proxmox_backup>
      - PBS_PASSWORD=<mot_de_passe_proxmox_backup>
      - PBS_DATASTORE=<stockage_proxmox_backup>
      - PBS_NAMESPACE=<namespace_proxmox_backup>
      - IMAGE_NAME=docker-backup-pbs
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: autoBackupDaily "02:00"
```

## Conclusion

Ce projet fournit une solution simple pour effectuer des sauvegardes de conteneurs Docker avec Proxmox Backup Server. Il est facile à utiliser et peut être intégré dans des workflows existants à l'aide de Docker Compose.
