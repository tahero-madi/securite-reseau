#!/usr/bin/env bash
# =====================================================================
#  Lab 3-020 sur Hexceos : route par défaut et DNS via pfSense
#  À lancer sur chaque VM (Kali, srv-int, web, cloud-gw, ext) :
#    curl -fsSL https://raw.githubusercontent.com/tahero-madi/securite-reseau/main/hexceos/reseau.sh | sudo bash
#  La machine est reconnue à son adresse IP. Le script peut être relancé.
# =====================================================================
set -uo pipefail

main() {
[ "$(id -u)" -eq 0 ] || { echo "À lancer avec sudo"; exit 1; }

VERT='\033[32m'; ROUGE='\033[31m'; RAZ='\033[0m'
ok() { echo -e "  ${VERT}[OK]${RAZ} $*"; }
ko() { echo -e "  ${ROUGE}[KO]${RAZ} $*"; ERREURS=$((ERREURS+1)); }
ERREURS=0

# carte qui porte une adresse commençant par $1
carte() { ip -o -4 addr show | awk -v p="$1" 'index($4, p) == 1 {print $2; exit}'; }
a_ip() { ip -o -4 addr show | grep -q "inet $1/"; }

if   a_ip 10.1.10.10; then ROLE=kali
elif a_ip 10.1.20.10; then ROLE=srv-int
elif a_ip 10.1.30.10; then ROLE=web
elif a_ip 10.10.0.30; then ROLE=cloud-gw
elif a_ip 10.10.0.40; then ROLE=ext
else echo "Machine non reconnue (aucune adresse du lab)"; ip -br a; exit 1
fi
echo "== Machine reconnue : $ROLE"

# ---------------------------------------------------------------------
#  Ubuntu : netplan fixe, cloud-init ne touche plus au réseau, IPv6 coupé
# ---------------------------------------------------------------------
config_ubuntu() {
  local IF=$1 IP=$2 GW=$3 DNS=$4 VERS_PFSENSE=$5
  echo 'network: {config: disabled}' > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg 2>/dev/null || true

  mkdir -p /root/netplan-origine
  for f in /etc/netplan/*.yaml; do
    [ -e "$f" ] || continue
    [ "$(basename "$f")" = "50-lab.yaml" ] && continue
    mv "$f" /root/netplan-origine/
  done

  {
    echo "network:"
    echo "  version: 2"
    echo "  ethernets:"
    echo "    $IF:"
    echo "      dhcp4: false"
    echo "      dhcp6: false"
    echo "      accept-ra: false"
    echo "      addresses: [$IP/24]"
    echo "      routes:"
    echo "        - {to: default, via: $GW}"
    [ "$VERS_PFSENSE" = oui ] && echo "        - {to: 10.1.0.0/16, via: 10.10.0.20}"
    echo "      nameservers: {addresses: [$DNS]}"
  } > /etc/netplan/50-lab.yaml
  chmod 600 /etc/netplan/50-lab.yaml

  cat > /etc/sysctl.d/90-lab-ipv6.conf <<EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF
  sysctl -q --system >/dev/null 2>&1 || true

  netplan apply
  sleep 3
}

# ---------------------------------------------------------------------
#  Kali : LAN fixe derrière pfSense, carte WAN coupée (y compris au démarrage)
# ---------------------------------------------------------------------
config_kali() {
  local LIF WIF C0 C1
  LIF=$(carte 10.1.10.)
  WIF=$(carte 10.10.0.); WIF=${WIF:-eth0}
  C1=$(nmcli -g GENERAL.CONNECTION dev show "$LIF")
  C0=$(nmcli -g GENERAL.CONNECTION dev show "$WIF" 2>/dev/null || true); [ "$C0" = "--" ] && C0=""
  echo "  LAN : $LIF ($C1)   WAN : $WIF (${C0:-déjà coupée})"

  nmcli con mod "$C1" ipv4.method manual ipv4.addresses 10.1.10.10/24 \
       ipv4.gateway 10.1.10.1 ipv4.dns 10.1.10.1 ipv4.ignore-auto-dns yes \
       ipv4.ignore-auto-routes yes ipv6.method disabled
  nmcli con up "$C1" >/dev/null

  if [ -n "$C0" ]; then
    nmcli con mod "$C0" connection.autoconnect no
    nmcli dev disconnect "$WIF" >/dev/null
  fi
  sleep 3
}

case $ROLE in
  kali)     config_kali ;;
  srv-int)  config_ubuntu "$(carte 10.1.20.)" 10.1.20.10 10.1.20.1 10.1.20.1 non ;;
  web)      config_ubuntu "$(carte 10.1.30.)" 10.1.30.10 10.1.30.1 10.1.30.1 non ;;
  cloud-gw) config_ubuntu "$(carte 10.10.0.)" 10.10.0.30 10.10.0.1  10.10.0.1 oui ;;
  ext)      config_ubuntu "$(carte 10.10.0.)" 10.10.0.40 10.10.0.1  10.10.0.1 oui ;;
esac

# ---------------------------------------------------------------------
#  Vérifications
# ---------------------------------------------------------------------
echo "== Vérifications"
case $ROLE in
  kali)     GW=10.1.10.1 ;;
  srv-int)  GW=10.1.20.1 ;;
  web)      GW=10.1.30.1 ;;
  *)        GW=10.10.0.1 ;;
esac

NB_DEF=$(ip -4 route show default | wc -l)
if [ "$NB_DEF" -eq 1 ] && ip -4 route show default | grep -q "via $GW "; then
  ok "une seule route par défaut, via $GW"
else
  ko "route par défaut : $(ip -4 route show default | tr '\n' ';')"
fi

if ip -4 route | grep -q '\.254'; then ko "il reste une route vers .254"; else ok "plus aucune route vers .254"; fi

case $ROLE in
  kali|srv-int|web)
    if ip route get 10.10.0.40 | grep -q "via $GW "; then ok "le WAN est joint via pfSense ($GW)"; else ko "le WAN n'est pas joint via pfSense : $(ip route get 10.10.0.40 | head -1)"; fi ;;
  cloud-gw|ext)
    if ip route get 10.1.30.10 | grep -q "via 10.10.0.20 "; then ok "les réseaux internes sont joints via pfSense (10.10.0.20)"; else ko "réseaux internes : $(ip route get 10.1.30.10 | head -1)"; fi ;;
esac

if getent hosts github.com >/dev/null; then ok "DNS : github.com est résolu"; else ko "DNS : github.com n'est pas résolu (pfSense : DNS Resolver en Forwarding ?)"; fi

CODE=$(curl -s -o /dev/null -m 8 -w '%{http_code}' https://github.com || true)
if [ "$CODE" != "000" ] && [ -n "$CODE" ]; then ok "Internet : https://github.com répond ($CODE)"; else ko "Internet : pas de réponse de https://github.com (NAT sortant de pfSense ?)"; fi

echo
ip -br a | grep -v '^lo'
ip -4 route
echo
if [ "$ERREURS" -eq 0 ]; then
  echo -e "${VERT}== $ROLE : configuration réseau OK${RAZ}"
else
  echo -e "${ROUGE}== $ROLE : $ERREURS vérification(s) en échec${RAZ}"
fi
}

main "$@"
