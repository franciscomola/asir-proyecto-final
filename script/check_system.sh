#!/bin/bash

######################################################
# ASIR LAB - CHECK SYSTEM (ANTES / DESPUÉS RESTORE)
# Realiza pruebas completas de:
#  - Estado de contenedores
#  - MariaDB
#  - LDAP
#  - Nextcloud
#  - Permisos y carpetas clave
######################################################

set -e

source .env
PROJECT_DIR="$(pwd)"
DATE=$(date +%Y%m%d_%H%M%S)
LOG_DIR="$PROJECT_DIR/script/logs"
LOG_FILE="$LOG_DIR/check_$DATE.log"

mkdir -p "$LOG_DIR"

echo "===================================" | tee "$LOG_FILE"
echo "     ASIR LAB - SYSTEM CHECK       " | tee -a "$LOG_FILE"
echo " Fecha: $DATE                       " | tee -a "$LOG_FILE"
echo "===================================" | tee -a "$LOG_FILE"
echo | tee -a "$LOG_FILE"

#############################################
# 1. ESTADO DE CONTENEDORES
#############################################
echo "[1/6] Comprobando contenedores Docker..." | tee -a "$LOG_FILE"
docker ps | tee -a "$LOG_FILE"
echo | tee -a "$LOG_FILE"

#############################################
# 2. COMPROBACIÓN MARIADB
#############################################
echo "[2/6] Probando MariaDB..." | tee -a "$LOG_FILE"

docker exec asir_mariadb mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SHOW DATABASES;" 2>&1 | tee -a "$LOG_FILE"

if [ $? -eq 0 ]; then
    echo "✔ Conexión a MariaDB OK" | tee -a "$LOG_FILE"
else
    echo "✘ Error al conectar a MariaDB" | tee -a "$LOG_FILE"
fi

echo | tee -a "$LOG_FILE"

#############################################
# 3. COMPROBACIÓN LDAP
#############################################
echo "[3/6] Probando LDAP..." | tee -a "$LOG_FILE"

docker exec asir_openldap ldapsearch -x -LLL -b "$LDAP_BASE_DN" "(objectClass=*)" dn 2>&1 | tee -a "$LOG_FILE"

if [ $? -eq 0 ]; then
    echo "✔ LDAP responde correctamente" | tee -a "$LOG_FILE"
else
    echo "✘ Error en la conexión a LDAP" | tee -a "$LOG_FILE"
fi

echo | tee -a "$LOG_FILE"

#############################################
# 4. NEXTCLOUD - TEST HTTP
#############################################
echo "[4/6] Probando acceso HTTP a Nextcloud..." | tee -a "$LOG_FILE"

NC_URL="http://localhost"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$NC_URL/status.php")

echo "Código HTTP: $HTTP_CODE" | tee -a "$LOG_FILE"

if [ "$HTTP_CODE" = "200" ]; then
    echo "✔ Nextcloud responde correctamente" | tee -a "$LOG_FILE"
else
    echo "✘ ERROR: Nextcloud no responde correctamente" | tee -a "$LOG_FILE"
fi

echo | tee -a "$LOG_FILE"

#############################################
# 5. PERMISOS DE DIRECTORIOS
#############################################
echo "[5/6] Comprobando permisos de carpetas..." | tee -a "$LOG_FILE"

dirs=(
    "docker/nextcloud/html"
    "docker/nextcloud/data"
    "docker/nextcloud/config"
    "docker/ldap/data"
    "docker/ldap/config"
)

for d in "${dirs[@]}"; do
    echo "- $d" | tee -a "$LOG_FILE"
    ls -ld "$PROJECT_DIR/$d" | tee -a "$LOG_FILE"
done

echo | tee -a "$LOG_FILE"

#############################################
# 6. COMPROBACIÓN DE ARCHIVOS CLAVE
#############################################
echo "[6/6] Comprobando archivos clave..." | tee -a "$LOG_FILE"

files=(
    "docker/nextcloud/config/config.php"
    "docker/ldap/config/cn=config.ldif"
)

for f in "${files[@]}"; do
    if [ -f "$PROJECT_DIR/$f" ]; then
        echo "✔ Encontrado: $f" | tee -a "$LOG_FILE"
    else
        echo "✘ NO encontrado: $f" | tee -a "$LOG_FILE"
    fi
done

echo | tee -a "$LOG_FILE"

echo "====================================" | tee -a "$LOG_FILE"
echo " CHECK COMPLETADO - LOG EN:"          | tee -a "$LOG_FILE"
echo " $LOG_FILE"                           | tee -a "$LOG_FILE"
echo "====================================" | tee -a "$LOG_FILE"

