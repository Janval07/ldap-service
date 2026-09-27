# OpenLDAP Service

Standalone OpenLDAP and phpLDAPadmin service for authentication and directory services.

## Architecture

- **OpenLDAP**: Exposed on ports `389` (LDAP) and `636` (LDAPS)
- **phpLDAPadmin**: Web administration UI exposed on port `8080` (HTTP)

## Start Standalone

From the `ldap-service/` directory:

```bash
docker compose up -d
```

To view running containers:

```bash
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
```

You should see:

```text
phpldapadmin   osixia/phpldapadmin:latest   ...   0.0.0.0:8080->80/tcp
openldap       osixia/openldap:1.5.0         ...   0.0.0.0:389->389/tcp, 0.0.0.0:636->636/tcp
```

## phpLDAPadmin

Open your browser at:

```text
http://localhost:8080
```

- **Login DN**: `cn=admin,dc=example,dc=com`
- **Password**: `adminpassword`

## Automatic Initialization & Seed LDIF

Starting the service via `docker compose up -d` automatically executes `init-ldap.sh`, which:
1. Waits for OpenLDAP to complete startup and become healthy.
2. Seeds `ou=users`, `ou=groups`, `uid=alice`, `uid=bob`, `cn=developers`, and `cn=admin,dc=example,dc=com` in a single pass.
3. Automatically removes `olcRootPW` from `cn=config` so password modifications via `ldap3` / `secret-rotator` take immediate effect.

If you ever need to manually re-import or add entries, you can still run:
```powershell
docker exec openldap ldapadd -x -H ldap://localhost -D "cn=admin,dc=example,dc=com" -w adminpassword -f /seed/users.ldif
```

Expected entries created:
- `ou=users,dc=example,dc=com`
- `ou=groups,dc=example,dc=com`
- `uid=alice,ou=users,dc=example,dc=com`
- `uid=bob,ou=users,dc=example,dc=com`
- `cn=developers,ou=groups,dc=example,dc=com`

## Verify with ldapwhoami

Test LDAP authentication directly using `ldapwhoami`:

### Test user `alice`:

```bash
docker exec openldap ldapwhoami \
  -x \
  -H ldap://localhost \
  -D "uid=alice,ou=users,dc=example,dc=com" \
  -w alice123
```

Expected output:

```text
dn:uid=alice,ou=users,dc=example,dc=com
```

### Test user `bob`:

```bash
docker exec openldap ldapwhoami \
  -x \
  -H ldap://localhost \
  -D "uid=bob,ou=users,dc=example,dc=com" \
  -w bob123
```

Expected output:

```text
dn:uid=bob,ou=users,dc=example,dc=com
```

## Query Directory (ldapsearch)

To query all user entries in the directory:

```bash
docker exec openldap ldapsearch \
  -x \
  -H ldap://localhost \
  -D "cn=admin,dc=example,dc=com" \
  -w adminpassword \
  -b "ou=users,dc=example,dc=com" \
  "(objectClass=inetOrgPerson)"
```

## Seed Credentials Summary

| Identity / User | DN | Password |
|---|---|---|
| **Administrator** | `cn=admin,dc=example,dc=com` | `adminpassword` |
| **Alice Smith** | `uid=alice,ou=users,dc=example,dc=com` | `alice123` |
| **Bob Johnson** | `uid=bob,ou=users,dc=example,dc=com` | `bob123` |

## Stop Standalone Service

To stop the containers while preserving volume data:

```bash
docker compose down
```

To stop and wipe directory volumes:

```bash
docker compose down -v
```
