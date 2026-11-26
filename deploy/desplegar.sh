#!/usr/bin/env bash
# =============================================================================
# Se ejecuta EN LA EC2 (lo invoca el job de despliegue por SSH).
# Uso: ./desplegar.sh <imagen:tag>
#   1. Prepara el servidor la primera vez (swap y plugin docker compose)
#   2. Descarga la nueva imagen de la app
#   3. Levanta/actualiza los servicios con docker compose
#   4. Verifica /api/health; si falla, regresa a la version anterior
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"
NUEVA="$1"

paso() { echo "==> $*"; }

# --- Contenedores de practicas anteriores que ocupaban el puerto 80 --------
sudo docker rm -f webapp-taskmanager webapp-container >/dev/null 2>&1 || true

# --- Espacio en disco ------------------------------------------------------
libre_mb() { df -Pm / | awk 'NR==2 {print $4}'; }

# Si el volumen EBS se agrando en la consola de AWS, se extiende la particion y el
# sistema de archivos (si no hubo cambio, estos comandos no hacen nada).
RAIZ=$(findmnt -n -o SOURCE /)
DISCO="/dev/$(lsblk -no PKNAME "$RAIZ" 2>/dev/null || true)"
PART=$(echo "$RAIZ" | grep -o '[0-9]*$')
if [ -b "$DISCO" ] && [ -n "$PART" ]; then
  sudo growpart "$DISCO" "$PART" >/dev/null 2>&1 && paso "Particion extendida" || true
  sudo resize2fs "$RAIZ" >/dev/null 2>&1 || sudo xfs_growfs / >/dev/null 2>&1 || true
fi

paso "Espacio libre antes de limpiar: $(libre_mb) MB"
# Imagenes y cache que no usa ningun contenedor (practicas anteriores, versiones viejas)
sudo docker container prune -f >/dev/null 2>&1 || true
sudo docker image prune -af >/dev/null 2>&1 || true
sudo docker builder prune -af >/dev/null 2>&1 || true
sudo apt-get clean >/dev/null 2>&1 || true
sudo journalctl --vacuum-size=50M >/dev/null 2>&1 || true
paso "Espacio libre despues de limpiar: $(libre_mb) MB"

# --- Memoria swap (la t3.micro solo tiene 1 GB de RAM) ---------------------
# 1 GB si el disco es chico; asi quedan ~2 GB para las imagenes de Docker
SWAP_MB=1024
if sudo swapon --show | grep -q '/swapfile'; then
  ACTUAL=$(( $(stat -c %s /swapfile) / 1048576 ))
  if [ "$ACTUAL" -gt "$SWAP_MB" ] && [ "$(libre_mb)" -lt 3000 ]; then
    paso "Reduciendo la swap de ${ACTUAL} MB a ${SWAP_MB} MB para liberar disco"
    sudo swapoff /swapfile && sudo rm -f /swapfile
  fi
fi
if ! sudo swapon --show | grep -q '/swapfile'; then
  paso "Creando ${SWAP_MB} MB de memoria swap"
  sudo fallocate -l ${SWAP_MB}M /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=$SWAP_MB
  sudo chmod 600 /swapfile && sudo mkswap /swapfile >/dev/null && sudo swapon /swapfile
  grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab >/dev/null
fi
paso "Espacio libre para las imagenes: $(libre_mb) MB"
df -h /

# --- Plugin docker compose ------------------------------------------------
if ! sudo docker compose version >/dev/null 2>&1; then
  paso "Instalando docker compose"
  sudo apt-get update -qq
  sudo apt-get install -y -qq docker-compose-v2 || sudo apt-get install -y -qq docker-compose-plugin || {
    sudo mkdir -p /usr/local/lib/docker/cli-plugins
    sudo curl -fsSL "https://github.com/docker/compose/releases/download/v2.29.7/docker-compose-linux-$(uname -m)" \
      -o /usr/local/lib/docker/cli-plugins/docker-compose
    sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
  }
fi
sudo docker compose version

ANTERIOR=$(grep '^APP_IMAGE=' .env.anterior 2>/dev/null | cut -d= -f2- || true)

paso "Descargando la nueva imagen $NUEVA"
sudo docker pull "$NUEVA"

paso "Levantando los servicios"
sudo docker compose pull --quiet otel-collector node-exporter openobserve
sudo docker compose up -d --remove-orphans

paso "Verificando /api/health"
for i in $(seq 1 30); do
  if curl -fsS http://localhost/api/health > /tmp/health.json 2>/dev/null; then
    echo "API arriba:"; cat /tmp/health.json; echo
    cp .env .env.anterior
    sudo docker image prune -f >/dev/null
    sudo docker compose ps
    exit 0
  fi
  sleep 2
done

echo "ERROR: la nueva version no respondio."
sudo docker compose logs --tail 60 app || true
if [ -n "$ANTERIOR" ]; then
  echo "Restaurando la version anterior: $ANTERIOR"
  sed -i "s|^APP_IMAGE=.*|APP_IMAGE=$ANTERIOR|" .env
  sudo docker compose up -d app
fi
exit 1
