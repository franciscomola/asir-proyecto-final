#!/bin/bash
#Ususarios bases para pruebas.

set -e

echo "🔹 Esperando a que el contenedor LDAP esté listo..."
sleep 5

echo "🔹 Creando grupos base en LDAP..."
docker exec -i asir_openldap ldapadd -x -D "cn=admin,dc=asir,dc=local" -w ldappass <<EOF
dn: ou=people,dc=asir,dc=local
objectClass: organizationalUnit
ou: people

dn: ou=groups,dc=asir,dc=local
objectClass: organizationalUnit
ou: groups

dn: cn=admins,ou=groups,dc=asir,dc=local
objectClass: posixGroup
cn: admins
gidNumber: 5000

dn: cn=profesores,ou=groups,dc=asir,dc=local
objectClass: posixGroup
cn: profesores
gidNumber: 5001

dn: cn=alumnos,ou=groups,dc=asir,dc=local
objectClass: posixGroup
cn: alumnos
gidNumber: 5002
EOF

echo "✅ Grupos creados correctamente."

echo "🔹 Creando usuarios base en LDAP..."
docker exec -i asir_openldap ldapadd -x -D "cn=admin,dc=asir,dc=local" -w ldappass <<EOF
dn: uid=admin1,ou=people,dc=asir,dc=local
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

dn: uid=profe1,ou=people,dc=asir,dc=local
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

dn: uid=alumno1,ou=people,dc=asir,dc=local
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

echo "✅ Usuarios creados correctamente."

