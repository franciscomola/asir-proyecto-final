#!/usr/bin/env bash
set -euo pipefail

# ----------------------------
# full_backup.sh (portable)
# Usa: ./script/full_backup.sh
# ----------------------------

# ROOT = carpeta raíz del proyecto (un nivel arriba de script/)
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$ROOT_DIR/docker/backup/tmp"
LOGS_DIR="$ROOT_DIR/logs"
TIMESTAMP="$(date +%F_%H%M%S)"
LOGFILE="$LOGS_DIR/backup_${TIMESTAMP}.log"

mkdir -p "$TMP_DIR" "$LOGS_DIR"

log() {
  echo "[$(date +'%F %T')] $1" | tee -a "$LOGFILE"
}

# --- Cargar .env de forma segura (soporta espacios y comillas) ---
if [ -f "$ROOT_DIR/.env" ]; then
  log "Cargando variables desde .env"
  set -o allexport
  # shellcheck disable=SC1090
  source "$ROOT_DIR/.env"
  set +o allexport
else
  log "ERROR: No se encontró $ROOT_DIR/.env"
  exit 1
fi

# --- Variables por defecto (si no están en .env) ---
RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-./docker/backup/repo}"
MYSQL_USER="${MYSQL_USER:-nextcloud}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-nextcloudpass}"
MYSQL_DATABASE="${MYSQL_DATABASE:-nextcloud}"
MYSQL_HOST="${MYSQL_HOST:-db}"            # en tu docker-compose el servicio DB se llama "db"
LDAP_CONTAINER="${LDAP_CONTAINER:-asir_openldap}"   # nombre en tu compose: asir_openldap
DB_CONTAINER="${DB_CONTAINER:-asir_mariadb}"       # nombre del contenedor mariadb
# Nota: en tu docker-compose el servicio 'db' tiene container_name: asir_mariadb

# --- Detectar red docker relacionada al proyecto ---
log "Detectando red Docker del proyecto..."
DOCKER_NETWORK="$(docker network ls --format '{{.Name}}' | grep -E 'asar|asir|_asir_net$' || true)"
# Intentos de coincidencias frecuentes:
if [ -z "$DOCKER_NETWORK" ]; then
  # fallback: usar COMPOSE_PROJECT_NAME si existe
  if [ -n "${COMPOSE_PROJECT_NAME:-}" ]; then
    DOCKER_NETWORK="${COMPOSE_PROJECT_NAME}_asir_net"
  else
    DOCKER_NETWORK="asir_lab_asir_net"
  fi
  log "No se detectó red automática; usando: $DOCKER_NETWORK"
else
  # si grep devolvió varias líneas, usa la primera
  DOCKER_NETWORK="$(echo "$DOCKER_NETWORK" | head -n1)"
  log "Red detectada: $DOCKER_NETWORK"
fi

# --- Ajustes permisos (solo si es necesario) ---
log "Ajustando permisos (permiso amplio temporal para evitar fallos de escritura)..."
# No cambiamos owners, solo modos para evitar problemas en WSL2/Windows
chmod -R u+rwx,g+rwx,o-rwx "$ROOT_DIR/docker/backup" 2>/dev/null || true
chmod -R u+rwx,g+rwx,o-rwx "$ROOT_DIR/docker/ldap" 2>/dev/null || true
chmod -R u+rwx,g+rwx,o-rwx "$ROOT_DIR/docker/nextcloud" 2>/dev/null || true

# --- Iniciar log ---
log "INICIO BACKUP - proyecto: ${PROJECT_NAME:-(sin PROJECT_NAME)}"
log "Tmp: $TMP_DIR | Repo restic: $RESTIC_REPOSITORY"

# --- Asegurar repo Restic (init si hace falta) ---
log "Comprobando repositorio Restic..."
if ! docker run --rm -v "$ROOT_DIR/$RESTIC_REPOSITORY":/repo -e RESTIC_PASSWORD="$RESTIC_PASSWORD" restic/restic -r /repo snapshots >/dev/null 2>&1; then
  log "Repositorio Restic no inicializado. Inicializando..."
  docker run --rm -v "$ROOT_DIR/$RESTIC_REPOSITORY":/repo -e RESTIC_PASSWORD="$RESTIC_PASSWORD" restic/restic -r /repo init
  log "Repositorio Restic inicializado."
else
  log "Repositorio Restic ya inicializado."
fi

# --- 1) Dump MariaDB -> archivo dentro de TMP_DIR ---
log "Dumping MariaDB (mysqldump) a $TMP_DIR/mysql_${TIMESTAMP}.sql ..."
docker run --rm \
  --network="$DOCKER_NETWORK" \
  -v "$TMP_DIR":/tmp_dumps \
  -e MYSQL_PWD="$MYSQL_PASSWORD" \
  mariadb:11.8 \
  sh -c "exec mysqldump -h $MYSQL_HOST -u\"$MYSQL_USER\" \"$MYSQL_DATABASE\" > /tmp_dumps/mysql_${TIMESTAMP}.sql" \
  2>> "$LOGFILE"

if [ -f "$TMP_DIR/mysql_${TIMESTAMP}.sql" ]; then
  log "Dump MariaDB creado correctamente."
else
  log "ERROR: No se creó el dump de MariaDB. Revisa logs."
  exit 1
fi

# --- 2) Export LDAP (slapcat) -> archivo temporal en host ---
log "Exportando LDAP (slapcat) desde contenedor $LDAP_CONTAINER ..."
# stdout del docker exec la redirigimos directamente a archivo host
if docker exec "$LDAP_CONTAINER" sh -c "slapcat -v" > "$TMP_DIR/ldap_${TIMESTAMP}.ldif" 2>> "$LOGFILE"; then
  log "LDAP exportado a $TMP_DIR/ldap_${TIMESTAMP}.ldif"
else
  log "ERROR: fallo al ejecutar slapcat. Comprueba $LDAP_CONTAINER y revisa $LOGFILE"
  # no abortamos del todo; LDAP es importante pero permitimos seguir si no crítico
fi

# --- 3) Ejecutar restic backup (montando rutas de tu estructura) ---
log "Ejecutando restic para respaldar nextcloud, ldap y dumps..."
docker run --rm \
  -v "$ROOT_DIR/$RESTIC_REPOSITORY":/repo \
  -v "$ROOT_DIR/docker/nextcloud":/data/nextcloud:ro \
  -v "$ROOT_DIR/docker/ldap":/data/ldap:ro \
  -v "$TMP_DIR":/data/tmp:ro \
  -e RESTIC_PASSWORD="$RESTIC_PASSWORD" \
  restic/restic -r /repo backup \
    /data/nextcloud/config \
    /data/nextcloud/data \
    /data/ldap/config \
    /data/ldap/data \
    /data/tmp \
    --tag asir_backup --host asir-lab-host 2>&1 | tee -a "$LOGFILE"

log "Restic backup finalizado (si no hubo errores en log)."

# --- 4) Aplicar política de retención ---
log "Aplicando política de retención (keep 7 daily) ..."
docker run --rm -v "$ROOT_DIR/$RESTIC_REPOSITORY":/repo -e RESTIC_PASSWORD="$RESTIC_PASSWORD" restic/restic -r /repo forget --keep-daily 7 --prune 2>&1 | tee -a "$LOGFILE"

# --- 5) Limpieza: eliminar dumps temporales ---
log "Limpiando archivos temporales (dumps) ..."
rm -f "$TMP_DIR/mysql_${TIMESTAMP}.sql" "$TMP_DIR/ldap_${TIMESTAMP}.ldif" || true

log "BACKUP COMPLETADO ✅ - Revisa $LOGFILE para detalles."
log "Para comprobar snapshots: docker run --rm -v $(pwd)/$RESTIC_REPOSITORY:/repo -e RESTIC_PASSWORD=\$RESTIC_PASSWORD restic/restic -r /repo snapshots"

exit 0

