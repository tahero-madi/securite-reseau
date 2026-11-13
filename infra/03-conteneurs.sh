#!/usr/bin/env bash
# Étape 3 — Conteneurs LXD du lab
#   sudo ./03-conteneurs.sh            -> crée ceux qui manquent
#   sudo ./03-conteneurs.sh web        -> (re)crée seulement « web »
#   sudo ./03-conteneurs.sh --force    -> recrée tout
# Chaque conteneur est installé sur lxdbr0 (accès Internet direct), puis basculé sur
# les ponts du lab avec son adresse fixe.
. "$(dirname "$0")/commun.sh"
exige_root
lxc profile show lab >/dev/null 2>&1 || meurt "Lancez d'abord 01-hote.sh"
ip link show lab-lan >/dev/null 2>&1 || meurt "Lancez d'abord 02-reseau.sh"

FORCE=0; CIBLES=()
for a in "$@"; do [ "$a" = --force ] && FORCE=1 || CIBLES+=("$a"); done
[ ${#CIBLES[@]} -gt 0 ] || read -r -a CIBLES <<< "$CONTENEURS"

# --- Définition des machines --------------------------------------------
# cartes : "pont:adresse:mac" (eth0, eth1…) ; passerelle ; DNS
declare -A CARTES PASS DNS
CARTES[srv-int]="lab-srv:$IP_SRVINT:00:16:3e:30:20:10"; PASS[srv-int]=$FW_SRV; DNS[srv-int]=$FW_SRV
CARTES[web]="lab-dmz:$IP_WEB:00:16:3e:30:20:30";        PASS[web]=$FW_DMZ;     DNS[web]=$FW_DMZ
CARTES[client]="lab-lan:$IP_CLIENT:00:16:3e:30:20:20";  PASS[client]=$FW_LAN;  DNS[client]=$FW_LAN
CARTES[intrus]="lab-lan:$IP_INTRUS:00:16:3e:30:20:66";  PASS[intrus]=$FW_LAN;  DNS[intrus]=$FW_LAN
CARTES[ext]="lab-wan:$IP_EXT:00:16:3e:30:20:31";        PASS[ext]=$HOTE_WAN;   DNS[ext]=$DNS_AMONT
CARTES[cloud-gw]="lab-wan:$IP_CLOUDGW_WAN:00:16:3e:30:20:21 lab-vpc:$IP_CLOUDGW_VPC:00:16:3e:30:20:a1"
PASS[cloud-gw]=$HOTE_WAN; DNS[cloud-gw]=$DNS_AMONT

declare -A PKI_FICHIERS
PKI_FICHIERS[srv-int]="ca.crt srv-int.crt srv-int.key radius.crt radius.key alice.crt alice.key"
PKI_FICHIERS[web]="web.crt web.key"
PKI_FICHIERS[cloud-gw]="cloud.crt cloud.key"

netplan_de() { # nom
  local n=$1 i=0 c pont ipa
  echo "network:"; echo "  version: 2"; echo "  renderer: networkd"; echo "  ethernets:"
  for c in ${CARTES[$n]}; do
    pont=${c%%:*}; ipa=$(echo "$c" | cut -d: -f2)
    echo "    eth$i:"
    echo "      addresses: [$ipa/24]"
    if [ $i -eq 0 ]; then
      echo "      routes: [{to: default, via: ${PASS[$n]}}]"
      echo "      nameservers: {addresses: [$(echo ${DNS[$n]} | sed 's/ /, /g')], search: [$DOMAINE]}"
    fi
    i=$((i+1))
  done
}

install -d $LAB/logs
# Toujours partir des scripts du kit (une correction du kit est prise en compte sans relancer 01)
install -d $LAB/conteneurs && cp -r "$KIT"/conteneurs/. $LAB/conteneurs/
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
hosts_lab > "$TMP/hosts.lab"

provisionner() {
  local n=$1
  titre "Conteneur $n"
  [ -n "${CARTES[$n]:-}" ] || { ko "machine inconnue : $n"; return 1; }
  if lxc info "$n" >/dev/null 2>&1; then
    if [ "$EXPLICITE" -eq 0 ]; then ok "existe déjà (le nommer ou --force pour le recréer)"; return 0; fi
    lxc delete -f "$n"
  fi

  local opts=()
  if [ "$n" = cloud-gw ]; then
    opts=(-c security.privileged=true -c linux.kernel_modules=esp4,esp6,xfrm_user,xfrm_algo,xfrm4_tunnel,af_key,nf_tables)
  fi
  info "création (image $IMAGE_LXD, réseau d'installation lxdbr0)…"
  lxc launch "$IMAGE_LXD" "$n" -q "${opts[@]}"
  attendre 180 lxc exec "$n" -- getent hosts archive.ubuntu.com || meurt "$n : pas d'accès Internet sur lxdbr0"

  netplan_de "$n" > "$TMP/10-lab.yaml"
  lxc file push -q $LAB/lab.conf "$n/root/lab.conf"
  lxc file push -q $LAB/pki/ca.crt "$n/root/ca.crt"
  lxc file push -q "$TMP/hosts.lab" "$n/root/hosts.lab"
  lxc file push -q "$TMP/10-lab.yaml" "$n/root/10-lab.yaml"
  lxc file push -q $LAB/conteneurs/commun.sh "$n/root/commun.sh"
  lxc file push -q "$LAB/conteneurs/$n.sh" "$n/root/role.sh"
  if [ -n "${PKI_FICHIERS[$n]:-}" ]; then
    lxc exec "$n" -- install -d -m 700 /root/pki
    for f in ${PKI_FICHIERS[$n]}; do lxc file push -q "$LAB/pki/$f" "$n/root/pki/$f"; done
  fi

  info "installation des logiciels (journal : $LAB/logs/$n.log)…"
  if ! lxc exec "$n" -- bash -c 'bash /root/commun.sh && bash /root/role.sh' > "$LAB/logs/$n.log" 2>&1; then
    tail -n 15 "$LAB/logs/$n.log"; meurt "$n : échec de l'installation"
  fi
  grep -E '^\[(OK|!!)\]' "$LAB/logs/$n.log" | sed 's/^/   /'
  lxc exec "$n" -- rm -f /root/commun.sh /root/role.sh /root/10-lab.yaml /root/hosts.lab /root/ca.crt

  info "bascule sur les ponts du lab…"
  lxc stop "$n"
  lxc profile assign "$n" lab
  local i=0 c pont mac
  for c in ${CARTES[$n]}; do
    pont=${c%%:*}; mac=$(echo "$c" | cut -d: -f3-)
    local hn="v-$n"; [ $i -gt 0 ] && hn="v-$n$i"
    lxc config device add "$n" "eth$i" nic nictype=bridged parent="$pont" name="eth$i" \
        host_name="$hn" hwaddr="$mac" >/dev/null
    i=$((i+1))
  done
  lxc config set "$n" boot.autostart true
  lxc start "$n"
  sleep 3
  ok "$n : $(echo ${CARTES[$n]} | sed -E 's/:[0-9a-f]{2}(:[0-9a-f]{2}){5}//g')"
}

# Recréation si l'on nomme des conteneurs ou avec --force ; sinon on ne crée que les absents
EXPLICITE=$FORCE; for a in "$@"; do [ "$a" != --force ] && EXPLICITE=1; done
for n in "${CIBLES[@]}"; do provisionner "$n"; done

titre "Étape 3 terminée"
lxc list -c ns4 --format compact
info "Tant que pfSense n'est pas installé (étape 5), les conteneurs n'ont pas d'accès Internet : c'est normal."
