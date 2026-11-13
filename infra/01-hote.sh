#!/usr/bin/env bash
# Étape 1 — Préparation de la VM hôte (le « poste » de l'apprenant)
# Paquets, groupes, LXD, libvirt, Docker, outils du poste.
. "$(dirname "$0")/commun.sh"
exige_root
U=$(utilisateur_bureau)

titre "Contrôles préalables"
. /etc/os-release
[ "${VERSION_ID:-}" = "24.04" ] && ok "Ubuntu $VERSION_ID" || avert "Ubuntu 24.04 attendu (trouvé : ${PRETTY_NAME:-?})"
[ -e /dev/kvm ] && ok "/dev/kvm présent (virtualisation imbriquée)" || meurt "/dev/kvm absent : demandez à Hexceos d'activer la virtualisation imbriquée."
RAM=$(awk '/MemTotal/{print int($2/1024/1024+0.5)}' /proc/meminfo)
CPU=$(nproc)
DISQUE=$(df -BG --output=avail / | tail -1 | tr -dc 0-9)
[ "$RAM" -ge 15 ] && ok "RAM : ${RAM} Go" || avert "RAM : ${RAM} Go (16 Go minimum, 24 recommandés)"
[ "$CPU" -ge 8 ]  && ok "vCPU : $CPU"     || avert "vCPU : $CPU (8 recommandés)"
[ "$DISQUE" -ge 90 ] && ok "Disque libre : ${DISQUE} Go" || avert "Disque libre : ${DISQUE} Go (100 Go conseillés)"
UP=$(uplink); [ -n "$UP" ] || meurt "Pas de route par défaut."
NET_UP=$(ip -4 -o addr show dev "$UP" | awk '{print $4; exit}')
ok "Sortie Internet : $UP ($NET_UP)"
python3 - "$NET_UP" <<'PY' || meurt "Le réseau de la VM chevauche un réseau du lab : ajustez lab.conf."
import ipaddress, sys
up = ipaddress.ip_interface(sys.argv[1]).network
for n in ["203.0.113.0/24","10.1.10.0/24","10.1.20.0/24","10.1.30.0/24","10.101.1.0/24"]:
    if up.overlaps(ipaddress.ip_network(n)): sys.exit(1)
PY
ok "Aucun chevauchement d'adresses avec le lab"

titre "Mises à jour automatiques désactivées (évite les verrous apt pendant les TP)"
systemctl disable --now unattended-upgrades.service apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true
ok "fait"

titre "Paquets"
export DEBIAN_FRONTEND=noninteractive
echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections
apt-get update -q
apt-get install -y -q \
  qemu-system-x86 qemu-utils libvirt-daemon-system libvirt-clients virtinst virt-viewer virt-manager \
  bridge-utils iptables wireshark tshark tcpdump nmap arpwatch netcat-openbsd \
  ldap-utils freeradius-utils eapoltest tnftp telnet curl openssh-client \
  testssl.sh ssh-audit python3-scapy jq openssl git gzip whois dnsutils
command -v ftp >/dev/null || ln -sf /usr/bin/tnftp /usr/local/bin/ftp
if ! docker compose version >/dev/null 2>&1; then
  apt-get install -y -q docker.io docker-compose-v2
fi
systemctl enable --now docker libvirtd
ok "paquets installés"

titre "LXD"
if ! command -v lxc >/dev/null; then snap install lxd; fi
snap refresh lxd --channel=6/stable >/dev/null 2>&1 || true
lxd waitready --timeout=120
if ! lxc storage show default >/dev/null 2>&1; then
  cat <<EOF | lxd init --preseed
config: {}
networks:
- name: lxdbr0
  type: bridge
  config: {ipv4.address: 10.250.0.1/24, ipv4.nat: "true", ipv6.address: none}
storage_pools:
- name: default
  driver: btrfs
  config: {size: ${LXD_POOL_GO}GiB}
profiles:
- name: default
  devices:
    root: {path: /, pool: default, type: disk}
    eth0: {name: eth0, network: lxdbr0, type: nic}
EOF
  ok "LXD initialisé (pool btrfs ${LXD_POOL_GO} Go, lxdbr0 réservé à l'installation)"
else
  ok "LXD déjà initialisé"
fi
lxc profile show lab >/dev/null 2>&1 || lxc profile create lab
lxc profile device add lab root disk path=/ pool=default >/dev/null 2>&1 || true
ok "profil « lab » (disque seul, cartes ajoutées par conteneur)"

titre "libvirt"
virsh net-destroy default >/dev/null 2>&1 || true
virsh net-autostart default --disable >/dev/null 2>&1 || true
ok "réseau libvirt « default » désactivé (le lab utilise ses propres ponts)"

titre "Utilisateur $U"
for g in lxd libvirt kvm wireshark docker; do getent group $g >/dev/null && usermod -aG $g "$U"; done
ok "$U ajouté aux groupes lxd, libvirt, kvm, wireshark, docker"

titre "Fichiers du lab dans $LAB"
install -d -m 755 $LAB $LAB/TP $LAB/conteneurs
install -m 600 "$KIT/lab.conf" $LAB/lab.conf
install -m 644 "$KIT/commun.sh" $LAB/commun.sh
cp -r "$KIT"/conteneurs/. $LAB/conteneurs/
install -m 755 "$KIT/bin/lab" /usr/local/bin/lab
sed -i '/# --- lab 3-020 ---/,/# --- fin lab 3-020 ---/d' /etc/hosts
hosts_lab >> /etc/hosts
ok "outil « lab » installé, /etc/hosts complété"

titre "Fichiers de TP"
install -d -o "$U" -g "$U" "/home/$U/TP"
cp -r "$KIT"/TP/. "/home/$U/TP/" 2>/dev/null || true
chown -R "$U:$U" "/home/$U/TP"
cat > "/home/$U/TP/identifiants-lab.txt" <<EOF
Identifiants initiaux du lab 3-020 (à changer pendant les TP)
--------------------------------------------------------------
Machines du lab (SSH)   stagiaire / $PW_STAGIAIRE   (sudo)
pfSense                 https://$FW_LAN            admin / $PW_PFSENSE
Greenbone (GSA)         voir « lab urls »          admin / $PW_GREENBONE
Zabbix                  http://127.0.0.1:8080      Admin / zabbix
LDAP (admin)            cn=admin,dc=lab,dc=local   $PW_LDAP_ADMIN
LDAP (service RADIUS)   cn=svc-radius,ou=services,dc=lab,dc=local   $PW_SVC_RADIUS
Utilisateurs LDAP       alice / $PW_ALICE (admins) · bob / $PW_BOB · carol / $PW_CAROL
FTP en clair (web)      ftpdemo / $PW_FTPDEMO
DVWA                    http://$IP_WEB/dvwa/       admin / password
EOF
rm -f "/home/$U/TP/generer_captures.py"
chown -R "$U:$U" "/home/$U/TP"
ok "captures, mandat d'audit et identifiants copiés dans /home/$U/TP"

titre "Autorité de certification du lab"
PKI=$LAB/pki; install -d -m 755 $PKI
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
  emettre srv-int  srv-int.$DOMAINE  "DNS:srv-int.$DOMAINE,DNS:srv-int,IP:$IP_SRVINT" serverAuth
  emettre radius   radius.$DOMAINE   "DNS:radius.$DOMAINE,DNS:srv-int.$DOMAINE" serverAuth
  emettre web      web.$DOMAINE      "DNS:web.$DOMAINE,DNS:web,IP:$IP_WEB,IP:$FW_WAN" serverAuth
  emettre cloud    cloud.$DOMAINE    "DNS:cloud.$DOMAINE,IP:$IP_CLOUDGW_VPC" serverAuth
  emettre alice    alice             "email:alice@$DOMAINE" clientAuth
  chmod 600 $PKI/*.key
fi
cp $PKI/ca.crt /usr/local/share/ca-certificates/lab-3020.crt && update-ca-certificates >/dev/null
install -d -o "$U" -g "$U" "/home/$U/pki"
cp $PKI/ca.crt $PKI/alice.crt "/home/$U/pki/"; cp $PKI/alice.key "/home/$U/pki/"
chown -R "$U:$U" "/home/$U/pki"; chmod 600 "/home/$U/pki/alice.key"
ok "AC du lab créée et approuvée par le poste (certificat client alice dans ~/pki)"

titre "Étape 1 terminée"
info "Déconnectez/reconnectez la session de $U pour prendre en compte les groupes."
