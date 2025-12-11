# -*- coding: utf-8 -*-
import os
import subprocess
import random
import string
import shutil

# --- Variables de Configuración ---
PROJECT_ROOT = os.path.dirname(os.path.abspath(__file__))
DOCKER_BASE = os.path.join(PROJECT_ROOT, "docker", "nextcloud")
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

        # Crear .gitkeep si no existe (buena práctica)
        gitkeep = os.path.join(path, ".gitkeep")
        if not os.path.exists(gitkeep):
            open(gitkeep, "w").close()

        print(f"   + Verificado: {folder}")


def clear_folder(path):
    """Elimina el contenido de una carpeta sin borrar la carpeta en sí."""
    if not os.path.exists(path):
        return

    for item in os.listdir(path):
        item_path = os.path.join(path, item)
        if os.path.isdir(item_path):
            shutil.rmtree(item_path)
        else:
            os.remove(item_path)


def reset_nextcloud_permissions():
    print("\n🔄 Reiniciando estructura de Nextcloud...")

    paths = {
        "db": os.path.join(DOCKER_BASE, "db"),
        "config": os.path.join(DOCKER_BASE, "config"),
        "html": os.path.join(DOCKER_BASE, "html"),
        "data": os.path.join(DOCKER_BASE, "data")
    }

    # Asegurar que existen
    for p in paths.values():
        os.makedirs(p, exist_ok=True)

    # 1 — Limpieza de archivos (sin tocar .gitkeep)
    for key, path in paths.items():
        print(f"   - Limpiando {key}...")
        for item in os.listdir(path):
            if item == ".gitkeep":
                continue
            item_path = os.path.join(path, item)
            if os.path.isdir(item_path):
                shutil.rmtree(item_path)
            else:
                os.remove(item_path)

    # 2 — Permisos
    print("   - Asignando permisos...")

    def chown_safe(path, uid, gid):
        try:
            subprocess.run(["sudo", "chown", "-R", f"{uid}:{gid}", path], check=True)
        except:
            print(f"⚠ No se pudo aplicar permisos en {path}")

    chown_safe(paths["html"], 82, 82)
    chown_safe(paths["config"], 82, 82)
    chown_safe(paths["data"], 82, 82)
    chown_safe(paths["db"], 999, 999)

    print("   ✔ Reset completo.")


def generate_env_file():
    if os.path.exists(ENV_FILE):
        print("\n⚠️  El archivo .env ya existe.")
        resp = input("   ¿Quieres sobrescribirlo? (s/N): ")
        if resp.lower() != 's':
            print("   -> Conservando .env actual.")
            return

    print("\n🔐 Generando nuevo archivo .env...")

    nc_pass = generate_strong_password()
    ldap_pass = "ldappass"
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

    print("   ✔ .env generado")
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
        print("   ✔ Certificado generado")
    except Exception as e:
        print(f"[ERROR] Falló la generación del certificado: {e}")


def run_docker_compose():
    print("\n🐳 Lanzando Docker Compose...")
    try:
        subprocess.run(['docker', 'compose', '--env-file', '.env', 'up', '-d'], check=True)
        print("   ✔ Servicios levantados.")
    except subprocess.CalledProcessError:
        print("   ❌ ERROR al lanzar Docker Compose.")


def main():
    print("=" * 60)
    print(f"  ASIR LAB: Setup Script ({DOMAIN_NAME})")
    print("=" * 60)

    create_folders()
    reset_nextcloud_permissions()
    generate_env_file()
    generate_self_signed_cert()

    if input("\n¿Lanzar contenedores ahora? (s/N): ").lower() == 's':
        run_docker_compose()
    else:
        print("\nSetup finalizado. Ejecuta:")
        print("   docker compose --env-file .env up -d")


if __name__ == "__main__":
    main()

