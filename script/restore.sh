#!/bin/bash
set -e

# --- VERIFICACIONES PREVIAS ---
# Verificar que se ejecuta como root (necesario para chown)
if [ "$EUID" -ne 0 ]; then
  echo " [ERROR] Este script debe ejecutarse con sudo."
  exit 1
fi

# Cargar variables del .env
if [ -f .env ]; then
    source .env
else
    echo " [ERROR] No se encuentra el archivo .env."
    exit 1
fi

PROJECT_DIR="$(pwd)"
RESTORE_DIR="$PROJECT_DIR/script/logs/restore_tmp_$(date +%Y%m%d_%H%M%S)"

echo "=========================================="
echo " RESTAURACIÓN DE SISTEMA (Restic)"
echo "=========================================="

# ----------------------------------------
# 1. SELECCIÓN DE SNAPSHOT
# ----------------------------------------
echo " [1/6] Listando copias de seguridad disponibles..."
docker run --rm \
  -v "$PROJECT_DIR/docker/backup/repo:/mnt/restic_repo" \
  -e RESTIC_PASSWORD="$RESTIC_PASSWORD" \
  restic/restic snapshots -r /mnt/restic_repo

echo ""
read -p " >> Introduce el ID del Snapshot a restaurar: " SNAPSHOT_ID
echo ""

if [ -z "$SNAPSHOT_ID" ]; then
    echo " [ERROR] ID no válido."
    exit 1
fi

# ----------------------------------------
# 2. EXTRACCIÓN DE DATOS
# ----------------------------------------
mkdir -p "$RESTORE_DIR"
echo " [2/6] Descargando snapshot $SNAPSHOT_ID en carpeta temporal..."

docker run --rm \
  -v "$PROJECT_DIR/docker/backup/repo:/mnt/restic_repo" \
  -v "$RESTORE_DIR:/data" \
  -e RESTIC_PASSWORD="$RESTIC_PASSWORD" \
  restic/restic restore "$SNAPSHOT_ID" --target /data -r /mnt/restic_repo

echo " [OK] Datos extraídos correctamente."

# ----------------------------------------
# 3. PARADA DE SERVICIOS
# ----------------------------------------
echo " [3/6] Deteniendo servicios..."
docker compose down

echo " [INFO] Esperando 5s para liberar archivos (WSL)..."
sleep 5

# ----------------------------------------
# 4. RESTAURACIÓN DE FICHEROS
# ----------------------------------------
echo " [4/6] Reemplazando archivos del sistema..."

# Función para limpiar y copiar
restore_folder() {
    local target="$1"
    local source="$2"
    
    # Vaciar destino
    if [ -d "$target" ]; then
        rm -rf "${target:?}"/*
    else
        mkdir -p "$target"
    fi
    
    # Copiar contenido
    cp -r "$source/." "$target/"
}

# Restaurar Nextcloud
restore_folder "$PROJECT_DIR/docker/nextcloud/html"   "$RESTORE_DIR/data/html"
restore_folder "$PROJECT_DIR/docker/nextcloud/data"   "$RESTORE_DIR/data/ncdata"
restore_folder "$PROJECT_DIR/docker/nextcloud/config" "$RESTORE_DIR/data/ncconfig"

# Restaurar LDAP
restore_folder "$PROJECT_DIR/docker/ldap/data"   "$RESTORE_DIR/data/ldapdata"
restore_folder "$PROJECT_DIR/docker/ldap/config" "$RESTORE_DIR/data/ldapconfig"

# CORRECCIÓN DE PERMISOS (Vital para que arranque)
echo " [INFO] Corrigiendo permisos de propietario..."
chown -R 82:82 "$PROJECT_DIR/docker/nextcloud"  # www-data (Alpine)
chown -R 999:999 "$PROJECT_DIR/docker/nextcloud/db" # MariaDB

echo " [OK] Archivos restaurados y permisos aplicados."

# ----------------------------------------
# 5. RESTAURACIÓN DE BASE DE DATOS
# ----------------------------------------
echo " [5/6] Importando base de datos..."

# Arrancamos solo la DB
docker compose up -d db
echo " [INFO] Esperando arranque de MariaDB (15s)..."
sleep 15

SQL_FILE="$RESTORE_DIR/data/exports/nextcloud-db.sql"
# Nota: Si tu backup anterior usaba otro nombre (ej: db_backup.sql), el script lo busca:
if [ ! -f "$SQL_FILE" ]; then
    SQL_FILE="$RESTORE_DIR/data/exports/db_backup.sql"
fi

if [ -f "$SQL_FILE" ]; then
    cat "$SQL_FILE" | docker exec -i asir_mariadb mariadb -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"
    echo " [OK] Base de datos importada."
else
    echo " [WARN] No se encontró archivo SQL en el backup. Se omite importación DB."
fi

# ----------------------------------------
# 6. ARRANQUE FINAL
# ----------------------------------------
echo " [6/6] Iniciando resto de servicios..."
docker compose up -d

# Limpieza temporal (Opcional, descomentar si quieres ahorrar espacio)
# rm -rf "$RESTORE_DIR"

echo "=========================================="
echo " [OK] RESTAURACIÓN COMPLETADA"
echo "=========================================="
