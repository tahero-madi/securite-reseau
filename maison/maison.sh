#!/usr/bin/env bash
# =====================================================================
#  Lab 3-020 à la maison : deux rôles dans une même VM
#    VM « interne » : poste Kali (espace réseau principal, LAN 10.1.10.10)
#                     + srv-int (espace réseau « srvint », SRV 10.1.20.10)
#    VM « externe » : cloud-gw (espace réseau principal, WAN 10.10.0.30)
#                     + ext (espace réseau « ext », WAN 10.10.0.40)
#  Chaque rôle garde sa carte, son adresse et ses routes : les deux rôles
#  d'une VM ne se parlent qu'en passant par pfSense, comme sur la plateforme.
#
#  Usage :
#    curl -fsSL https://raw.githubusercontent.com/tahero-madi/securite-reseau/main/maison/maison.sh | sudo bash -s interne
#    curl -fsSL https://raw.githubusercontent.com/tahero-madi/securite-reseau/main/maison/maison.sh | sudo bash -s externe
#  Le script peut être relancé.
# =====================================================================
set -euo pipefail

main() {
  ROLE=${1:-}
  [ "$(id -u)" -eq 0 ] || { echo "À lancer avec sudo"; exit 1; }
  U=${SUDO_USER:-}
  [ -n "$U" ] && [ "$U" != root ] || U=$(getent passwd 1000 | cut -d: -f1)
  export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=l

  case $ROLE in
    interne) NS=srvint; NOM=srv-int; MAC=52:54:00:20:00:10; ADR=10.1.20.10/24; GW=10.1.20.1; DNS=10.1.20.1; ROUTES="" ;;
    externe) NS=ext;    NOM=ext;     MAC=52:54:00:00:00:40; ADR=10.10.0.40/24; GW=10.10.0.1; DNS=10.10.0.1; ROUTES="10.1.0.0/16 10.10.0.20" ;;
    *) echo "Usage : maison.sh interne|externe"; exit 1 ;;
  esac
  echo "== VM $ROLE : rôle $NOM dans l'espace réseau « $NS »"

  # ---------- Script qui crée l'espace réseau et y déplace la carte ----------
  cat > /usr/local/sbin/lab-netns <<'SCRIPT'
#!/usr/bin/env bash
# lab-netns ESPACE MAC ADRESSE/MASQUE PASSERELLE DNS [RÉSEAU ROUTEUR]...
# Crée l'espace réseau, y déplace la carte qui porte l'adresse MAC, la configure.
set -euo pipefail
NS=$1 MAC=$2 ADR=$3 GW=$4 DNS=$5; shift 5
IFN=${NS}0
ip netns add "$NS" 2>/dev/null || true
if ! ip -n "$NS" link show "$IFN" >/dev/null 2>&1; then
  IF=""
  for i in $(seq 1 30); do
    IF=$(ip -o link show | awk -v m="$MAC" 'tolower($0) ~ m {n=$2; sub(/:$/,"",n); sub(/@.*/,"",n); print n; exit}')
    [ -n "$IF" ] && break
    sleep 1
  done
  [ -n "$IF" ] || { echo "Carte $MAC introuvable"; exit 1; }
  ip link set "$IF" down
  ip link set "$IF" netns "$NS"
  ip -n "$NS" link set "$IF" name "$IFN"
fi
ip netns exec "$NS" sysctl -e -q -w \
  net.ipv6.conf.all.disable_ipv6=1 net.ipv6.conf.default.disable_ipv6=1 \
  net.ipv4.conf.all.send_redirects=0 net.ipv4.conf.default.send_redirects=0 \
  "net.ipv4.conf.$IFN.send_redirects=0" "net.ipv4.ping_group_range=0 2147483647" || true
ip -n "$NS" link set lo up
ip -n "$NS" link set "$IFN" up
ip -n "$NS" addr replace "$ADR" dev "$IFN"
ip -n "$NS" route replace default via "$GW"
while [ $# -ge 2 ]; do ip -n "$NS" route replace "$1" via "$2"; shift 2; done
install -d "/etc/netns/$NS"
echo "nameserver $DNS" > "/etc/netns/$NS/resolv.conf"
SCRIPT
  chmod 755 /usr/local/sbin/lab-netns

  cat > "/etc/systemd/system/lab-netns-$NS.service" <<EOF
[Unit]
Description=Lab 3-020 : espace réseau de $NOM ($ADR)
After=systemd-udevd.service
Before=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/lab-netns $NS $MAC $ADR $GW $DNS $ROUTES

[Install]
WantedBy=multi-user.target
EOF

  # ---------- Commande qui ouvre un shell « sur » le rôle ----------
  cat > "/usr/local/bin/$NOM" <<EOF
#!/usr/bin/env bash
# Ouvre un shell sur $NOM (espace réseau « $NS », ${ADR%/*}). « exit » pour revenir.
U=\$(id -un)
exec sudo ip netns exec $NS unshare --uts sh -c "hostname $NOM; exec sudo -u \$U -i"
EOF
  chmod 755 "/usr/local/bin/$NOM"

  if [ "$ROLE" = interne ]; then
    # NetworkManager ne doit pas toucher la carte SRV : elle part dans l'espace srvint
    install -d /etc/NetworkManager/conf.d
    printf '[keyfile]\nunmanaged-devices=mac:%s\n' "$MAC" > /etc/NetworkManager/conf.d/90-lab-3020.conf
    systemctl reload NetworkManager 2>/dev/null || true

    apt-get update -q
    apt-get install -y -q openssh-server rsyslog mousepad masscan >/dev/null
    echo "[OK] paquets du poste (mousepad, masscan) et openssh-server"

    # Les services de srv-int tournent dans l'espace srvint. SSH sans activation par socket.
    systemctl disable --now ssh.socket >/dev/null 2>&1 || true
    systemctl mask ssh.socket >/dev/null 2>&1 || true
    for s in ssh slapd freeradius rsyslog zabbix-agent; do
      install -d "/etc/systemd/system/$s.service.d"
      cat > "/etc/systemd/system/$s.service.d/50-lab-srvint.conf" <<EOF
# Lab 3-020 à la maison : ce service appartient à srv-int (10.1.20.10)
[Unit]
Requires=lab-netns-srvint.service
After=lab-netns-srvint.service

[Service]
NetworkNamespacePath=/run/netns/srvint
EOF
    done
    systemctl daemon-reload
    systemctl enable --now lab-netns-srvint.service
    systemctl enable ssh.service >/dev/null 2>&1 || true
    systemctl restart ssh.service rsyslog.service
    echo "[OK] SSH et rsyslog tournent dans l'espace de srv-int"
  else
    # ext a son propre serveur SSH, dans l'espace ext
    apt-get install -y -q openssh-server >/dev/null
    cat > /etc/systemd/system/ssh-ext.service <<'EOF'
[Unit]
Description=Lab 3-020 : SSH de ext (10.10.0.40)
Requires=lab-netns-ext.service
After=lab-netns-ext.service

[Service]
NetworkNamespacePath=/run/netns/ext
ExecStartPre=/usr/bin/mkdir -p /run/sshd
ExecStart=/usr/sbin/sshd -D -o PidFile=/run/sshd-ext.pid
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now lab-netns-ext.service
    systemctl enable --now ssh-ext.service
    echo "[OK] SSH de ext actif sur 10.10.0.40"
  fi

  # ---------- Vérifications ----------
  echo "== Vérifications"
  E=0
  if ip -n "$NS" -4 addr show | grep -q "inet $ADR"; then echo "  [OK] $NOM : ${ADR%/*} dans l'espace « $NS »"; else echo "  [KO] adresse ${ADR%/*} absente de l'espace « $NS »"; E=1; fi
  if ip netns exec "$NS" ping -c1 -W2 "$GW" >/dev/null 2>&1; then echo "  [OK] $NOM joint sa passerelle $GW"; else echo "  [KO] $NOM ne joint pas $GW (pfSense démarré ? interface configurée ?)"; E=1; fi
  if ip netns exec "$NS" getent hosts github.com >/dev/null 2>&1; then echo "  [OK] DNS de $NOM"; else echo "  [!!] DNS de $NOM : github.com non résolu (règles « HRA » de pfSense posées ?)"; fi

  echo
  if [ $E -eq 0 ]; then echo "== VM $ROLE prête pour l'installation des logiciels"; else echo "== VM $ROLE : $E point(s) en échec"; fi
  echo "Ensuite (voir maison/README.md) :"
  if [ "$ROLE" = interne ]; then
    echo "  curl -fsSL https://raw.githubusercontent.com/tahero-madi/securite-reseau/main/hexceos/prep.sh | sudo ip netns exec srvint bash"
    echo "  curl -fsSL https://raw.githubusercontent.com/tahero-madi/securite-reseau/main/hexceos/prep.sh | sudo bash"
  else
    echo "  curl -fsSL https://raw.githubusercontent.com/tahero-madi/securite-reseau/main/hexceos/prep.sh | sudo bash"
    echo "  curl -fsSL https://raw.githubusercontent.com/tahero-madi/securite-reseau/main/hexceos/prep.sh | sudo ip netns exec ext bash"
  fi
  echo "Shell sur $NOM : commande « $NOM »."
}

main "$@"
