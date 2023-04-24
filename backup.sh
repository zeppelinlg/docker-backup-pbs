#!/bin/bash

# Check environment variables PBS_SERVER, PBS_USER, PBS_PASSWORD, PBS_DATASTORE and PBS_NAMESPACE
if [ -z "$PBS_SERVER" ]; then
    echo "The environment variable PBS_SERVER is not defined"
    exit 1
fi
if [ -z "$PBS_USER" ]; then
    echo "The environment variable PBS_USER is not defined"
    exit 1
fi
if [ -z "$PBS_PASSWORD" ]; then
    echo "The environment variable PBS_PASSWORD is not defined"
    exit 1
fi
if [ -z "$PBS_DATASTORE" ]; then
    echo "The environment variable PBS_DATASTORE is not defined"
    exit 1
fi
if [ -z "$PBS_NAMESPACE" ]; then
    echo "The environment variable PBS_NAMESPACE is not defined"
    exit 1
fi

# Set default value for LABEL_ONLY if not defined
if [ -z "$LABEL_ONLY" ]; then
    LABEL_ONLY="false"
fi

## Function to backup volumes of all running containers
function backup() {
    # Get list of all running containers
    if [ "$LABEL_ONLY" == "true" ]; then
        CONTAINERS=$(docker ps --format '{{.Names}}' --filter label=docker-backup-pbs=true)
    else
        CONTAINERS=$(docker ps --format '{{.Names}}')
    fi

    # For each container, get list of attached volumes and launch a new container for each volume
    for CONTAINER_NAME in $CONTAINERS; do

        # Exclude backup container based on image name
        CURRENT_IMAGE_NAME=$(docker inspect --format='{{.Config.Image}}' "$CONTAINER_NAME" | cut -d ":" -f 1)
        if [[ "$IMAGE_NAME" == "$CURRENT_IMAGE_NAME" ]]; then
            continue
        fi

        CONTAINER_ID=$(docker ps -aqf "name=$CONTAINER_NAME")
        VOLUMES=("$(docker inspect --format='{{range .Mounts}}{{.Name}} {{end}}' "$CONTAINER_ID" | sed -E 's/ +$//g' | sed -E 's/^ +//g')")
        if [ -z "${VOLUMES[*]}" ]; then
            continue
        fi

        VOLUMEARGS=""
        for VOLUME in "${VOLUMES[@]}"; do
            VOLUMEARGS="$VOLUMEARGS -v $VOLUME:/data/$VOLUME"
        done

        # Launch new container to backup each volume
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

## Function to restore a container's volume with Proxmox Backup Client
function restoreContainer() {
    # Get container name
    CONTAINER_NAME=$1

    # Get snapshot name
    SNAPSHOT_NAME=$2

    export PBS_REPOSITORY="${PBS_USER}@${PBS_SERVER}:${PBS_DATASTORE}"

    if [ -z "$SNAPSHOT_NAME" ]; then
        echo "Usage: $0 restoreContainer CONTAINER_NAME SNAPSHOT_NAME"
        proxmox-backup-client list --ns "$PBS_NAMESPACE"
        exit 1
    fi

    # Get volume names
    CONTAINER_ID=$(docker ps -aqf "name=$CONTAINER_NAME")
    VOLUMES=("$(docker inspect --format='{{range .Mounts}}{{.Name}} {{end}}' "$CONTAINER_ID" | sed -E 's/ +$//g' | sed -E 's/^ +//g')")

    # Pause container to avoid modifications during backup
    printf "Pausing container %s\n" "$CONTAINER_NAME"
    docker pause "$CONTAINER_NAME"

    for VOLUME in "${VOLUMES[@]}"; do
        printf "Restoring volume %s\n" "$VOLUME"
        proxmox-backup-client restore  --ns "$PBS_NAMESPACE" "$SNAPSHOT_NAME" "$VOLUME.pxar" "/data/$VOLUME"
    done

    # Unpause container
    printf "Resuming container %s\n" "$CONTAINER_NAME"
    docker unpause "$CONTAINER_NAME"
}

## Function to backup a container's volume with Proxmox Backup Client
function backupContainer() {
    # Get container name
    CONTAINER_NAME=$1
    shift

    # Get volume names
    VOLUMES=("$@")

    export PBS_REPOSITORY="${PBS_USER}@${PBS_SERVER}:${PBS_DATASTORE}"

    VOLUMESARGS=""
    for VOLUME in "${VOLUMES[@]}"; do
        VOLUMESARGS="$VOLUMESARGS $VOLUME.pxar:/data/$VOLUME"
    done

    # Pause container to avoid modifications during backup
    printf "Pausing container %s\n" "$CONTAINER_NAME"
    docker pause "$CONTAINER_NAME"

    # Backup with Proxmox Backup Client
    printf "Backing up container %s\n" "$CONTAINER_NAME"
    proxmox-backup-client backup $VOLUMESARGS --ns "$PBS_NAMESPACE" --backup-id "${CONTAINER_NAME}"

    # Unpause container
    printf "Resuming container %s\n" "$CONTAINER_NAME"
    docker unpause "$CONTAINER_NAME"
}

## Function to automatically backup volumes daily at a specified time
function autoBackupDaily() {
    TIME=${1:-"00:00"}
    while true; do
        backup
        # Wait until specified time
        NOW=$(date +%s)
        NEXT=$(date -d "tomorrow $TIME" +%s)
        SLEEP=$((NEXT-NOW))
        sleep "$SLEEP"
    done
}

# Check first argument and call corresponding function
if [ "$1" == "backup" ]; then
    backup
    elif [ "$1" == "backupContainer" ]; then
    backupContainer "$2" "${@:3}"
    elif [ "$1" == "restoreContainer" ]; then
    restoreContainer "$2" "$3"
    elif [ "$1" == "autoBackupDaily" ]; then
    autoBackupDaily "$2"
else
    echo "Usage: $0 backup|backupContainer|restoreContainer"
    exit 1
fi

