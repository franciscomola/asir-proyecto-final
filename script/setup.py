#!/usr/bin/env python3
import os

# Directorios base
dirs = [
    "docker/backup/repo",
    "docker/backup/tmp",
    "docker/backup/restore",
    "docker/ldap/bootstrap",
    "docker/nextcloud/html",
    "docker/nextcloud/db",
    "logs",
    "script"
]

print("[SETUP] Inicializando estructura del proyecto...")

for d in dirs:
    os.makedirs(d, exist_ok=True)
    print(f"  ✔ {d} creado")

# Crear archivos vacíos si no existen
open("docker-compose.yml", "a").close()
open(".env", "a").close()

# Dar permisos a los scripts
os.system("chmod +x script/*.sh || true")

print("\n[SETUP] Estructura creada correctamente.")
print("Ahora puedes ejecutar:")
print("  docker compose up -d")
print("y luego:")
print("  ./script/backup.sh")

