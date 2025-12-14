#!/bin/bash

# ======================================================
#  AUDITORÍA DE ESTADO DEL SISTEMA (Health Check)
# ======================================================

# Cargar variables de entorno ignorando errores si no existe
source .env 2>/dev/null || true

PROJECT_DIR="$(pwd)"
DATE=$(date +%Y%m%d_%H%M%S)
LOG_DIR="$PROJECT_DIR/script/logs"
LOG_FILE="$LOG_DIR/system_check_$DATE.log"
ERRORS=0 # Contador global de errores

mkdir -p "$LOG_DIR"

# Función para registrar en pantalla y archivo
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

log "==================================="
log "   REPORTE DE ESTADO: ASIR LAB"
log "   Fecha: $DATE"
log "==================================="
log ""

# ----------------------------------------
# 1. CONTENEDORES DOCKER
# ----------------------------------------
log "[1/5] Verificando contenedores activos..."

RUNNING=$(docker compose ps -q | wc -l)
EXPECTED=10  # Ajustado a tus 10 servicios reales

if [ "$RUNNING" -ge "$EXPECTED" ]; then
    log " [OK] Hay $RUNNING contenedores en ejecución."
else
    log " [WARN] ¡Atención! Solo hay $RUNNING contenedores activos (se esperaban ~$EXPECTED)."
    # No sumamos error crítico aquí, solo aviso
fi
# Tabla resumen
docker compose ps --format "table {{.Service}}\t{{.Status}}\t{{.Ports}}" | tee -a "$LOG_FILE"
log ""

# ----------------------------------------
# 2. BASE DE DATOS (MARIADB)
# ----------------------------------------
log "[2/5] Test de conexión MariaDB..."

if docker exec asir_mariadb mariadb-admin -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" ping > /dev/null 2>&1; then
    log " [OK] MariaDB está respondiendo (Ping exitoso)."
else
    log " [ERROR] No se puede conectar a MariaDB."
    ERRORS=$((ERRORS+1))
fi
log ""

# ----------------------------------------
# 3. DIRECTORIO ACTIVO (LDAP)
# ----------------------------------------
log "[3/5] Test de conexión LDAP..."

# Usamos credenciales de administrador para evitar rechazo por búsqueda anónima
BIND_DN="cn=admin,${LDAP_BASE_DN}"

if docker exec asir_openldap ldapsearch -x -D "$BIND_DN" -w "$LDAP_ADMIN_PASSWORD" -b "$LDAP_BASE_DN" -s base > /dev/null 2>&1; then
    log " [OK] LDAP responde consultas correctamente (Autenticado)."
else
    log " [ERROR] Falló la consulta a LDAP."
    ERRORS=$((ERRORS+1))
fi
log ""

# ----------------------------------------
# 4. NEXTCLOUD (WEB HTTPS)
# ----------------------------------------
log "[4/5] Test de respuesta Web (Nextcloud)..."

HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" "https://localhost/status.php")

if [ "$HTTP_CODE" == "200" ]; then
    log " [OK] Web responde correctamente (HTTPS 200)."
elif [ "$HTTP_CODE" == "000" ]; then
    log " [ERROR] No se pudo conectar con Nginx (¿Puerto caído?)."
    ERRORS=$((ERRORS+1))
else
    log " [WARN] Web responde con código inesperado: $HTTP_CODE"
    ERRORS=$((ERRORS+1))
fi
log ""

# ----------------------------------------
# 5. INTEGRIDAD DE ARCHIVOS
# ----------------------------------------
log "[5/5] Verificación de archivos críticos..."

FILES=(
    "docker/nextcloud/config/config.php"
    "docker/nginx/certs/nextcloud.crt"
    ".env"
)

for f in "${FILES[@]}"; do
    if [ -f "$PROJECT_DIR/$f" ]; then
        log " [OK] Encontrado: $f"
    else
        log " [ERROR] FALTA: $f"
        ERRORS=$((ERRORS+1))
    fi
done

log ""
log "==================================="
if [ $ERRORS -eq 0 ]; then
    log " ✅ ESTADO GLOBAL: SALUDABLE"
else
    log " ❌ ESTADO GLOBAL: CON ERRORES ($ERRORS)"
fi
log "==================================="
