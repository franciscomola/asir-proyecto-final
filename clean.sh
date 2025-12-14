#!/bin/bash

# Detener el script si hay errores
set -e

echo "=========================================="
echo "🧹  LIMPIEZA TOTAL DEL PROYECTO"
echo "=========================================="

# 1. Detener contenedores para liberar archivos
echo "🐳 [1/4] Deteniendo servicios Docker..."
docker compose down

# 2. Borrar datos generados (Requiere sudo porque son de Docker)
echo "🗑️  [2/4] Eliminando datos, bases de datos y configuraciones..."
sudo rm -rf docker/nextcloud/db/*
sudo rm -rf docker/nextcloud/config/*
sudo rm -rf docker/nextcloud/html/*
sudo rm -rf docker/nextcloud/data/*
sudo rm -rf docker/ldap/data/*
sudo rm -rf docker/ldap/config/*
sudo rm -rf docker/backup/repo/*
sudo rm -rf docker/backup/tmp/*
sudo rm -rf monitoring/grafana_data/*
sudo rm -rf monitoring/prometheus/data/*

# 3. Borrar archivos de entorno y certificados
echo "📄 [3/4] Eliminando .env, certificados SSL y logs..."
rm -f .env
rm -f docker/nginx/certs/*.key
rm -f docker/nginx/certs/*.crt
rm -rf script/logs/*

# 4. Restaurar los .gitkeep
# Esto asegura que Git mantenga la estructura de carpetas aunque estén vacías
echo "📁 [4/4] Restaurando archivos .gitkeep..."

# Función para crear .gitkeep asegurando que la carpeta existe
create_gitkeep() {
    mkdir -p "$1"
    touch "$1/.gitkeep"
}

create_gitkeep "docker/nextcloud/db"
create_gitkeep "docker/nextcloud/config"
create_gitkeep "docker/nextcloud/html"
create_gitkeep "docker/nextcloud/data"
create_gitkeep "docker/ldap/data"
create_gitkeep "docker/ldap/config"
create_gitkeep "docker/backup/repo"
create_gitkeep "monitoring/grafana_data"
create_gitkeep "monitoring/prometheus/data"

echo "=========================================="
echo "✅  LIMPIEZA COMPLETADA"
echo "    Ya puedes hacer 'git add .' y 'git push'"
echo "=========================================="
