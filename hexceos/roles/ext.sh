#!/usr/bin/env bash
# ext (WAN, 10.10.0.40) : machine « Internet » — tests de publication (TP 3), attaques vues
# par Suricata (TP 5), vérification de l'exposition (TP 8), usurpation ARP sur le WAN (TP 1)
set -Eeuo pipefail
trap 'echo "[KO] ext, ligne $LINENO : $BASH_COMMAND"' ERR
. ./lab.conf
export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=l  # pas de redémarrage automatique de services
echo "== ext"
apt-get install -y -q nmap ssh-audit dsniff hping3 snmp ldap-utils git iputils-arping
apt-get install -y -q testssl.sh || true
# Debian/Kali/Ubuntu installent la commande sous le nom « testssl » : on garde aussi « testssl.sh »
command -v testssl.sh >/dev/null || { command -v testssl >/dev/null && ln -sf "$(command -v testssl)" /usr/local/bin/testssl.sh; } || true
# À défaut de paquet, version officielle depuis GitHub
if ! command -v testssl.sh >/dev/null; then
  rm -rf /opt/testssl.sh
  git clone -q --depth 1 https://github.com/testssl/testssl.sh.git /opt/testssl.sh \
    && ln -sf /opt/testssl.sh/testssl.sh /usr/local/bin/testssl.sh || echo "[!!] testssl.sh non installé"
fi
# Pas de redirections ICMP pendant la démonstration d'homme du milieu du TP 1
IF=$(ip -o -4 addr show | awk -v ip="$IP_EXT/" 'index($4, ip) == 1 {print $2; exit}')
cat > /etc/sysctl.d/60-lab.conf <<EOF
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.conf.${IF:-ens18}.send_redirects=0
EOF
sysctl -q -p /etc/sysctl.d/60-lab.conf || true
echo "[OK] outils : nmap, testssl.sh, ssh-audit, arpspoof (dsniff), hping3, snmpwalk"
echo "[OK] ext prêt"
