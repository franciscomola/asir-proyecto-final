#!/bin/bash

###############################################
# ASIR LAB - RESTAURACIÓN DE BACKUP
# Restaura un snapshot Restic a las rutas originales
# NOTA: Ejecutar desde la raíz del proyecto
###############################################

set -e

# Cargar variables del .env
source .env

# Directorio absoluto del proyecto
PROJECT_DIR="$(pwd)"

# Nombre de la red docker generada por docker compose
NETWORK="${COMPOSE_PROJECT_NAME}_asir_net"

# Carpeta temporal donde se restaurará el backup
RESTORE_DIR="$PROJECT_DIR/script/logs/restore_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESTORE_DIR"

echo "=============================="
echo "  ASIR LAB - RESTORE BACKUP"
echo "=============================="

# Listar snapshots disponibles
echo "[1/3] Snapshots disponibles:"
docker run --rm \
  --network "$NETWORK" \
  -v "$PROJECT_DIR/docker/backup/repo:/mnt/restic_repo" \
  -e RESTIC_PASSWORD="$RESTIC_PASSWORD" \
  restic/restic snapshots -r /mnt/restic_repo

echo
read -p "Introduce el ID del snapshot a restaurar: " SNAPSHOT_ID

# Restaurar el snapshot
echo "[2/3] Restaurando snapshot $SNAPSHOT_ID en $RESTORE_DIR ..."
docker run --rm \
  --network "$NETWORK" \
  -v "$PROJECT_DIR/docker/backup/repo:/mnt/restic_repo" \
  -v "$RESTORE_DIR:/data" \
  -e RESTIC_PASSWORD="$RESTIC_PASSWORD" \
  restic/restic restore "$SNAPSHOT_ID" --target /data -r /mnt/restic_repo

echo "✔ Snapshot restaurado en $RESTORE_DIR"

echo
echo "[3/3] Revisión manual de archivos restaurados"
echo "Los datos restaurados están en $RESTORE_DIR. Copia los directorios a sus ubicaciones originales:"
echo "  - Base de datos: db_backup.sql"
echo "  - LDAP: ldap.ldif"
echo "  - Nextcloud: html, data, config"
echo
echo "===================================="
echo " RESTAURACIÓN COMPLETA (PARCIAL / MANUAL)"
echo "===================================="

