#!/bin/bash

###############################################
# ASIR LAB - FULL BACKUP (EJECUTAR DESDE RAÍZ)
###############################################

set -e  # Parar si ocurre un error

# Cargar variables del .env que está en la raíz del proyecto
source .env

# Nombre de la red docker generada por docker compose
NETWORK="${COMPOSE_PROJECT_NAME}_asir_net"

# Directorio absoluto del proyecto
PROJECT_DIR="$(pwd)"

# Carpeta para este backup
DATE=$(date +%Y%m%d_%H%M%S)
TMP_DIR="$PROJECT_DIR/script/logs/fullbackup_$DATE"

mkdir -p "$TMP_DIR"

echo "=============================="
echo "  ASIR LAB - FULL BACKUP"
echo "  Fecha: $DATE"
echo "=============================="

################################
# 1. BACKUP BASE DE DATOS
################################
echo "[1/3] Exportando base de datos MariaDB..."

docker exec asir_mariadb /usr/bin/mysqldump -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" | tee "$TMP_DIR/db_backup.sql" > /dev/null


echo "✔ Base de datos exportada a $TMP_DIR/db_backup.sql"


################################
# 2. BACKUP LDAP (slapcat)
################################
echo "[2/3] Exportando LDAP (slapcat)..."

docker exec asir_openldap slapcat > "$TMP_DIR/ldap.ldif"

echo "✔ LDAP exportado a $TMP_DIR/ldap.ldif"



################################
# 3. SNAPSHOT RESTIC
################################
# Inicializar repositorio Restic si no existe
if [ ! -f "$PROJECT_DIR/docker/backup/repo/config" ]; then
    echo "[3/3] Inicializando repositorio Restic..."
    docker run --rm \
      -v "$PROJECT_DIR/docker/backup/repo:/mnt/restic_repo" \
      -e RESTIC_PASSWORD="$RESTIC_PASSWORD" \
      restic/restic init -r /mnt/restic_repo
fi
echo "[3/3] Creando snapshot con Restic..."

docker run --rm \
  --network "$NETWORK" \
  -v "$PROJECT_DIR/docker/backup/repo:/mnt/restic_repo" \
  -v "$PROJECT_DIR/docker/nextcloud/html:/data/html:ro" \
  -v "$PROJECT_DIR/docker/nextcloud/data:/data/ncdata:ro" \
  -v "$PROJECT_DIR/docker/nextcloud/config:/data/ncconfig:ro" \
  -v "$PROJECT_DIR/docker/ldap/data:/data/ldapdata:ro" \
  -v "$PROJECT_DIR/docker/ldap/config:/data/ldapconfig:ro" \
  -v "$TMP_DIR:/data/exports:ro" \
  -e RESTIC_PASSWORD="$RESTIC_PASSWORD" \
  restic/restic \
  -r /mnt/restic_repo \
  backup /data \
  --tag "full-backup" \
  --tag "$DATE"

echo "✔ Snapshot Restic creado con éxito"


################################
# FIN
################################
echo
echo "===================================="
echo " BACKUP COMPLETO REALIZADO CON ÉXITO"
echo " Carpeta temporal: $TMP_DIR"
echo "===================================="

