# -*- coding: utf-8 -*-
import os
import subprocess
import random
import string
import sys

# --- CONFIGURACIÓN DEL PROYECTO ---
PROJECT_ROOT = os.path.dirname(os.path.abspath(__file__))
ENV_FILE = os.path.join(PROJECT_ROOT, '.env')
DOMAIN_NAME = "asir.local"

# Carpetas requeridas por el despliegue Docker
FOLDERS_TO_CREATE = [
    'docker/ldap/config', 'docker/ldap/data',
    'docker/nextcloud/config', 'docker/nextcloud/data', 'docker/nextcloud/html', 'docker/nextcloud/db',
    'docker/nginx/conf.d', 'docker/nginx/certs',
    'docker/backup/repo', 'docker/backup/tmp',
    'script/logs',
    'monitoring/grafana_data', 'monitoring/prometheus/data'
]

def generate_strong_password(length=16):
    """Genera una contraseña alfanumérica aleatoria."""
    chars = string.ascii_letters + string.digits
    return ''.join(random.choice(chars) for i in range(length))

def create_structure():
    """Crea la estructura de directorios y archivos .gitkeep necesarios."""
    print(" [INFO] Verificando estructura de directorios...")
    
    for folder in FOLDERS_TO_CREATE:
        path = os.path.join(PROJECT_ROOT, folder)
        os.makedirs(path, exist_ok=True)

        # Crear .gitkeep para persistencia en git
        gitkeep = os.path.join(path, ".gitkeep")
        if not os.path.exists(gitkeep):
            try:
                open(gitkeep, "w").close()
            except PermissionError:
                # Si la carpeta es de root (ej: despliegue previo), se ignora
                pass
    
    print(" [OK] Estructura verificada.")

def set_docker_permissions():
    """
    Asigna los permisos UID/GID requeridos por los contenedores.
    Requiere privilegios de sudo.
    """
    print(" [INFO] Ajustando permisos de volúmenes (requiere sudo)...")

    # Rutas base
    nc_base = os.path.join(PROJECT_ROOT, "docker", "nextcloud")
    
    # Mapeo de rutas y usuarios
    # www-data (Alpine) = 82:82
    # mysql = 999:999
    permissions_map = [
        (os.path.join(nc_base, "html"), "82:82"),
        (os.path.join(nc_base, "config"), "82:82"),
        (os.path.join(nc_base, "data"), "82:82"),
        (os.path.join(nc_base, "db"), "999:999")
    ]

    try:
        for path, ownership in permissions_map:
            if os.path.exists(path):
                subprocess.run(["sudo", "chown", "-R", ownership, path], check=False)
        print(" [OK] Permisos aplicados correctamente.")
    except Exception as e:
        print(f" [WARN] No se pudieron aplicar permisos automáticamente: {e}")

def generate_env_file():
    """Genera el archivo .env si no existe."""
    if os.path.exists(ENV_FILE):
        print(" [INFO] El archivo .env ya existe. Se omite la generación.")
        # Descomentar la siguiente línea si se desea preguntar interactivo
        # if input(" [?] ¿Sobrescribir? (s/N): ").lower() != 's': return
        return

    print(" [INFO] Generando nueva configuración de entorno (.env)...")

    nc_pass = generate_strong_password()
    
    env_content = f"""# --- CONFIGURACIÓN DE DESPLIEGUE ---
COMPOSE_PROJECT_NAME=asir_lab
TZ=Europe/Madrid
PROJECT_NAME=asir_lab
DOMAIN_NAME={DOMAIN_NAME}

# --- OPENLDAP ---
LDAP_ORGANISATION="ASIR LAB"
LDAP_DOMAIN={DOMAIN_NAME}
LDAP_BASE_DN=dc=asir,dc=local
LDAP_ADMIN_PASSWORD=ldappass
LDAP_HOST=asir_openldap

# --- PHPLDAPADMIN ---
PHPLDAPADMIN_HTTPS=false
PHPLDAPADMIN_LDAP_HOSTS=asir_openldap
PHP_LDAPADMIN_PORT=8080

# --- DATABASE ---
MYSQL_ROOT_PASSWORD={generate_strong_password()}
MYSQL_USER=nextcloud
MYSQL_PASSWORD={generate_strong_password()}
MYSQL_DATABASE=nextcloud

# --- NEXTCLOUD ---
NEXTCLOUD_VERSION=28.0
NEXTCLOUD_ADMIN_USER=ncadmin
NEXTCLOUD_ADMIN_PASSWORD={nc_pass}
NEXTCLOUD_TRUSTED_DOMAINS="lab.local {DOMAIN_NAME} localhost 127.0.0.1"
OVERWRITEHOST={DOMAIN_NAME}

# --- BACKUP ---
RESTIC_PASSWORD={generate_strong_password()}
RESTIC_REPOSITORY=./docker/backup/repo

# --- SERVIDOR WEB ---
HTTP_PORT=80
HTTPS_PORT=443

# --- MONITORIZACIÓN ---
GRAFANA_PORT=3000
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD={generate_strong_password()}
"""

    with open(ENV_FILE, 'w') as f:
        f.write(env_content)

    print(" [OK] Archivo .env generado.")
    print(f"      > Password Admin Nextcloud: {nc_pass}")

def generate_self_signed_cert():
    """Genera certificados SSL autofirmados para Nginx."""
    cert_dir = os.path.join(PROJECT_ROOT, 'docker/nginx/certs')
    key_file = os.path.join(cert_dir, 'nextcloud.key')
    crt_file = os.path.join(cert_dir, 'nextcloud.crt')

    if os.path.exists(key_file):
        print(" [INFO] Certificados SSL detectados. Se omite generación.")
        return

    print(" [INFO] Generando certificado SSL autofirmado...")
    try:
        subprocess.run([
            'openssl', 'req', '-x509', '-nodes', '-days', '365', '-newkey', 'rsa:2048',
            '-keyout', key_file,
            '-out', crt_file,
            '-subj', f"/C=ES/ST=Madrid/L=Madrid/O=ASIR Lab/CN={DOMAIN_NAME}"
        ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(" [OK] Certificado generado exitosamente.")
    except FileNotFoundError:
        print(" [ERROR] OpenSSL no encontrado en el sistema. Instale openssl.")
    except subprocess.CalledProcessError:
        print(" [ERROR] Falló la generación del certificado SSL.")

def main():
    print("-" * 60)
    print(f" SISTEMA DE DESPLIEGUE AUTOMATIZADO: {DOMAIN_NAME}")
    print("-" * 60)

    create_structure()
    generate_env_file()
    generate_self_signed_cert()
    set_docker_permissions()

    print("\n [INFO] Setup finalizado.")
    
    if input("\n [?] ¿Desea iniciar los contenedores ahora? (s/N): ").lower() == 's':
        try:
            print(" [INFO] Iniciando Docker Compose...")
            subprocess.run(['docker', 'compose', '--env-file', '.env', 'up', '-d'], check=True)
            print("\n [OK] Despliegue completado. Acceda a https://asir.local")
        except subprocess.CalledProcessError:
            print("\n [ERROR] Ocurrió un error al iniciar los contenedores.")
    else:
        print("      Ejecute manualmente: docker compose --env-file .env up -d")

if __name__ == "__main__":
    main()
