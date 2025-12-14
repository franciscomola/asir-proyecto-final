# ☁️ ASIR Lab: Nextcloud + LDAP + Backup System

Despliegue automatizado de una nube privada segura con autenticación centralizada y sistema de recuperación ante desastres.

## 🚀 Características

* **Infraestructura como Código:** Despliegue completo con Docker Compose.
* **Nextcloud:** Almacenamiento en nube privado.
* **OpenLDAP:** Gestión centralizada de usuarios y grupos.
* **Seguridad:** Nginx como Proxy Inverso con SSL/TLS (autofirmado) y cabeceras de seguridad.
* **Backup Profesional:** Sistema de copias incrementales y deduplicadas con **Restic**.
* **Monitorización:** Scripts de auditoría de salud del sistema.

## 📋 Requisitos

* Linux (Ubuntu/Debian recomendado o WSL2).
* Docker y Docker Compose.
* Python 3.

## 🛠️ Instalación Rápida

1.  **Clonar el repositorio:**
    ```bash
    git clone <URL_DEL_REPO>
    cd asir-proyecto-final
    ```

2.  **Ejecutar el asistente de instalación:**
    Este script crea la estructura de carpetas, genera contraseñas seguras en un archivo `.env` y certificados SSL.
    ```bash
    python3 setup.py
    ```

3.  **Configuración de DNS Local (Importante):**
    Para acceder usando el dominio `asir.local`, debes añadir la siguiente línea a tu archivo `hosts`:
    ```text
    127.0.0.1       asir.local
    ```
    * **Windows:** `C:\Windows\System32\drivers\etc\hosts` (Editar como Administrador)
    * **Linux/Mac:** `/etc/hosts` (Editar con sudo)

4.  **Acceder al sistema:**
    * Web: `https://asir.local` (Acepta el certificado de seguridad).
    * Credenciales: Ver archivo `.env` generado por el setup.

## ⚙️ Gestión y Scripts

El proyecto incluye herramientas de administración en la carpeta `script/`:

| Script | Descripción |
| :--- | :--- |
| `add_users_ldap.sh` | Puebla el directorio LDAP con usuarios y grupos de prueba. |
| `full_backup.sh` | Realiza un backup completo (BD + Archivos + LDAP) usando Restic. |
| `restore.sh` | **Restauración automática**. Recupera el sistema a un punto anterior. |
| `check_system.sh` | Auditoría completa del estado de los servicios. |

## 🛡️ Política de Backups

Los backups se almacenan en `docker/backup/repo`.
* Para realizar una copia manual: `./script/full_backup.sh`
* Para restaurar: `sudo ./script/restore.sh` (Requiere permisos de root para gestionar volúmenes).

## 🧹 Limpieza

Para reiniciar el entorno o limpiar antes de subir a git:
```bash
./clean.sh
