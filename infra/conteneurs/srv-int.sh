#!/usr/bin/env bash
# srv-int (zone SRV, 10.1.20.10) : OpenLDAP, FreeRADIUS, collecteur rsyslog, agent Zabbix
set -Eeuo pipefail
trap 'echo "[KO] srv-int ligne $LINENO : $BASH_COMMAND" >&2' ERR
. /root/lab.conf
export DEBIAN_FRONTEND=noninteractive

# ---------- OpenLDAP ----------
debconf-set-selections <<EOF
slapd slapd/no_configuration boolean false
slapd slapd/domain string $DOMAINE
slapd shared/organization string Lab 3-020
slapd slapd/password1 password $PW_LDAP_ADMIN
slapd slapd/password2 password $PW_LDAP_ADMIN
slapd slapd/purge_database boolean true
slapd slapd/move_old_database boolean true
EOF
apt-get install -y -q slapd ldap-utils
BASE="dc=lab,dc=local"
h() { slappasswd -s "$1"; }

cat > /root/annuaire.ldif <<EOF
dn: ou=people,$BASE
objectClass: organizationalUnit
ou: people

dn: ou=groups,$BASE
objectClass: organizationalUnit
ou: groups

dn: ou=services,$BASE
objectClass: organizationalUnit
ou: services

dn: uid=alice,ou=people,$BASE
objectClass: inetOrgPerson
uid: alice
cn: Alice Martin
sn: Martin
mail: alice@$DOMAINE
userPassword: $(h "$PW_ALICE")

dn: uid=bob,ou=people,$BASE
objectClass: inetOrgPerson
uid: bob
cn: Bob Durand
sn: Durand
mail: bob@$DOMAINE
userPassword: $(h "$PW_BOB")

dn: uid=carol,ou=people,$BASE
objectClass: inetOrgPerson
uid: carol
cn: Carol Petit
sn: Petit
mail: carol@$DOMAINE
userPassword: $(h "$PW_CAROL")

dn: cn=admins,ou=groups,$BASE
objectClass: groupOfNames
cn: admins
member: uid=alice,ou=people,$BASE

dn: cn=users,ou=groups,$BASE
objectClass: groupOfNames
cn: users
member: uid=bob,ou=people,$BASE
member: uid=carol,ou=people,$BASE

dn: cn=svc-radius,ou=services,$BASE
objectClass: organizationalRole
objectClass: simpleSecurityObject
cn: svc-radius
description: Compte de service FreeRADIUS (lecture seule)
userPassword: $(h "$PW_SVC_RADIUS")
EOF
ldapadd -x -D "cn=admin,$BASE" -w "$PW_LDAP_ADMIN" -H ldapi:/// -f /root/annuaire.ldif >/dev/null
rm -f /root/annuaire.ldif

# TLS : LDAPS (636) et StartTLS disponibles ; ldap:// en clair reste ouvert (à durcir au TP 4)
install -d -o openldap -g openldap -m 750 /etc/ldap/tls
install -o openldap -g openldap -m 644 /root/pki/ca.crt      /etc/ldap/tls/ca.crt
install -o openldap -g openldap -m 644 /root/pki/srv-int.crt /etc/ldap/tls/srv-int.crt
install -o openldap -g openldap -m 600 /root/pki/srv-int.key /etc/ldap/tls/srv-int.key
ldapmodify -Y EXTERNAL -H ldapi:/// >/dev/null 2>&1 <<EOF
dn: cn=config
changetype: modify
replace: olcTLSCACertificateFile
olcTLSCACertificateFile: /etc/ldap/tls/ca.crt
-
replace: olcTLSCertificateFile
olcTLSCertificateFile: /etc/ldap/tls/srv-int.crt
-
replace: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: /etc/ldap/tls/srv-int.key
EOF
sed -i 's|^SLAPD_SERVICES=.*|SLAPD_SERVICES="ldap:/// ldapi:/// ldaps:///"|' /etc/default/slapd
cat > /etc/ldap/ldap.conf <<EOF
BASE    $BASE
URI     ldap://localhost
TLS_CACERT /etc/ssl/certs/ca-certificates.crt
EOF
systemctl restart slapd

# ---------- FreeRADIUS ----------
# Installé avec sa configuration par défaut ; module ldap présent mais NON activé (TP 4).
apt-get install -y -q freeradius freeradius-ldap freeradius-utils eapoltest
RD=/etc/freeradius/3.0
rm -f $RD/mods-enabled/ldap
install -d -o freerad -g freerad -m 750 $RD/certs/lab
install -o freerad -g freerad -m 644 /root/pki/ca.crt     $RD/certs/lab/ca.pem
install -o freerad -g freerad -m 644 /root/pki/radius.crt $RD/certs/lab/server.pem
install -o freerad -g freerad -m 640 /root/pki/radius.key $RD/certs/lab/server.key
# Matériel pour le défi EAP-TLS (certificat client d'alice)
install -d -o stagiaire -g stagiaire /home/stagiaire/pki
install -o stagiaire -g stagiaire -m 644 /root/pki/ca.crt /root/pki/alice.crt /home/stagiaire/pki/
install -o stagiaire -g stagiaire -m 600 /root/pki/alice.key /home/stagiaire/pki/
systemctl enable freeradius >/dev/null 2>&1
systemctl restart freeradius

# ---------- Collecteur rsyslog ----------
# UDP/TCP 514 actifs ; TLS 6514 fourni en exemple (défi TP 7)
apt-get install -y -q rsyslog-gnutls
install -d -o syslog -g adm -m 750 /var/log/remote
cat > /etc/rsyslog.d/10-collecteur.conf <<'EOF'
# Collecteur central du lab : un fichier par machine émettrice
module(load="imudp")
module(load="imtcp")
template(name="ParHote" type="string" string="/var/log/remote/%HOSTNAME%.log")
ruleset(name="distant") {
  action(type="omfile" dynaFile="ParHote" fileOwner="syslog" fileGroup="adm" fileCreateMode="0640")
  stop
}
input(type="imudp" port="514" ruleset="distant")
input(type="imtcp" port="514" ruleset="distant")
EOF
cat > /etc/rsyslog.d/20-tls.conf.exemple <<'EOF'
# Écoute syslog sur TLS (6514). Renommer en 20-tls.conf puis : systemctl restart rsyslog
global(DefaultNetstreamDriverCAFile="/etc/rsyslog-tls/ca.crt"
       DefaultNetstreamDriverCertFile="/etc/rsyslog-tls/srv-int.crt"
       DefaultNetstreamDriverKeyFile="/etc/rsyslog-tls/srv-int.key")
module(load="imtcp" StreamDriver.Name="gtls" StreamDriver.Mode="1" StreamDriver.Authmode="anon")
input(type="imtcp" port="6514" ruleset="distant")
EOF
install -d -o syslog -g syslog -m 750 /etc/rsyslog-tls
install -o syslog -g syslog -m 644 /root/pki/ca.crt /root/pki/srv-int.crt /etc/rsyslog-tls/
install -o syslog -g syslog -m 600 /root/pki/srv-int.key /etc/rsyslog-tls/srv-int.key
systemctl restart rsyslog

# ---------- Agent Zabbix ----------
# Ubuntu 24.04 ne fournit plus d'agent Zabbix : on prend le dépôt officiel Zabbix 7.0
# (même version que le serveur). Non bloquant : sans agent, seule la partie B du TP 7 est touchée.
installer_agent_zabbix() {
  local base=https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release f
  for f in zabbix-release_latest_7.0+ubuntu24.04_all.deb zabbix-release_7.0-2+ubuntu24.04_all.deb; do
    curl -fsSL -o /tmp/zabbix-release.deb "$base/$f" && break
  done
  [ -s /tmp/zabbix-release.deb ] || return 1
  dpkg -i /tmp/zabbix-release.deb >/dev/null && rm -f /tmp/zabbix-release.deb
  apt-get update -q && apt-get install -y -q zabbix-agent || return 1
  sed -i -e "s/^Server=.*/Server=$HOTE_LAN/" -e "s/^ServerActive=.*/ServerActive=$HOTE_LAN/" \
         -e "s/^Hostname=.*/Hostname=srv-int/" /etc/zabbix/zabbix_agentd.conf
  usermod -aG adm zabbix
  systemctl enable zabbix-agent >/dev/null 2>&1
  systemctl restart zabbix-agent
}
if installer_agent_zabbix; then echo "[OK] agent Zabbix 7.0 installé"
else echo "[!!] agent Zabbix non installé (dépôt repo.zabbix.com injoignable) : le reste du lab n'en dépend pas"; fi

rm -rf /root/pki
echo "[OK] srv-int provisionné"
