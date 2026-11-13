#!/usr/bin/env bash
# Kali (LAN, 10.1.10.10) : poste d'administration de l'apprenant
#   outils réseau et sécurité, Docker, Greenbone Community Edition, Zabbix 7.0, fichiers de TP
set -Eeuo pipefail
trap 'echo "[KO] kali, ligne $LINENO : $BASH_COMMAND"' ERR
. ./lab.conf
export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=l  # pas de redémarrage automatique de services
echo "== Kali"
U=$LAB_USER
H=$(getent passwd "$U" | cut -d: -f6)

# ---------- Outils ----------
echo "== Outils du poste (quelques minutes)"
echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections
OUTILS="wireshark tshark nmap arpwatch dsniff hping3 ldap-utils freeradius-utils eapoltest snmp \
  tnftp telnet testssl.sh ssh-audit python3-scapy git openssl whois sshpass snmp-mibs-downloader"
MANQUANTS=""
for p in $OUTILS; do
  dpkg -s "$p" >/dev/null 2>&1 && continue
  apt-get install -y -q "$p" >/dev/null 2>&1 || MANQUANTS="$MANQUANTS $p"
done
# Debian/Kali/Ubuntu installent la commande sous le nom « testssl » : on garde aussi « testssl.sh »
command -v testssl.sh >/dev/null || { command -v testssl >/dev/null && ln -sf "$(command -v testssl)" /usr/local/bin/testssl.sh; } || true
# À défaut de paquet, version officielle depuis GitHub
if ! command -v testssl.sh >/dev/null; then
  rm -rf /opt/testssl.sh
  git clone -q --depth 1 https://github.com/testssl/testssl.sh.git /opt/testssl.sh \
    && ln -sf /opt/testssl.sh/testssl.sh /usr/local/bin/testssl.sh || echo "[!!] testssl.sh non installé"
fi
command -v ftp >/dev/null || { [ -x /usr/bin/tnftp ] && ln -sf /usr/bin/tnftp /usr/local/bin/ftp; }
# Noms des objets SNMP (system, ifTable…) : activer les MIB installées par snmp-mibs-downloader
[ -f /etc/snmp/snmp.conf ] && sed -i 's/^mibs *:/#mibs :/' /etc/snmp/snmp.conf
dpkg-reconfigure -f noninteractive wireshark-common >/dev/null 2>&1 || true
getent group wireshark >/dev/null && usermod -aG wireshark "$U"
[ -z "$MANQUANTS" ] && echo "[OK] outils du poste installés" || echo "[!!] paquets non installés :$MANQUANTS"

# ---------- Docker ----------
if ! command -v docker >/dev/null; then apt-get install -y -q docker.io; fi
systemctl enable --now docker >/dev/null 2>&1
if ! docker compose version >/dev/null 2>&1; then
  apt-get install -y -q docker-compose >/dev/null 2>&1 || true
fi
if ! docker compose version >/dev/null 2>&1; then
  install -d /usr/local/lib/docker/cli-plugins
  curl -fsSL -o /usr/local/lib/docker/cli-plugins/docker-compose \
    https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64
  chmod 755 /usr/local/lib/docker/cli-plugins/docker-compose
fi
docker compose version >/dev/null
usermod -aG docker "$U"
echo "[OK] Docker et docker compose"

# ---------- Zabbix 7.0 ----------
install -d /opt/zabbix
cat > /opt/zabbix/compose.yaml <<'EOF'
# Zabbix 7.0 LTS du lab 3-020, sur le poste Kali (10.1.10.10)
#   Interface web : http://127.0.0.1:8080  (Admin / zabbix, à changer au TP 7)
#   Agents actifs : 10.1.10.10:10051 (joignable depuis les zones via pfSense)
name: zabbix
services:
  postgres:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER: zabbix
      POSTGRES_PASSWORD: ${PW_ZABBIX_DB}
      POSTGRES_DB: zabbix
    volumes: [pgdata:/var/lib/postgresql/data]
  zabbix-server:
    image: zabbix/zabbix-server-pgsql:ubuntu-7.0-latest
    restart: unless-stopped
    depends_on: [postgres]
    environment:
      DB_SERVER_HOST: postgres
      POSTGRES_USER: zabbix
      POSTGRES_PASSWORD: ${PW_ZABBIX_DB}
      POSTGRES_DB: zabbix
    ports: ["10.1.10.10:10051:10051"]
  zabbix-web:
    image: zabbix/zabbix-web-nginx-pgsql:ubuntu-7.0-latest
    restart: unless-stopped
    depends_on: [zabbix-server]
    environment:
      DB_SERVER_HOST: postgres
      POSTGRES_USER: zabbix
      POSTGRES_PASSWORD: ${PW_ZABBIX_DB}
      POSTGRES_DB: zabbix
      ZBX_SERVER_HOST: zabbix-server
      PHP_TZ: Europe/Paris
    ports: ["127.0.0.1:8080:8080"]
volumes:
  pgdata:
EOF
printf 'PW_ZABBIX_DB=%s\n' "$PW_ZABBIX_DB" > /opt/zabbix/.env; chmod 600 /opt/zabbix/.env
echo "== Zabbix : téléchargement des images (quelques minutes)"
docker compose -f /opt/zabbix/compose.yaml --env-file /opt/zabbix/.env pull -q
docker compose -f /opt/zabbix/compose.yaml --env-file /opt/zabbix/.env up -d
echo "[OK] Zabbix : http://127.0.0.1:8080 (Admin / zabbix)"

# ---------- Greenbone Community Edition ----------
GB=/opt/greenbone; install -d $GB
if [ ! -s $GB/compose.yaml ]; then
  curl -fsSL -o $GB/compose.yaml https://greenbone.github.io/docs/latest/_static/compose.yaml \
    || curl -fsSL -o $GB/compose.yaml https://greenbone.github.io/docs/latest/_static/docker-compose.yml
fi
GBC=(docker compose -f $GB/compose.yaml -p greenbone-community-edition)
echo "== Greenbone : téléchargement des images (10 à 30 minutes selon le débit)"
"${GBC[@]}" pull -q
"${GBC[@]}" up -d
admin_present() { "${GBC[@]}" exec -T -u gvmd gvmd gvmd --get-users 2>/dev/null | grep -qx admin; }
echo "== Greenbone : attente du gestionnaire gvmd (jusqu'à 15 minutes)"
for i in $(seq 1 90); do admin_present && break; sleep 10; done
# Mot de passe admin : gvmd peut mettre plus d'une heure à être disponible pendant le premier
# chargement du flux. Un service réessaie toutes les 2 minutes jusqu'à réussir, puis se désactive.
cat > /usr/local/sbin/lab-greenbone-mdp <<SCRIPT
#!/bin/bash
# Positionne le mot de passe admin de Greenbone (lab 3-020), puis désactive son minuteur.
docker compose -f $GB/compose.yaml -p greenbone-community-edition exec -T -u gvmd gvmd \\
  gvmd --user=admin --new-password='$PW_GREENBONE' || exit 1
touch /var/lib/lab-greenbone-mdp.ok
systemctl disable --now lab-greenbone-mdp.timer >/dev/null 2>&1 || true
echo "mot de passe admin de Greenbone positionné"
SCRIPT
chmod 700 /usr/local/sbin/lab-greenbone-mdp
cat > /etc/systemd/system/lab-greenbone-mdp.service <<'UNIT'
[Unit]
Description=Lab 3-020 : mot de passe admin de Greenbone
After=docker.service
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/lab-greenbone-mdp
UNIT
cat > /etc/systemd/system/lab-greenbone-mdp.timer <<'UNIT'
[Unit]
Description=Lab 3-020 : réessaie de positionner le mot de passe admin de Greenbone
[Timer]
OnActiveSec=10s
OnBootSec=2min
OnUnitInactiveSec=2min
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload
if [ -f /var/lib/lab-greenbone-mdp.ok ] || /usr/local/sbin/lab-greenbone-mdp >/dev/null 2>&1; then
  echo "[OK] mot de passe admin de Greenbone positionné"
else
  systemctl enable --now lab-greenbone-mdp.timer >/dev/null 2>&1
  echo "[!!] gvmd pas encore prêt : le mot de passe admin de Greenbone sera positionné automatiquement (réessai toutes les 2 min ; en attendant : admin / admin)"
fi
GSA_URL=http://127.0.0.1:9392
for i in $(seq 1 30); do
  if [ "$(curl -sk -o /dev/null -w '%{http_code}' https://127.0.0.1/ || true)" != 000 ]; then GSA_URL=https://127.0.0.1; break; fi
  if [ "$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:9392/ || true)" != 000 ]; then break; fi
  sleep 5
done
echo "[OK] Greenbone : $GSA_URL (admin / $PW_GREENBONE) — le flux se charge en arrière-plan (30 min à 2 h)"

# ---------- Fichiers de TP ----------
T="$H/TP"; install -d -o "$U" -g "$U" "$T" "$H/pki" "$H/livrables"
for f in tp1-arp-demo.pcap tp1-ftp-clear.pcap tp7-incident.pcap mandat-audit-TP8.pdf; do
  curl -fsSL -o "$T/$f" "$LAB_BASE/fichiers/$f" || echo "[!!] $f non téléchargé"
done
cat > "$T/identifiants-lab.txt" <<EOF
Identifiants initiaux du lab 3-020 (à changer pendant les TP)
--------------------------------------------------------------
VM du lab (SSH)         compte « formation », mot de passe : portail Hexceos (bouton clé)
pfSense                 https://$FW_LAN             compte : portail Hexceos (bouton clé)
Greenbone (GSA)         $GSA_URL         admin / $PW_GREENBONE
Zabbix                  http://127.0.0.1:8080      Admin / zabbix
LDAP (admin)            cn=admin,dc=lab,dc=local   $PW_LDAP_ADMIN
LDAP (service RADIUS)   cn=svc-radius,ou=services,dc=lab,dc=local   $PW_SVC_RADIUS
Utilisateurs LDAP       alice / $PW_ALICE (admins) · bob / $PW_BOB · carol / $PW_CAROL
FTP en clair (web)      ftpdemo / $PW_FTPDEMO
DVWA                    http://$IP_WEB/dvwa/       admin / password
EOF
for f in cartographie.md matrice-risques.md; do
  [ -e "$H/livrables/$f" ] || curl -fsSL -o "$H/livrables/$f" "$LAB_BASE/tp1/modeles/$f" || true
done
chown -R "$U:$U" "$T" "$H/pki" "$H/livrables"
echo "[OK] fichiers de TP dans $T (captures, mandat, identifiants)"

echo "[OK] Kali prête — fermez puis rouvrez la session de $U (groupes docker et wireshark)"
