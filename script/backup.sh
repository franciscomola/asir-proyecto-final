#!/bin/bash
# set -eux: Muestra cada comando antes de ejecutarlo.
# set -e: Se detiene inmediatamente si cualquier comando devuelve un código de error distinto de cero.
set -eux

echo "--- INICIO DE PROCESO DE BACKUP ---"

# --- 1. Variables ---
DB_DUMP_FILE="$BACKUP_PATH/nextcloud_db.sql"
DATE=$(date +%Y-%m-%d_%H-%M-%S)
SNAPSHOT_NAME="lab-backup-$DATE"

# --- 2. Preparar Directorio Temporal ---
mkdir -p $BACKUP_PATH
echo "CHECKPOINT 1: Directorio temporal creado."

# --- 3. Exportar la Base de Datos (MariaDB) ---
echo "3. Exportando la base de datos de Nextcloud..."
# Nota: La redirección 2> /dev/null suprime la advertencia de 'mysqldump' sobre la falta de contraseña en el CLI.
mysqldump -h $DB_HOST -u $DB_USER -p$DB_PASSWORD $DB_NAME 2> /dev/null > $DB_DUMP_FILE
echo "CHECKPOINT 2: MySQL Dump completado."

# --- 4. Inicializar Repositorio Restic (si es la primera vez) ---
if [ ! -f "$RESTIC_REPOSITORY/config" ]; then
    echo "4. Repositorio Restic no encontrado. Inicializando..."
    # Utilizamos 'restic init' que lee RESTIC_PASSWORD del entorno.
    restic init
    echo "    Repositorio inicializado."
fi
echo "CHECKPOINT 3: Repositorio listo."

# --- 5. Realizar Copia de Seguridad Restic ---
echo "5. Creando Snapshot Restic..."
# Los paths deben existir en el contenedor
restic backup \
    /var/www/html/config \
    /var/www/html/data \
    /etc/ldap/slapd.d \
    /var/lib/ldap \
    $DB_DUMP_FILE \
    --host $HOSTNAME \
    --tag $SNAPSHOT_NAME \
    --verbose
echo "CHECKPOINT 4: Snapshot creado."

# --- 6. Aplicar Política de Retención ---
echo "6. Aplicando política de retención (Prune)..."
restic forget --prune \
    --keep-daily 7 \
    --keep-weekly 4 \
    --keep-monthly 6
echo "CHECKPOINT 5: Prune completado."

# --- 7. Limpieza Temporal ---
rm -f $DB_DUMP_FILE

echo "--- PROCESO DE BACKUP FINALIZADO ---"
