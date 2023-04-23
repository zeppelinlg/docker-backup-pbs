FROM debian:bullseye-slim

ARG IMAGE_NAME="docker-backup-pbs"
ENV IMAGE_NAME=${IMAGE_NAME}

RUN apt-get update && apt-get install -y wget apt-transport-https ca-certificates curl gnupg lsb-release && rm -rf /var/lib/apt/lists/*

# Installation de Proxmox Backup Client
RUN wget https://enterprise.proxmox.com/debian/proxmox-release-bullseye.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-bullseye.gpg

RUN echo "deb http://download.proxmox.com/debian/pbs-client $(lsb_release -cs) main" > /etc/apt/sources.list.d/pbs.list
RUN apt-get update && apt-get install -y proxmox-backup-client && rm -rf /var/lib/apt/lists/*

# Installation de docker-ce-cli
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
RUN echo "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
RUN apt-get update && apt-get install -y docker-ce-cli && rm -rf /var/lib/apt/lists/*

VOLUME /tmp

# Copie du script de backup
COPY backup.sh /usr/local/bin/backup.sh

# Définition de la commande par défaut
ENTRYPOINT ["/usr/local/bin/backup.sh"]
CMD [ "backup" ]