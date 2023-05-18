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

# Set default value for LABEL_ONLY if not defined
if [ -z "$LABEL_ONLY" ]; then
    LABEL_ONLY="false"
fi

# Set default value for STORAGE_TYPE if not defined
if [ -z "$STORAGE_TYPE" ]; then
    STORAGE_TYPE="volume"
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
        mapfile -t VOLUMES < <(docker inspect --format='{{range .Mounts}}{{.Type}}|{{if eq .Type "volume"}}{{.Name}}{{end}}{{if eq .Type "bind"}}{{.Source}}{{end}} {{end}}' "$CONTAINER_ID" | sed -E 's/ +$//g' | sed -E 's/^ +//g' | sed -E 's/ /\n/g')
        
        VOLUMEARGS=()
        for VOLUME in "${VOLUMES[@]}"; do
            if [ "$(echo "$VOLUME" | cut -d "|" -f 1)" == "volume" ] && { [ "$STORAGE_TYPE" == "volume" ] || [ "$STORAGE_TYPE" == "all" ]; }; then
                VOLUME_NAME="$(echo "$VOLUME" | cut -d "|" -f 2)"
                if [ "$(docker volume inspect --format '{{.Options.type}}' "$VOLUME_NAME")" == "nfs" ]; then
                    continue;
                fi
                VOLUMEARGS+=("-v $VOLUME_NAME:/data/$VOLUME_NAME")
            fi
            if [ "$(echo "$VOLUME" | cut -d "|" -f 1)" == "bind" ] && { [ "$STORAGE_TYPE" == "bind" ] || [ "$STORAGE_TYPE" == "all" ]; }; then
                VOLUME_SOURCE="$(echo "$VOLUME" | cut -d "|" -f 2)"
                VOLUME_NAME="$(echo "$VOLUME_SOURCE" | sed -E 's/\/+/_/g')"
                VOLUMEARGS+=("-v $VOLUME_SOURCE:/data/$VOLUME_NAME")
            fi
        done
        
        
        
        if [ -z "${VOLUMEARGS[*]}" ]; then
            continue
        fi
        
        # Launch new container to backup each volume
        docker run \
        --rm \
        ${VOLUMEARGS[*]} \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -e PBS_SERVER="$PBS_SERVER" \
        -e PBS_USER="$PBS_USER" \
        -e PBS_PASSWORD="$PBS_PASSWORD" \
        -e PBS_DATASTORE="$PBS_DATASTORE" \
        -e PBS_NAMESPACE="$PBS_NAMESPACE" \
        -e IMAGE_NAME="$IMAGE_NAME" \
        --name "backup-$CONTAINER_NAME" \
        "${IMAGE_NAME}" \
        backupContainer "$CONTAINER_NAME"
    done
}

## Function to restore a container's volume with Proxmox Backup Client
function restoreSnapshot() {
    # Get container name
    CONTAINER_NAME=$1
    
    # Get snapshot name
    SNAPSHOT_NAME=$2
    
    export PBS_REPOSITORY="${PBS_USER}@${PBS_SERVER}:${PBS_DATASTORE}"
    
    if [ -z "$SNAPSHOT_NAME" ]; then
        echo "Usage: $0 restoreSnapshot CONTAINER_NAME SNAPSHOT_NAME"
        local argsNS=()
        if [ -n "$PBS_NAMESPACE" ]; then
            argsNS=(--ns "${PBS_NAMESPACE}")
        fi
        proxmox-backup-client list "${argsNS[@]}"
        exit 1
    fi
    
    CONTAINER_ID=$(docker ps -aqf "name=$CONTAINER_NAME")
    mapfile -t VOLUMES < <(docker inspect --format='{{range .Mounts}}{{.Type}}|{{if eq .Type "volume"}}{{.Name}}{{end}}{{if eq .Type "bind"}}{{.Source}}{{end}} {{end}}' "$CONTAINER_ID" | sed -E 's/ +$//g' | sed -E 's/^ +//g' | sed -E 's/ /\n/g')
    
    VOLUMEARGS=()
    for VOLUME in "${VOLUMES[@]}"; do
        if [ "$(echo "$VOLUME" | cut -d "|" -f 1)" == "volume" ] && { [ "$STORAGE_TYPE" == "volume" ] || [ "$STORAGE_TYPE" == "all" ]; }; then
            VOLUME_NAME="$(echo "$VOLUME" | cut -d "|" -f 2)"
            if [ "$(docker volume inspect --format '{{.Options.type}}' "$VOLUME_NAME")" == "nfs" ]; then
                continue;
            fi
            VOLUMEARGS+=("-v $VOLUME_NAME:/data/$VOLUME_NAME")
        fi
        if [ "$(echo "$VOLUME" | cut -d "|" -f 1)" == "bind" ] && { [ "$STORAGE_TYPE" == "bind" ] || [ "$STORAGE_TYPE" == "all" ]; }; then
            VOLUME_SOURCE="$(echo "$VOLUME" | cut -d "|" -f 2)"
            VOLUME_NAME="$(echo "$VOLUME_SOURCE" | sed -E 's/\/+/_/g')"
            VOLUMEARGS+=("-v $VOLUME_SOURCE:/data/$VOLUME_NAME")
        fi
    done
    
    
    
    if [ -z "${VOLUMEARGS[*]}" ]; then
        exit 1
    fi
    
    # Launch new container to restore each volume
    docker run \
    --rm \
    ${VOLUMEARGS[*]} \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -e PBS_SERVER="$PBS_SERVER" \
    -e PBS_USER="$PBS_USER" \
    -e PBS_PASSWORD="$PBS_PASSWORD" \
    -e PBS_DATASTORE="$PBS_DATASTORE" \
    -e PBS_NAMESPACE="$PBS_NAMESPACE" \
    -e IMAGE_NAME="$IMAGE_NAME" \
    --name "restore-$CONTAINER_NAME" \
    "${IMAGE_NAME}" \
    restoreContainer "$CONTAINER_NAME" "$SNAPSHOT_NAME"
    
}

function restoreContainer() {
    # Get container name
    CONTAINER_NAME=$1
    
    # Get snapshot name
    SNAPSHOT_NAME=$2
    
    export PBS_REPOSITORY="${PBS_USER}@${PBS_SERVER}:${PBS_DATASTORE}"
    
    # Get volume destination from myself
    mapfile -t VOLUMES < <(docker inspect --format='{{range .Mounts}}{{.Destination}} {{end}}' "restore-$CONTAINER_NAME" | sed -E 's/ +$//g' | sed -E 's/^ +//g' | sed -E 's/ /\n/g')
    
    local argsNS=()
    if [ -n "$PBS_NAMESPACE" ]; then
        argsNS=(--ns "${PBS_NAMESPACE}")
    fi
    
    
    # Stop container before restore
    printf "Stop container %s\n" "$CONTAINER_NAME"
    docker stop "$CONTAINER_NAME"
    
    for VOLUME in "${VOLUMES[@]}"; do
        # Skip volume if the path does not begin with /data
        if [[ "$VOLUME" != /data* ]]; then
            continue
        fi
        VOLUME_NAME="$(echo "$VOLUME" | sed -E 's/^\/data\///g')"
        if [ "$VOLUME" == "/var/run/docker.sock" ] || [ "$VOLUME" == "/tmp" ]; then
            continue
        fi
        printf "Restoring volume %s\n" "$VOLUME"
        proxmox-backup-client restore  "${argsNS[@]}" "$SNAPSHOT_NAME" "$VOLUME_NAME.pxar" "$VOLUME"
    done
    
    # Start container
    printf "Start container %s\n" "$CONTAINER_NAME"
    docker start "$CONTAINER_NAME"
}

## Function to backup a container's volume with Proxmox Backup Client
function backupContainer() {
    # Get container name
    CONTAINER_NAME=$1
    
    export PBS_REPOSITORY="${PBS_USER}@${PBS_SERVER}:${PBS_DATASTORE}"
    
    # Get volume destination from myself
    mapfile -t VOLUMES < <(docker inspect --format='{{range .Mounts}}{{.Destination}} {{end}}' "backup-$CONTAINER_NAME" | sed -E 's/ +$//g' | sed -E 's/^ +//g' | sed -E 's/ /\n/g')
    
    VOLUMEARGS=()
    for VOLUME in "${VOLUMES[@]}"; do
        # Skip volume if the path does not begin with /data
        if [[ "$VOLUME" != /data* ]]; then
            continue
        fi
        VOLUME_NAME="$(echo "$VOLUME" | sed -E 's/^\/data\///g')"
        if [ "$VOLUME" == "/var/run/docker.sock" ] || [ "$VOLUME" == "/tmp" ]; then
            continue
        fi
        VOLUMEARGS+=("$VOLUME_NAME.pxar:$VOLUME")
    done
    
    local argsNS=()
    if [ -n "$PBS_NAMESPACE" ]; then
        argsNS=(--ns "${PBS_NAMESPACE}")
    fi
    
    # Pause container to avoid modifications during backup
    printf "Pausing container %s\n" "$CONTAINER_NAME"
    docker pause "$CONTAINER_NAME"
    
    # Backup with Proxmox Backup Client
    printf "Backing up container %s\n" "$CONTAINER_NAME"
    proxmox-backup-client backup ${VOLUMEARGS[*]} "${argsNS[@]}" --backup-id "${CONTAINER_NAME}"
    
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
    backupContainer "$2"
    elif [ "$1" == "restoreSnapshot" ]; then
    restoreSnapshot "$2" "$3"
    elif [ "$1" == "restoreContainer" ]; then
    restoreContainer "$2" "$3"
    elif [ "$1" == "autoBackupDaily" ]; then
    autoBackupDaily "$2"
else
    echo "Usage: $0 backup|backupContainer|restoreContainer"
    exit 1
fi

