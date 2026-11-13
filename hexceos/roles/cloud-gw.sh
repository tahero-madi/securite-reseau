#!/usr/bin/env bash
# cloud-gw (WAN 10.10.0.30, « VPC » 10.101.1.0/24) : passerelle du cloud simulé
#   strongSwan (swanctl), nftables, journal de flux (ulogd2), service applicatif « cloud »
#   (nginx 443 sur 10.101.1.1), arpwatch (observation de l'usurpation ARP au TP 1)
set -Eeuo pipefail
trap 'echo "[KO] cloud-gw, ligne $LINENO : $BASH_COMMAND"' ERR
. ./lab.conf
export DEBIAN_FRONTEND=noninteractive
echo "== cloud-gw"

apt-get install -y -q strongswan-swanctl charon-systemd nftables nginx ulogd2 arpwatch
systemctl disable --now arpwatch >/dev/null 2>&1 || true   # lancé à la main au TP 1
systemctl enable ulogd2 >/dev/null 2>&1 || true
echo "[OK] strongSwan, nftables, ulogd2, nginx, arpwatch installés"

# ---------- « VPC » : interface virtuelle vpc0 portant 10.101.1.1/24 ----------
install -d /etc/systemd/network
cat > /etc/systemd/network/20-vpc0.netdev <<'EOF'
[NetDev]
Name=vpc0
Kind=dummy
EOF
cat > /etc/systemd/network/20-vpc0.network <<EOF
[Match]
Name=vpc0
[Network]
Address=$IP_CLOUDGW_VPC/24
ConfigureWithoutCarrier=yes
EOF
systemctl enable systemd-networkd >/dev/null 2>&1 || true
networkctl reload 2>/dev/null || systemctl restart systemd-networkd
for i in $(seq 1 10); do ip -4 addr show vpc0 2>/dev/null | grep -q "$IP_CLOUDGW_VPC" && break; sleep 1; done
ip -4 addr show vpc0 | grep -q "$IP_CLOUDGW_VPC"
printf 'net.ipv4.ip_forward=1\nnet.ipv4.ip_nonlocal_bind=1\n' > /etc/sysctl.d/60-lab.conf
sysctl -q -p /etc/sysctl.d/60-lab.conf || true
echo "[OK] VPC simulé : vpc0 = $IP_CLOUDGW_VPC/24"

# ---------- strongSwan : configuration vide, le tunnel est écrit au TP 6 ----------
cat > /etc/swanctl/conf.d/README-lab.txt <<'EOF'
Le tunnel vers le pare-feu du site est à écrire dans /etc/swanctl/swanctl.conf (TP 6).
Commandes utiles : swanctl --load-all ; swanctl --initiate --child net ; swanctl --list-sas
EOF
systemctl enable strongswan >/dev/null 2>&1 || true

# ---------- nftables présent mais sans règles (TP 6, partie D) ----------
printf '#!/usr/sbin/nft -f\nflush ruleset\n# Jeu de règles « groupes de sécurité » à écrire au TP 6\n' > /etc/nftables.conf
systemctl enable nftables >/dev/null 2>&1 || true

# ---------- Service applicatif « cloud » publié sur l'interface VPC ----------
install -d -m 755 /etc/nginx/tls /var/www/cloud
if [ ! -f /etc/nginx/tls/cloud.crt ]; then
  openssl req -x509 -newkey rsa:2048 -nodes -days 825 -subj "/O=Cloud/CN=cloud.$DOMAINE" \
    -addext "subjectAltName=DNS:cloud.$DOMAINE,IP:$IP_CLOUDGW_VPC" \
    -keyout /etc/nginx/tls/cloud.key -out /etc/nginx/tls/cloud.crt 2>/dev/null
  chmod 600 /etc/nginx/tls/cloud.key
fi
cat > /etc/nginx/sites-available/default <<EOF
server {
    listen $IP_CLOUDGW_VPC:443 ssl;
    server_name cloud.$DOMAINE;
    ssl_certificate     /etc/nginx/tls/cloud.crt;
    ssl_certificate_key /etc/nginx/tls/cloud.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    root /var/www/cloud;
}
EOF
cat > /var/www/cloud/index.html <<'EOF'
<!doctype html><html lang="fr"><meta charset="utf-8"><title>Service cloud</title>
<h1>Application « cloud » (VPC 10.101.1.0/24)</h1><p>Si vous lisez ceci depuis srv-int, le chemin site → cloud fonctionne.</p></html>
EOF
install -d /etc/systemd/system/nginx.service.d
printf '[Unit]\nAfter=network-online.target\nWants=network-online.target\n' > /etc/systemd/system/nginx.service.d/lab.conf
systemctl daemon-reload
systemctl enable nginx >/dev/null 2>&1
systemctl restart nginx
echo "[OK] service « cloud » : https://$IP_CLOUDGW_VPC (SSH aussi joignable sur cette adresse)"

echo "[OK] cloud-gw prêt"
