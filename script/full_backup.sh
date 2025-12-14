#!/bin/bash
set -e

# Configuración del entorno
if [ -f .env ]; then
    source .env
else
    echo " [ERROR] No se encuentra el archivo .env en la raíz."
    exit 1
fi

PROJECT_DIR="$(pwd)"
DATE=$(date +%Y%m%d_%H%M%S)
TMP_DIR="$PROJECT_DIR/script/logs/backup_tmp_$DATE"

# Crear directorio temporal para volcados
mkdir -p "$TMP_DIR"

echo "=========================================="
echo " COPIA DE SEGURIDAD COMPLETA (Restic)"
echo " Fecha: $DATE"
echo "=========================================="

# ----------------------------------------
# 1. EXTRACCIÓN DE BASES DE DATOS (HOT DUMP)
# ----------------------------------------
echo " [1/4] Exportando base de datos MariaDB..."

# Usamos mariadb-dump para asegurar consistencia
docker exec asir_mariadb mariadb-dump \
    -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" \
    --single-transaction --quick --lock-tables=false \
    > "$TMP_DIR/nextcloud-db.sql"

echo " [OK] Dump SQL generado."

# ----------------------------------------
# 2. EXTRACCIÓN DE LDAP
# ----------------------------------------
echo " [2/4] Exportando directorio LDAP..."

docker exec asir_openldap slapcat > "$TMP_DIR/ldap-backup.ldif"

echo " [OK] Exportación LDAP generada."

# ----------------------------------------
# 3. EJECUCIÓN DE RESTIC
# ----------------------------------------
# Inicializar repositorio si es la primera vez
if [ ! -f "$PROJECT_DIR/docker/backup/repo/config" ]; then
    echo " [INFO] Inicializando repositorio Restic por primera vez..."
    docker run --rm \
      -v "$PROJECT_DIR/docker/backup/repo:/mnt/restic_repo" \
      -e RESTIC_PASSWORD="$RESTIC_PASSWORD" \
      restic/restic init -r /mnt/restic_repo
fi

echo " [3/4] Enviando datos al repositorio cifrado..."

# Montamos volúmenes en solo lectura (:ro) para asegurar integridad
docker run --rm \
  --hostname docker-backup-host \
  -v "$PROJECT_DIR/docker/backup/repo:/mnt/restic_repo" \
  -v "$PROJECT_DIR/docker/nextcloud/html:/data/html:ro" \
  -v "$PROJECT_DIR/docker/nextcloud/data:/data/ncdata:ro" \
  -v "$PROJECT_DIR/docker/nextcloud/config:/data/ncconfig:ro" \
  -v "$PROJECT_DIR/docker/ldap/data:/data/ldapdata:ro" \
  -v "$PROJECT_DIR/docker/ldap/config:/data/ldapconfig:ro" \
  -v "$TMP_DIR:/data/exports:ro" \
  -e RESTIC_PASSWORD="$RESTIC_PASSWORD" \
  restic/restic -r /mnt/restic_repo backup /data \
  --tag "full-backup" \
  --tag "scheduled"

echo " [OK] Snapshot Restic creado."

# ----------------------------------------
# 4. LIMPIEZA
# ----------------------------------------
echo " [4/4] Limpiando archivos temporales..."
rm -rf "$TMP_DIR"

echo "=========================================="
echo " [OK] BACKUP FINALIZADO EXITOSAMENTE"
echo "=========================================="
