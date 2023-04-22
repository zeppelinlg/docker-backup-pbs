# README

Ce projet vise à sauvegarder les volumes des conteneurs Docker en utilisant le client Proxmox Backup Server (PBS). Le Dockerfile fourni crée une image Docker avec le client PBS et le client Docker CE CLI installé. Un script de sauvegarde `backup.sh` est également fourni pour gérer la sauvegarde des volumes des conteneurs.

## Installation

1. Clonez le dépôt Git à l'aide de la commande suivante :
```
git clone https://github.com/votre-utilisateur/docker-backup-pbs.git
```

2. Accédez au répertoire cloné :
```
cd docker-backup-pbs
```

3. Créez l'image Docker à l'aide de la commande suivante :
```
docker build -t docker-backup-pbs .
```

## Utilisation

Le script de sauvegarde `backup.sh` utilise des variables d'environnement pour se connecter au serveur Proxmox Backup Server et sauvegarder les volumes des conteneurs Docker. Les variables d'environnement suivantes doivent être définies avant d'exécuter le script :

- `PBS_SERVER` : l'adresse IP ou le nom d'hôte du serveur Proxmox Backup Server
- `PBS_USER` : le nom d'utilisateur pour se connecter au serveur Proxmox Backup Server
- `PBS_PASSWORD` : le mot de passe pour se connecter au serveur Proxmox Backup Server
- `PBS_DATASTORE` : le nom du datastore sur le serveur Proxmox Backup Server
- `PBS_NAMESPACE` : le namespace pour stocker les sauvegardes sur le serveur Proxmox Backup Server

Le script de sauvegarde peut être exécuté de différentes manières :

1. Sauvegardez tous les volumes de tous les conteneurs en cours d'exécution :
```
docker run --rm \
-e PBS_SERVER="$PBS_SERVER" \
-e PBS_USER="$PBS_USER" \
-e PBS_PASSWORD="$PBS_PASSWORD" \
-e PBS_DATASTORE="$PBS_DATASTORE" \
-e PBS_NAMESPACE="$PBS_NAMESPACE" \
-v /var/lib/docker.sock:/var/lib/docker.sock
--name docker-backup-pbs \
docker-backup-pbs
```

2. Sauvegardez tous les volumes d'un conteneur spécifique :
```
docker run --rm \
-e PBS_SERVER="$PBS_SERVER" \
-e PBS_USER="$PBS_USER" \
-e PBS_PASSWORD="$PBS_PASSWORD" \
-e PBS_DATASTORE="$PBS_DATASTORE" \
-e PBS_NAMESPACE="$PBS_NAMESPACE" \
-v /var/lib/docker.sock:/var/lib/docker.sock
--name docker-backup-pbs \
docker-backup-pbs backupContainer CONTAINER_NAME
```
où `CONTAINER_NAME` est le nom du conteneur dont vous souhaitez sauvegarder les volumes.

3. Restaurez tous les volumes d'un conteneur spécifique à partir d'une sauvegarde spécifique :
```
docker run --rm \
-e PBS_SERVER="$PBS_SERVER" \
-e PBS_USER="$PBS_USER" \
-e PBS_PASSWORD="$PBS_PASSWORD" \
-e PBS_DATASTORE="$PBS_DATASTORE" \
-e PBS_NAMESPACE="$PBS_NAMESPACE" \
-v /var/lib/docker.sock:/var/lib/docker.sock
--name docker-backup-pbs \
docker-backup-pbs restoreContainer CONTAINER_NAME SNAPSHOT_NAME
```
où `CONTAINER_NAME` est le nom du conteneur à restaurer et `SNAPSHOT_NAME` est le nom de la sauvegarde à partir de laquelle vous souhaitez restaurer les volumes.

4. Exécutez une sauvegarde automatique quotidienne :
```
docker run --rm \
-e PBS_SERVER="$PBS_SERVER" \
-e PBS_USER="$PBS_USER" \
-e PBS_PASSWORD="$PBS_PASSWORD" \
-e PBS_DATASTORE="$PBS_DATASTORE" \
-e PBS_NAMESPACE="$PBS_NAMESPACE" \
-v /var/lib/docker.sock:/var/lib/docker.sock
--name docker-backup-pbs \
docker-backup-pbs autoBackupDaily
```

### docker-compose

Vous pouvez également utiliser `docker-compose` pour déployer le service de sauvegarde. Voici un exemple de fichier `docker-compose.yml` :

```
version: '3'
services:
  backup:
    image: docker-backup-pbs
    environment:
      - PBS_SERVER=192.168.1.100
      - PBS_USER=admin@pbs.local
      - PBS_PASSWORD=MyPassword
      - PBS_DATASTORE=local
      - PBS_NAMESPACE=docker-backups
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
```

Dans cet exemple, nous définissons un service `backup` qui utilise l'image `docker-backup-pbs`. Nous définissons également les variables d'environnement requises pour se connecter au serveur Proxmox Backup Server et stocker les sauvegardes. Enfin, nous montons les volumes `/var/run/docker.sock` et `/` pour permettre au script de sauvegarde d'accéder aux conteneurs.

## Licence

Ce projet est sous licence MIT. Veuillez consulter le fichier `LICENSE` pour plus d'informations.