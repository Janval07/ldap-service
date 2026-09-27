#!/bin/bash
set -e

echo "[init] Waiting for container startup to complete..."
while [ ! -f /container/run/state/startup-done ]; do
    sleep 1
done

echo "[init] Waiting for OpenLDAP ldapi socket to become ready..."
until ldapsearch -Y EXTERNAL -Q -H ldapi:/// -s base -b "cn=config" dn >/dev/null 2>&1; do
    sleep 1
done
echo "[init] OpenLDAP is ready."

# 1. Fresh volume: Load seed data in one pass if directory is empty
if ! ldapsearch -Y EXTERNAL -Q -H ldapi:/// -b "ou=users,dc=example,dc=com" -s base dn >/dev/null 2>&1; then
    echo "[init] Fresh directory detected. Seeding all entries from /seed/users.ldif..."
    sed "s/userPassword: adminpassword/userPassword: ${LDAP_ADMIN_PASSWORD:-adminpassword}/g" /seed/users.ldif | \
        ldapadd -Y EXTERNAL -Q -H ldapi:/// -c || true
    echo "[init] Initial seed complete."
else
    echo "[init] Existing directory entries detected (skipping users.ldif bulk import)."
fi

# 2. Existing volume fallback: Ensure cn=admin DIT entry exists if not already present
if ! ldapsearch -Y EXTERNAL -Q -H ldapi:/// -b "cn=admin,dc=example,dc=com" -s base dn >/dev/null 2>&1; then
    echo "[init] cn=admin DIT entry missing. Creating cn=admin,dc=example,dc=com..."
    cat <<EOF | ldapadd -Y EXTERNAL -Q -H ldapi:///
dn: cn=admin,dc=example,dc=com
objectClass: simpleSecurityObject
objectClass: organizationalRole
cn: admin
description: LDAP administrator
userPassword: ${LDAP_ADMIN_PASSWORD:-adminpassword}
EOF
    echo "[init] cn=admin entry created."
else
    echo "[init] cn=admin DIT entry already present."
fi

# 3. Ensure olcRootPW is removed from cn=config
if ldapsearch -Y EXTERNAL -Q -H ldapi:/// -b "olcDatabase={1}mdb,cn=config" "(olcRootPW=*)" dn 2>/dev/null | grep -q "olcDatabase={1}mdb"; then
    echo "[init] Removing olcRootPW from cn=config..."
    cat <<EOF | ldapmodify -Y EXTERNAL -Q -H ldapi:///
dn: olcDatabase={1}mdb,cn=config
changetype: modify
delete: olcRootPW
EOF
    echo "[init] olcRootPW removed successfully."
else
    echo "[init] olcRootPW already removed from cn=config."
fi

# 4. Clean up osixia admin password flag so it does not overwrite rotated passwords on restart
rm -f /etc/ldap/slapd.d/docker-openldap-was-admin-password-set

echo "[init] OpenLDAP initialization complete."
