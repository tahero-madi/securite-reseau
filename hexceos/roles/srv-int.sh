#!/usr/bin/env bash
# srv-int (zone SRV, 10.1.20.10) : AC du lab, OpenLDAP, FreeRADIUS, collecteur rsyslog, agent Zabbix
set -Eeuo pipefail
trap 'echo "[KO] srv-int, ligne $LINENO : $BASH_COMMAND"' ERR
. ./lab.conf
export DEBIAN_FRONTEND=noninteractive
echo "== srv-int"
U=$LAB_USER

# ---------- Autorité de certification du lab ----------
# Créée ici, une fois : les autres machines récupèrent ca.crt au besoin (TP 4).
PKI=/etc/lab-pki
install -d -m 700 $PKI
if [ ! -f $PKI/ca.crt ]; then
  openssl req -x509 -newkey rsa:3072 -nodes -days 1095 -subj "/O=Lab 3-020/CN=AC Lab 3-020" \
    -keyout $PKI/ca.key -out $PKI/ca.crt 2>/dev/null
  emettre() { # nom CN SAN usage
    openssl req -newkey rsa:2048 -nodes -subj "/O=Lab 3-020/CN=$2" -keyout $PKI/$1.key -out $PKI/$1.csr 2>/dev/null
    printf 'subjectAltName=%s\nextendedKeyUsage=%s\n' "$3" "$4" > $PKI/$1.ext
    openssl x509 -req -in $PKI/$1.csr -CA $PKI/ca.crt -CAkey $PKI/ca.key -CAcreateserial \
      -days 825 -extfile $PKI/$1.ext -out $PKI/$1.crt 2>/dev/null
    rm -f $PKI/$1.csr $PKI/$1.ext
  }
  emettre srv-int srv-int.$DOMAINE "DNS:srv-int.$DOMAINE,DNS:ldap.$DOMAINE,DNS:srv-int,IP:$IP_SRVINT" serverAuth
  emettre radius  radius.$DOMAINE  "DNS:radius.$DOMAINE,DNS:srv-int.$DOMAINE" serverAuth
  emettre alice   alice            "email:alice@$DOMAINE" clientAuth
  chmod 600 $PKI/*.key
fi
chmod 644 $PKI/ca.crt
# Matériel pour le défi EAP-TLS du TP 4 (et AC publique du lab)
install -d -o "$U" -g "$U" "/home/$U/pki"
install -o "$U" -g "$U" -m 644 $PKI/ca.crt $PKI/alice.crt "/home/$U/pki/"
install -o "$U" -g "$U" -m 600 $PKI/alice.key "/home/$U/pki/"
echo "[OK] AC du lab (/etc/lab-pki, copie publique dans /home/$U/pki/ca.crt)"

# ---------- OpenLDAP ----------
if ! dpkg -s slapd >/dev/null 2>&1; then
  debconf-set-selections <<EOF
slapd slapd/no_configuration boolean false
slapd slapd/domain string $DOMAINE
slapd shared/organization string Lab 3-020
slapd slapd/password1 password $PW_LDAP_ADMIN
slapd slapd/password2 password $PW_LDAP_ADMIN
slapd slapd/purge_database boolean true
slapd slapd/move_old_database boolean true
EOF
fi
apt-get install -y -q slapd ldap-utils
BASE="dc=lab,dc=local"
if ! ldapsearch -x -LLL -H ldapi:/// -b "ou=people,$BASE" uid=alice dn 2>/dev/null | grep -q alice; then
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
fi
# TLS : LDAPS (636) et StartTLS ; ldap:// en clair reste ouvert (à durcir au TP 4)
install -d -o openldap -g openldap -m 750 /etc/ldap/tls
install -o openldap -g openldap -m 644 $PKI/ca.crt      /etc/ldap/tls/ca.crt
install -o openldap -g openldap -m 644 $PKI/srv-int.crt /etc/ldap/tls/srv-int.crt
install -o openldap -g openldap -m 600 $PKI/srv-int.key /etc/ldap/tls/srv-int.key
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
TLS_CACERT /etc/ldap/tls/ca.crt
EOF
systemctl restart slapd
echo "[OK] OpenLDAP (dc=lab,dc=local ; alice, bob, carol ; ldap 389 et ldaps 636)"

# ---------- FreeRADIUS ----------
# Configuration par défaut ; module ldap présent mais NON activé (TP 4).
apt-get install -y -q freeradius freeradius-ldap freeradius-utils eapoltest
RD=/etc/freeradius/3.0
rm -f $RD/mods-enabled/ldap
install -d -o freerad -g freerad -m 750 $RD/certs/lab
install -o freerad -g freerad -m 644 $PKI/ca.crt     $RD/certs/lab/ca.pem
install -o freerad -g freerad -m 644 $PKI/radius.crt $RD/certs/lab/server.pem
install -o freerad -g freerad -m 640 $PKI/radius.key $RD/certs/lab/server.key
systemctl enable freeradius >/dev/null 2>&1
systemctl restart freeradius
echo "[OK] FreeRADIUS (configuration par défaut, module ldap à activer au TP 4)"

# ---------- Collecteur rsyslog ----------
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
install -o syslog -g syslog -m 644 $PKI/ca.crt $PKI/srv-int.crt /etc/rsyslog-tls/
install -o syslog -g syslog -m 600 $PKI/srv-int.key /etc/rsyslog-tls/srv-int.key
systemctl restart rsyslog
echo "[OK] collecteur rsyslog (UDP et TCP 514, /var/log/remote/)"

# ---------- Agent Zabbix 7.0 (dépôt officiel, même version que le serveur sur Kali) ----------
installer_agent_zabbix() {
  local base=https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release f
  if ! dpkg -s zabbix-release >/dev/null 2>&1; then
    rm -f /tmp/zabbix-release.deb
    for f in zabbix-release_latest_7.0+ubuntu24.04_all.deb zabbix-release_7.0-2+ubuntu24.04_all.deb; do
      curl -fsSL -o /tmp/zabbix-release.deb "$base/$f" && break
    done
    [ -s /tmp/zabbix-release.deb ] || return 1
    dpkg -i /tmp/zabbix-release.deb >/dev/null && rm -f /tmp/zabbix-release.deb
  fi
  apt-get update -q && apt-get install -y -q zabbix-agent || return 1
  sed -i -e "s/^Server=.*/Server=$IP_KALI/" -e "s/^ServerActive=.*/ServerActive=$IP_KALI/" \
         -e "s/^Hostname=.*/Hostname=srv-int/" /etc/zabbix/zabbix_agentd.conf
  usermod -aG adm zabbix
  systemctl enable zabbix-agent >/dev/null 2>&1
  systemctl restart zabbix-agent
}
if installer_agent_zabbix; then echo "[OK] agent Zabbix 7.0 (serveur : $IP_KALI)"
else echo "[!!] agent Zabbix non installé (repo.zabbix.com injoignable) : seule la partie B du TP 7 est touchée"; fi

echo "[OK] srv-int prêt"
