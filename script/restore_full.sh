#!/bin/bash

#################################################
# ASIR LAB - RESTAURACIÓN COMPLETA DEL SISTEMA
# - Restaura Nextcloud (html, data, config)
# - Restaura LDAP (data, config)
# - Restaura MariaDB con db_backup.sql
# - Totalmente automatizado y seguro
#################################################

set -e

# Cargar variables del .env
source .env

PROJECT_DIR="$(pwd)"
NETWORK="${COMPOSE_PROJECT_NAME}_asir_net"

# Carpeta donde restauraremos los datos
RESTORE_DIR="$PROJECT_DIR/script/logs/restore_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESTORE_DIR"

echo "===================================="
echo "      ASIR LAB - RESTAURAR BACKUP"
echo "===================================="

#######################################
# 1. Mostrar snapshots disponibles
#######################################
echo "[1/6] Snapshots disponibles:"
docker run --rm \
  -v "$PROJECT_DIR/docker/backup/repo:/mnt/restic_repo" \
  -e RESTIC_PASSWORD="$RESTIC_PASSWORD" \
  restic/restic snapshots -r /mnt/restic_repo

echo
read -p "Introduce el ID del snapshot para restaurar: " SNAPSHOT_ID
echo

#######################################
# 2. Restaurar los datos del snapshot
#######################################
echo "[2/6] Restaurando snapshot en $RESTORE_DIR ..."

docker run --rm \
  -v "$PROJECT_DIR/docker/backup/repo:/mnt/restic_repo" \
  -v "$RESTORE_DIR:/data" \
  -e RESTIC_PASSWORD="$RESTIC_PASSWORD" \
  restic/restic restore "$SNAPSHOT_ID" --target /data -r /mnt/restic_repo

echo "✔ Snapshot restaurado."


#######################################
# 3. Parar contenedores
#######################################
echo "[3/6] Deteniendo servicios Docker..."
docker compose down
echo "✔ Servicios detenidos."


#######################################
# 4. Restaurar directorios
#######################################
echo "[4/6] Restaurando archivos del sistema..."

# Restaurar Nextcloud
rm -rf "$PROJECT_DIR/docker/nextcloud/html"/*
rm -rf "$PROJECT_DIR/docker/nextcloud/data"/*
rm -rf "$PROJECT_DIR/docker/nextcloud/config"/*

cp -r "$RESTORE_DIR/data/html/."      "$PROJECT_DIR/docker/nextcloud/html/"
cp -r "$RESTORE_DIR/data/ncdata/."    "$PROJECT_DIR/docker/nextcloud/data/"
cp -r "$RESTORE_DIR/data/ncconfig/."  "$PROJECT_DIR/docker/nextcloud/config/"

# Restaurar LDAP
rm -rf "$PROJECT_DIR/docker/ldap/data"/*
rm -rf "$PROJECT_DIR/docker/ldap/config"/*

cp -r "$RESTORE_DIR/data/ldapdata/."   "$PROJECT_DIR/docker/ldap/data/"
cp -r "$RESTORE_DIR/data/ldapconfig/." "$PROJECT_DIR/docker/ldap/config/"

echo "✔ Archivos restaurados."


#######################################
# 5. Restaurar MariaDB
#######################################
echo "[5/6] Restaurando base de datos MariaDB..."

# Levantar solo MariaDB para importar dump
docker compose up -d db
sleep 10

if [ ! -f "$RESTORE_DIR/data/exports/db_backup.sql" ]; then
    echo "ERROR: No se encuentra db_backup.sql en el snapshot restaurado."
    exit 1
fi

cat "$RESTORE_DIR/data/exports/db_backup.sql" | docker exec -i asir_mariadb \
    mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"

echo "✔ Base de datos restaurada."


#######################################
# 6. Levantar servicios completos
#######################################
echo "[6/6] Iniciando todos los servicios..."
docker compose up -d

echo
echo "===================================="
echo " RESTAURACIÓN COMPLETA FINALIZADA"
echo " Datos restaurados desde: $SNAPSHOT_ID"
echo " Carpeta base temporal: $RESTORE_DIR"
echo "===================================="

