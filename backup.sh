#!/bin/bash
# Vérification des variables d'environnement PBS_SERVER, PBS_USER, PBS_PASSWORD, PBS_DATASTORE et PBS_NAMESPACE
if [ -z "$PBS_SERVER" ]; then
    echo "La variable d'environnement PBS_SERVER n'est pas définie"
    exit 1
fi
if [ -z "$PBS_USER" ]; then
    echo "La variable d'environnement PBS_USER n'est pas définie"
    exit 1
fi
if [ -z "$PBS_PASSWORD" ]; then
    echo "La variable d'environnement PBS_PASSWORD n'est pas définie"
    exit 1
fi
if [ -z "$PBS_DATASTORE" ]; then
    echo "La variable d'environnement PBS_DATASTORE n'est pas définie"
    exit 1
fi
if [ -z "$PBS_NAMESPACE" ]; then
    echo "La variable d'environnement PBS_NAMESPACE n'est pas définie"
    exit 1
fi



## Fonction de backup des volumes de toutes les instances en cours d'exécution
function backup() {
    # Récupération de la liste de tous les conteneurs en cours d'exécution
    CONTAINERS=$(docker ps --format '{{.Names}}')
    
    # Pour chaque conteneur, récupérer la liste des volumes attachés et lancer un nouveau conteneur pour chaque volume
    for CONTAINER_NAME in $CONTAINERS; do
        
        # On exclut le conteneur de backup en fonction du nom de l'image
        CURRENT_IMAGE_NAME=$(docker inspect --format='{{.Config.Image}}' "$CONTAINER_NAME" | cut -d ":" -f 1)
        if [[ "$IMAGE_NAME" == "$CURRENT_IMAGE_NAME" ]]; then
            continue
        fi
        echo "$IMAGE_NAME != $CURRENT_IMAGE_NAME"
        
        CONTAINER_ID=$(docker ps -aqf "name=$CONTAINER_NAME")
        VOLUMES=("$(docker inspect --format='{{range .Mounts}}{{.Name}} {{end}}' "$CONTAINER_ID" | sed -E 's/ +$//g' | sed -E 's/^ +//g')")
        if [ -z "${VOLUMES[*]}" ]; then
            continue
        fi
        
        VOLUMEARGS=""
        for VOLUME in "${VOLUMES[@]}"; do
            VOLUMEARGS="$VOLUMEARGS -v $VOLUME:/data/$VOLUME"
        done
        
        
        docker run \
        --rm \
        ${VOLUMEARGS} \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -e PBS_SERVER="$PBS_SERVER" \
        -e PBS_USER="$PBS_USER" \
        -e PBS_PASSWORD="$PBS_PASSWORD" \
        -e PBS_DATASTORE="$PBS_DATASTORE" \
        -e PBS_NAMESPACE="$PBS_NAMESPACE" \
        -e IMAGE_NAME="$IMAGE_NAME" \
        --name "backup-$CONTAINER_NAME" \
        "${IMAGE_NAME}" \
        backupContainer "$CONTAINER_NAME" "${VOLUMES[*]}"
    done
}

function restoreContainer() {
    # Récupération du nom du conteneur
    CONTAINER_NAME=$1
    
    # Récupération du nom du snapshot
    SNAPSHOT_NAME=$2

    export PBS_REPOSITORY="${PBS_USER}@${PBS_SERVER}:${PBS_DATASTORE}"

    if [ -z "$SNAPSHOT_NAME" ]; then
        echo "Usage: $0 restoreContainer CONTAINER_NAME SNAPSHOT_NAME"
        proxmox-backup-client list --ns "$PBS_NAMESPACE"
        exit 1
    fi
    
    # Récupération du nom des volumes
    CONTAINER_ID=$(docker ps -aqf "name=$CONTAINER_NAME")
    VOLUMES=("$(docker inspect --format='{{range .Mounts}}{{.Name}} {{end}}' "$CONTAINER_ID" | sed -E 's/ +$//g' | sed -E 's/^ +//g')")
    
    
    # Pause du conteneur pour éviter les modifications pendant le backup
    printf "Pause du conteneur %s\n" "$CONTAINER_NAME"
    docker pause "$CONTAINER_NAME"
    
    for VOLUME in "${VOLUMES[@]}"; do
        printf "Restauration du volume %s\n" "$VOLUME"
        proxmox-backup-client restore  --ns "$PBS_NAMESPACE" "$SNAPSHOT_NAME" "$VOLUME.pxar" "/data/$VOLUME"
    done
    
    # Reprise du conteneur
    printf "Reprise du conteneur %s\n" "$CONTAINER_NAME"
    docker unpause "$CONTAINER_NAME"
}


## Fonction de backup d'un volume avec proxmox backup client
function backupContainer() {
    # Récupération du nom du conteneur
    CONTAINER_NAME=$1
    shift
    
    # Récupération du nom des volumes
    VOLUMES=("$@")
    
    export PBS_REPOSITORY="${PBS_USER}@${PBS_SERVER}:${PBS_DATASTORE}"
    
    VOLUMESARGS=""
    for VOLUME in "${VOLUMES[@]}"; do
        VOLUMESARGS="$VOLUMESARGS $VOLUME.pxar:/data/$VOLUME"
    done
    
    # Pause du conteneur pour éviter les modifications pendant le backup
    printf "Pause du conteneur %s\n" "$CONTAINER_NAME"
    docker pause "$CONTAINER_NAME"
    
    # Backup avec proxmox backup client
    printf "Backup du conteneur %s\n" "$CONTAINER_NAME"
    proxmox-backup-client backup $VOLUMESARGS --ns "$PBS_NAMESPACE" --backup-id "${CONTAINER_NAME}"
    
    # Reprise du conteneur
    printf "Reprise du conteneur %s\n" "$CONTAINER_NAME"
    docker unpause "$CONTAINER_NAME"
}

function autoBackupDaily() {
    while true; do
        backup
        sleep 1d
    done
}

if [ "$1" == "backup" ]; then
    backup
    elif [ "$1" == "backupContainer" ]; then
    backupContainer "$2" "${@:3}"
    elif [ "$1" == "restoreContainer" ]; then
    restoreContainer "$2" "$3"
    elif [ "$1" == "autoBackupDaily" ]; then
    autoBackupDaily
else
    echo "Usage: $0 backup|backupContainer|restoreContainer"
    exit 1
fi