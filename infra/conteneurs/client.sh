#!/usr/bin/env bash
# client (LAN, 10.1.10.20) : poste utilisateur « normal » qui génère du trafic de fond
set -Eeuo pipefail
trap 'echo "[KO] client ligne $LINENO : $BASH_COMMAND" >&2' ERR
. /root/lab.conf
export DEBIAN_FRONTEND=noninteractive

apt-get install -y -q tnftp

cat > /usr/local/bin/trafic-poste <<EOF
#!/bin/sh
# Activité d'un poste : la passerelle, l'intranet, un site externe
ping -c 3 -W 1 $FW_LAN >/dev/null 2>&1
curl -s -m 5 -o /dev/null http://$IP_WEB/ || true
curl -s -m 5 -o /dev/null https://www.ubuntu.com/ || true
EOF
chmod 755 /usr/local/bin/trafic-poste
cat > /etc/systemd/system/trafic-poste.service <<'EOF'
[Unit]
Description=Trafic de fond d'un poste utilisateur
[Service]
Type=oneshot
ExecStart=/usr/local/bin/trafic-poste
EOF
cat > /etc/systemd/system/trafic-poste.timer <<'EOF'
[Unit]
Description=Trafic de fond toutes les 20 s
[Timer]
OnBootSec=30
OnUnitActiveSec=20
AccuracySec=1
[Install]
WantedBy=timers.target
EOF
systemctl daemon-reload
systemctl enable trafic-poste.timer >/dev/null 2>&1
echo "[OK] client provisionné"
