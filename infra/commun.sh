# Fonctions communes aux scripts du kit (sourcé, pas exécuté)
set -Eeuo pipefail

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB=/opt/lab

if [ -f "$LAB/lab.conf" ]; then . "$LAB/lab.conf"; else . "$KIT/lab.conf"; fi

C_OK=$'\e[32m'; C_KO=$'\e[31m'; C_AV=$'\e[33m'; C_T=$'\e[1;36m'; C_0=$'\e[0m'
titre() { printf '\n%s== %s ==%s\n' "$C_T" "$*" "$C_0"; }
info()  { printf '   %s\n' "$*"; }
ok()    { printf '   %s[OK]%s %s\n' "$C_OK" "$C_0" "$*"; }
avert() { printf '   %s[!!]%s %s\n' "$C_AV" "$C_0" "$*"; }
ko()    { printf '   %s[KO]%s %s\n' "$C_KO" "$C_0" "$*"; }
meurt() { ko "$*"; exit 1; }

trap 'ko "Échec ligne $LINENO : $BASH_COMMAND"' ERR

exige_root() { [ "$(id -u)" -eq 0 ] || meurt "Lancez ce script avec sudo."; }

# Utilisateur « humain » de la VM (celui de la session de la console web Hexceos)
utilisateur_bureau() {
  if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != root ]; then echo "$SUDO_USER"; return; fi
  getent passwd 1000 | cut -d: -f1
}

# Interface de sortie Internet de la VM (ens18 chez Hexceos)
uplink() { ip -4 route show default | awk '{print $5; exit}'; }

# Bloc /etc/hosts du lab
hosts_lab() {
  cat <<EOF
# --- lab 3-020 ---
$FW_LAN     fw.$DOMAINE fw
$HOTE_LAN    poste.$DOMAINE poste
$IP_CLIENT    client.$DOMAINE client
$IP_INTRUS    intrus.$DOMAINE intrus
$IP_SRVINT    srv-int.$DOMAINE srv-int
$IP_WEB    web.$DOMAINE web
$IP_CLOUDGW_WAN  cloud-gw.$DOMAINE cloud-gw
$IP_CLOUDGW_VPC    cloud.$DOMAINE cloud
$IP_EXT  ext.$DOMAINE ext
# --- fin lab 3-020 ---
EOF
}

# Attend qu'une commande réussisse (timeout en secondes)
attendre() {
  local t=$1; shift
  for _ in $(seq "$t"); do "$@" >/dev/null 2>&1 && return 0; sleep 1; done
  return 1
}
