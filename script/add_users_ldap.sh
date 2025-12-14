#!/bin/bash
# Script de población inicial de LDAP (OUs, Grupos y Usuarios)

# Intentar cargar variables de entorno
if [ -f .env ]; then
    source .env
else
    # Valores por defecto por si falla la carga
    LDAP_BASE_DN="dc=asir,dc=local"
    LDAP_ADMIN_PASSWORD="ldappass"
fi

# Definir el usuario administrador
BIND_DN="cn=admin,${LDAP_BASE_DN}"

echo "=========================================="
echo " POBLACIÓN DE LDAP: ${LDAP_BASE_DN}"
echo "=========================================="

echo " [INFO] Esperando 5s para asegurar que LDAP está listo..."
sleep 5

# ----------------------------------------
# 1. CREAR ESTRUCTURA (OUs y GRUPOS)
# ----------------------------------------
echo " [1/2] Creando Unidades Organizativas y Grupos..."

# Usamos -c para continuar si alguna entrada ya existe
docker exec -i asir_openldap ldapadd -x -D "$BIND_DN" -w "$LDAP_ADMIN_PASSWORD" -c <<EOF
dn: ou=people,${LDAP_BASE_DN}
objectClass: organizationalUnit
ou: people

dn: ou=groups,${LDAP_BASE_DN}
objectClass: organizationalUnit
ou: groups

dn: cn=admins,ou=groups,${LDAP_BASE_DN}
objectClass: posixGroup
cn: admins
gidNumber: 5000

dn: cn=profesores,ou=groups,${LDAP_BASE_DN}
objectClass: posixGroup
cn: profesores
gidNumber: 5001

dn: cn=alumnos,ou=groups,${LDAP_BASE_DN}
objectClass: posixGroup
cn: alumnos
gidNumber: 5002
EOF

echo " [OK] Estructura base procesada."

# ----------------------------------------
# 2. CREAR USUARIOS
# ----------------------------------------
echo " [2/2] Creando usuarios de prueba..."

docker exec -i asir_openldap ldapadd -x -D "$BIND_DN" -w "$LDAP_ADMIN_PASSWORD" -c <<EOF
dn: uid=admin1,ou=people,${LDAP_BASE_DN}
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
cn: Admin Uno
sn: Uno
uid: admin1
uidNumber: 1000
gidNumber: 5000
homeDirectory: /home/admin1
loginShell: /bin/bash
userPassword: 1234

dn: uid=profe1,ou=people,${LDAP_BASE_DN}
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
cn: Profesor Uno
sn: Uno
uid: profe1
uidNumber: 1001
gidNumber: 5001
homeDirectory: /home/profe1
loginShell: /bin/bash
userPassword: 1234

dn: uid=alumno1,ou=people,${LDAP_BASE_DN}
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
cn: Alumno Uno
sn: Uno
uid: alumno1
uidNumber: 1002
gidNumber: 5002
homeDirectory: /home/alumno1
loginShell: /bin/bash
userPassword: 1234
EOF

echo "=========================================="
echo " [OK] Usuarios añadidos correctamente."
echo "      Nota: Si viste errores 'Already exists', es normal."
echo "=========================================="
