# -*- coding: utf-8 -*-
import os
import subprocess
import random
import string

# --- Variables de Configuración ---
PROJECT_ROOT = os.path.dirname(os.path.abspath(__file__))
DOCKER_COMPOSE_FILE = os.path.join(PROJECT_ROOT, 'docker-compose.yml')
ENV_FILE = os.path.join(PROJECT_ROOT, '.env')
DOMAIN_NAME = "asir.local"  # Tu dominio real

# --- Estructura de Carpetas ---
FOLDERS_TO_CREATE = [
    'docker/ldap/config', 'docker/ldap/data',
    'docker/nextcloud/config', 'docker/nextcloud/data', 'docker/nextcloud/html',
    'docker/nginx/conf.d', 'docker/nginx/certs',
    'docker/backup/repo', 'docker/backup/tmp',
    'logs'
]

# --- Funciones de Utilidad ---

def generate_strong_password(length=16):
    chars = string.ascii_letters + string.digits
    return ''.join(random.choice(chars) for i in range(length))

def create_folders():
    print("🛠️  Creando estructura de carpetas...")
    for folder in FOLDERS_TO_CREATE:
        path = os.path.join(PROJECT_ROOT, folder)
        os.makedirs(path, exist_ok=True)
        print(f"   + Verificado: {folder}")

def generate_env_file():
    if os.path.exists(ENV_FILE):
        print("\n⚠️  El archivo .env ya existe.")
        resp = input("   ¿Quieres sobrescribirlo? (s/N): ")
        if resp.lower() != 's':
            print("   -> Conservando .env actual.")
            return

    print("\n🔐 Generando nuevo archivo .env...")

    nc_pass = generate_strong_password()
    ldap_pass = generate_strong_password()
    db_root_pass = generate_strong_password()
    db_user_pass = generate_strong_password()
    restic_pass = generate_strong_password()
    grafana_pass = generate_strong_password()

    env_content = f"""# --- Proyecto ---
COMPOSE_PROJECT_NAME=asir_lab
TZ=Europe/Madrid
PROJECT_NAME=asir_lab
DOMAIN_NAME={DOMAIN_NAME}

# --- LDAP ---
LDAP_ORGANISATION="ASIR LAB"
LDAP_DOMAIN={DOMAIN_NAME}
LDAP_BASE_DN=dc=asir,dc=local
LDAP_ADMIN_PASSWORD={ldap_pass}
LDAP_HOST=asir_openldap

# --- phpLDAPadmin ---
PHPLDAPADMIN_HTTPS=false
PHPLDAPADMIN_LDAP_HOSTS=asir_openldap

# --- Base de datos ---
MYSQL_ROOT_PASSWORD={db_root_pass}
MYSQL_USER=nextcloud
MYSQL_PASSWORD={db_user_pass}
MYSQL_DATABASE=nextcloud

# --- Nextcloud ---
NEXTCLOUD_VERSION=28.0
NEXTCLOUD_ADMIN_USER=ncadmin
NEXTCLOUD_ADMIN_PASSWORD={nc_pass}
NEXTCLOUD_TRUSTED_DOMAINS="lab.local {DOMAIN_NAME} localhost 127.0.0.1"
OVERWRITEHOST={DOMAIN_NAME}

# --- Restic ---
RESTIC_PASSWORD={restic_pass}
RESTIC_REPOSITORY=./docker/backup/repo

# --- Puertos ---
HTTP_PORT=80
HTTPS_PORT=443
GRAFANA_PORT=3000
PHP_LDAPADMIN_PORT=8080

# --- Grafana ---
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD={grafana_pass}
"""

    with open(ENV_FILE, 'w') as f:
        f.write(env_content)

    print("   Archivo .env generado con éxito.")
    print(f"   Nextcloud Admin Password: {nc_pass}")
    print(f"   LDAP Admin Password: {ldap_pass}")

def generate_self_signed_cert():
    cert_path = os.path.join(PROJECT_ROOT, 'docker/nginx/certs')
    key_file = os.path.join(cert_path, 'nextcloud.key')
    crt_file = os.path.join(cert_path, 'nextcloud.crt')

    if os.path.exists(key_file):
        print("\n🔒 Certificado SSL ya existe. Omitiendo.")
        return

    print("\n🔒 Generando certificado SSL autofirmado...")

    try:
        subprocess.run([
            'openssl', 'req', '-x509', '-nodes', '-days', '365', '-newkey', 'rsa:2048',
            '-keyout', key_file,
            '-out', crt_file,
            '-subj', f"/C=ES/ST=Madrid/L=Madrid/O=ASIR Lab/CN={DOMAIN_NAME}"
        ], check=True)
        print("   Certificado generado.")
    except FileNotFoundError:
        print("[ERROR] No se encontró openssl.")
    except subprocess.CalledProcessError:
        print("[ERROR] Falló la generación del certificado.")

def run_docker_compose():
    print("\n🐳 Lanzando Docker Compose...")
    try:
        subprocess.run(['docker', 'compose', '--env-file', '.env', 'up', '-d'], check=True)
        print("   ✅ Servicios lanzados.")
    except subprocess.CalledProcessError:
        print("   ❌ ERROR al ejecutar Docker Compose.")

def main():
    print("=" * 60)
    print(f"  ASIR LAB: Setup Script ({DOMAIN_NAME})")
    print("=" * 60)

    create_folders()
    generate_env_file()
    generate_self_signed_cert()

    if input("\n¿Lanzar contenedores ahora? (s/N): ").lower() == 's':
        run_docker_compose()
    else:
        print("Setup finalizado. Ejecuta manualmente:")
        print("   docker compose --env-file .env up -d")

if __name__ == "__main__":
    main()

