#!/usr/bin/env bash
# cloud-gw : passerelle du « cloud » simulé (WAN 203.0.113.21, VPC 10.101.1.1)
#   strongSwan (swanctl), nftables, service applicatif « cloud » (nginx 443 + SSH sur 10.101.1.1)
set -Eeuo pipefail
trap 'echo "[KO] cloud-gw ligne $LINENO : $BASH_COMMAND" >&2' ERR
. /root/lab.conf
export DEBIAN_FRONTEND=noninteractive

apt-get install -y -q strongswan-swanctl charon-systemd nftables nginx ulogd2
# Journal de flux du TP 6 : règles nftables « log group 0 » -> /var/log/ulog/syslogemu.log
systemctl enable ulogd2 >/dev/null 2>&1 || true
printf 'net.ipv4.ip_forward=1\nnet.ipv4.ip_nonlocal_bind=1\n' > /etc/sysctl.d/60-lab.conf
sysctl -q -p /etc/sysctl.d/60-lab.conf || true

# swanctl.conf vide : le tunnel est écrit au TP 6
cat > /etc/swanctl/conf.d/README-lab.txt <<'EOF'
Le tunnel vers le pare-feu du site est à écrire dans /etc/swanctl/swanctl.conf (TP 6).
Commandes utiles : swanctl --load-all ; swanctl --initiate --child net ; swanctl --list-sas
EOF
systemctl enable strongswan >/dev/null 2>&1 || true

# nftables présent mais sans règles (TP 6, partie D)
printf '#!/usr/sbin/nft -f\nflush ruleset\n# Jeu de règles « groupes de sécurité » à écrire au TP 6\n' > /etc/nftables.conf
systemctl enable nftables >/dev/null 2>&1 || true

# Service applicatif « cloud » publié sur l'interface VPC
install -d -m 755 /etc/nginx/tls /var/www/cloud
install -m 644 /root/pki/cloud.crt /etc/nginx/tls/cloud.crt
install -m 600 /root/pki/cloud.key /etc/nginx/tls/cloud.key
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
# nginx doit attendre l'adresse VPC
install -d /etc/systemd/system/nginx.service.d
printf '[Unit]\nAfter=network-online.target\nWants=network-online.target\n' > /etc/systemd/system/nginx.service.d/lab.conf
systemctl daemon-reload
systemctl enable nginx >/dev/null 2>&1

rm -rf /root/pki
echo "[OK] cloud-gw provisionné"
