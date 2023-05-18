# README

This project provides a Dockerfile and a backup script to perform Docker container backups with Proxmox Backup Server.

The Dockerfile contains the installation of Proxmox Backup Client and Docker CLI, as well as the environment configuration for the backup script.

The backup script allows for backing up all running containers on the host machine. It uses Proxmox Backup Client to perform the backup and stores the backups on the Proxmox backup server.

## Usage

To use this project, you first need to build the Docker image using the provided Dockerfile:

```bash
docker build -t docker-backup-pbs .
```

If you want change the image name, you have to pass IMAGE_NAME as build-arg

```bash
docker build -t other-name --build-arg IMAGE_NAME=other-name .
```

Then, you can run the backup script using the following command:

```bash
docker run -it --rm \
  -e PBS_SERVER=<proxmox_backup_server> \
  -e PBS_USER=<proxmox_backup_username> \
  -e PBS_PASSWORD=<proxmox_backup_password> \
  -e PBS_DATASTORE=<proxmox_backup_datastore> \
  -e PBS_NAMESPACE=<proxmox_backup_namespace> \
  -e STORAGE_TYPE=<storage_type> # optional default is 'volume' \
  -e LABEL_ONLY=<label_only> # optional default is 'false' \
  -v /var/lib/docker.sock:/var/lib/docker.sock \
  -v /:/host:ro # optional for bind mounts \  
  docker-backup-pbs backup
```

You need to replace the environment variables with the appropriate values for your environment.

To restore a container from a backup, you can use the following command:

```bash
docker run -it --rm \
  -e PBS_SERVER=<proxmox_backup_server> \
  -e PBS_USER=<proxmox_backup_username> \
  -e PBS_PASSWORD=<proxmox_backup_password> \
  -e PBS_DATASTORE=<proxmox_backup_datastore> \
  -e PBS_NAMESPACE=<proxmox_backup_namespace> \
  -v /var/lib/docker.sock:/var/lib/docker.sock \
  -v /:/host # optional for bind mounts \  
  docker-backup-pbs restoreSnapshot <container_name> <backup_name>
```

Finally, you can schedule automatic backups using the following command:

```bash
docker run -d \
  -e PBS_SERVER=<proxmox_backup_server> \
  -e PBS_USER=<proxmox_backup_username> \
  -e PBS_PASSWORD=<proxmox_backup_password> \
  -e PBS_DATASTORE=<proxmox_backup_datastore> \
  -e PBS_NAMESPACE=<proxmox_backup_namespace> \
  -v /var/lib/docker.sock:/var/lib/docker.sock \
  docker-backup-pbs autoBackupDaily <time>
```

This command will automatically run a daily backup at the specified time.

## Environment Variables

- `PBS_SERVER`: the IP address or hostname of the Proxmox Backup Server
- `PBS_USER`: the username to connect to the Proxmox Backup Server
- `PBS_PASSWORD`: the password to connect to the Proxmox Backup Server
- `PBS_DATASTORE`: the name of the datastore on the Proxmox Backup Server
- `PBS_NAMESPACE`: the namespace to store the backups on the Proxmox Backup Server
- `LABEL_ONLY`: if set to `true`, the backup script will only backup containers with the label `docker-backup-pbs=true`
- `STORAGE_TYPE`: Take 'all', 'volume' or 'bind' as value. If set to 'all', all volumes and bind mounts will be backed up. If set to 'volume', only volumes will be backed up. If set to 'bind', only bind mounts will be backed up. Default is 'volume'.

## Example with docker-compose.yml

Here is an example docker-compose.yml file to automatically run daily backups at 2am:

```yml
version: '3'

services:
  backup:
    image: docker-backup-pbs
    environment:
      - PBS_SERVER=<proxmox_backup_server>
      - PBS_USER=<proxmox_backup_username>
      - PBS_PASSWORD=<proxmox_backup_password>
      - PBS_DATASTORE=<proxmox_backup_datastore>
      - PBS_NAMESPACE=<proxmox_backup_namespace>
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: autoBackupDaily "02:00"
```

## Conclusion

This project provides a simple solution for performing Docker container backups with Proxmox Backup Server. It is easy to use and can be integrated into existing workflows using Docker Compose.
