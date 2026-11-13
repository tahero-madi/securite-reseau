#!/usr/bin/env bash
# web (DMZ, 10.1.30.10) : serveur exposé ET cible volontairement vulnérable
#   nginx (TLS perfectible), DVWA, OWASP Juice Shop, FTP en clair, Telnet, SNMP v2c.
# Les paquets de service sont pris dans la version de sortie d'Ubuntu 24.04 (sans les
# mises à jour) pour que le scan authentifié du TP 2 trouve des correctifs manquants.
set -Eeuo pipefail
trap 'echo "[KO] web, ligne $LINENO : $BASH_COMMAND"' ERR
. ./lab.conf
export DEBIAN_FRONTEND=noninteractive
echo "== web"

PAQUETS="nginx php8.3-fpm php8.3-mysql php8.3-gd mariadb-server vsftpd inetutils-telnetd openbsd-inetd snmpd git xz-utils"

# ---------- Paquets « en retard » ----------
SRC=/etc/apt/sources.list.d/ubuntu.sources
if [ -f $SRC ] && ! dpkg -s nginx >/dev/null 2>&1; then
  cp $SRC /root/ubuntu.sources.orig
  cat > $SRC <<'EOF'
Types: deb
URIs: http://archive.ubuntu.com/ubuntu/
Suites: noble
Components: main universe restricted multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
  apt-get update -q
  if ! apt-get install -y -q $PAQUETS; then
    echo "[!!] installation depuis la version de sortie impossible : installation à jour"
    cp /root/ubuntu.sources.orig $SRC; apt-get update -q; apt-get install -y -q $PAQUETS
  fi
  cp /root/ubuntu.sources.orig $SRC
  apt-get update -q   # les mises à jour sont visibles mais NON appliquées (remédiation du TP 2)
else
  apt-get install -y -q $PAQUETS
fi
echo "[OK] paquets de service (versions de sortie d'Ubuntu 24.04)"

# ---------- nginx + PHP (certificat autosigné : constat d'audit) ----------
install -d -m 755 /etc/nginx/tls
if [ ! -f /etc/nginx/tls/web.crt ]; then
  openssl req -x509 -newkey rsa:2048 -nodes -days 825 -subj "/O=PME/CN=web.$DOMAINE" \
    -addext "subjectAltName=DNS:web.$DOMAINE,IP:$IP_WEB,IP:$FW_WAN" \
    -keyout /etc/nginx/tls/web.key -out /etc/nginx/tls/web.crt 2>/dev/null
  chmod 600 /etc/nginx/tls/web.key
fi
cat > /etc/nginx/sites-available/default <<'EOF'
# Configuration volontairement perfectible (audit TLS du TP 8)
server {
    listen 80 default_server;
    listen 443 ssl default_server;
    server_name web.lab.local;
    server_tokens on;

    ssl_certificate     /etc/nginx/tls/web.crt;
    ssl_certificate_key /etc/nginx/tls/web.key;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers   DEFAULT:@SECLEVEL=0;

    root /var/www/html;
    index index.php index.html;

    location / { try_files $uri $uri/ =404; }
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
    }
}
EOF
cat > /var/www/html/index.html <<'EOF'
<!doctype html><html lang="fr"><meta charset="utf-8"><title>Intranet PME</title>
<h1>Intranet PME — serveur web DMZ</h1>
<ul><li><a href="/dvwa/">Application interne (DVWA)</a></li>
<li>Boutique : port 3000</li></ul></html>
EOF
# Dépôt git oublié dans la racine web (détecté au TP 5)
install -d /var/www/html/.git
cat > /var/www/html/.git/config <<'EOF'
[core]
	repositoryformatversion = 0
	bare = false
[remote "origin"]
	url = https://deploy:Deploy2019!@git.lab.local/intranet.git
	fetch = +refs/heads/*:refs/remotes/origin/*
EOF
echo "[OK] nginx (80, 443 avec TLS 1.0/1.1 et certificat autosigné)"

# ---------- DVWA ----------
mysql <<EOF
CREATE DATABASE IF NOT EXISTS dvwa;
CREATE USER IF NOT EXISTS 'dvwa'@'localhost' IDENTIFIED BY '$PW_DVWA_DB';
GRANT ALL ON dvwa.* TO 'dvwa'@'localhost';
FLUSH PRIVILEGES;
EOF
[ -d /var/www/html/dvwa ] || git clone -q --depth 1 https://github.com/digininja/DVWA.git /var/www/html/dvwa
cd /var/www/html/dvwa/config
cp config.inc.php.dist config.inc.php
sed -i -e "s/\(\$_DVWA\[ 'db_server' \] *= *\).*/\1'127.0.0.1';/" \
       -e "s/\(\$_DVWA\[ 'db_user' \] *= *\).*/\1'dvwa';/" \
       -e "s/\(\$_DVWA\[ 'db_password' \] *= *\).*/\1'$PW_DVWA_DB';/" \
       -e "s/\(\$_DVWA\[ 'default_security_level' \] *= *\).*/\1'low';/" config.inc.php
cd /
chown -R www-data:www-data /var/www/html
systemctl restart php8.3-fpm nginx
J=$(mktemp)
TOK=$(curl -s -c "$J" http://127.0.0.1/dvwa/setup.php | grep -oP "name='user_token' value='\K[^']+" || true)
if [ -n "$TOK" ]; then
  curl -s -b "$J" -c "$J" --data-urlencode "create_db=Create / Reset Database" \
       --data-urlencode "user_token=$TOK" http://127.0.0.1/dvwa/setup.php >/dev/null
  echo "[OK] DVWA (http://$IP_WEB/dvwa/, admin / password)"
else
  echo "[!!] DVWA : ouvrir http://$IP_WEB/dvwa/setup.php et cliquer « Create / Reset Database »"
fi
rm -f "$J"

# ---------- OWASP Juice Shop (port 3000) ----------
installer_juice() {
  local maj=$1 node js
  node=$(curl -fsS "https://nodejs.org/dist/latest-v${maj}.x/SHASUMS256.txt" | awk '/linux-x64.tar.xz$/{print $2; exit}')
  [ -n "$node" ] || return 1
  js=$(curl -fsS https://api.github.com/repos/juice-shop/juice-shop/releases/latest \
       | jq -r '.assets[].browser_download_url' | grep "_node${maj}_linux_x64.tgz$" | head -1)
  [ -n "$js" ] || return 1
  rm -rf /opt/node /opt/juice-shop; install -d /opt/node /opt/juice-shop
  curl -fsSL "https://nodejs.org/dist/latest-v${maj}.x/$node" | tar -xJ --strip-components=1 -C /opt/node
  curl -fsSL "$js" | tar -xz --strip-components=1 -C /opt/juice-shop
  id juice >/dev/null 2>&1 || useradd -r -d /opt/juice-shop -s /usr/sbin/nologin juice
  chown -R juice:juice /opt/juice-shop
  cat > /etc/systemd/system/juice-shop.service <<'EOF'
[Unit]
Description=OWASP Juice Shop (cible volontairement vulnérable)
After=network.target
[Service]
User=juice
WorkingDirectory=/opt/juice-shop
Environment=PATH=/opt/node/bin:/usr/bin:/bin NODE_ENV=production
ExecStart=/opt/node/bin/npm start
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload; systemctl enable --now juice-shop >/dev/null 2>&1
}
if systemctl is-enabled juice-shop >/dev/null 2>&1; then echo "[OK] Juice Shop déjà installé"
elif installer_juice 22 || installer_juice 20; then echo "[OK] Juice Shop (port 3000)"
else echo "[!!] Juice Shop non installé (téléchargement impossible) : le reste du lab n'en dépend pas"; fi

# ---------- Services anciens (rôle « hérité ») ----------
id ftpdemo >/dev/null 2>&1 || useradd -m -s /bin/bash ftpdemo
echo "ftpdemo:$PW_FTPDEMO" | chpasswd
printf 'client;email;montant\nDupont;dupont@exemple.fr;1200\nMartin;martin@exemple.fr;860\n' > /home/ftpdemo/export-clients.csv
chown ftpdemo:ftpdemo /home/ftpdemo/export-clients.csv
sed -i -e 's/^#\?write_enable=.*/write_enable=YES/' -e 's/^#\?chroot_local_user=.*/chroot_local_user=YES/' /etc/vsftpd.conf
grep -q '^allow_writeable_chroot' /etc/vsftpd.conf || echo 'allow_writeable_chroot=YES' >> /etc/vsftpd.conf
systemctl enable vsftpd >/dev/null 2>&1; systemctl restart vsftpd
grep -q '^telnet' /etc/inetd.conf || echo 'telnet stream tcp nowait root /usr/sbin/tcpd /usr/sbin/telnetd' >> /etc/inetd.conf
systemctl enable openbsd-inetd >/dev/null 2>&1; systemctl restart openbsd-inetd
cat > /etc/snmp/snmpd.conf <<'EOF'
agentAddress udp:161
rocommunity public default
sysLocation DMZ - salle serveurs
sysContact admin@lab.local
EOF
systemctl enable snmpd >/dev/null 2>&1; systemctl restart snmpd
echo "[OK] services anciens : FTP (ftpdemo), Telnet, SNMP v2c « public »"

echo "[OK] web prêt"
