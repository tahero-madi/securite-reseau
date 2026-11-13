#!/usr/bin/env bash
# Réseau du lab : 5 ponts Linux + adresses du poste + filtrage de la VM hôte.
# Lancé à chaque démarrage par lab-net.service (avant Docker, LXD et libvirt).
#
#   lab-wan  203.0.113.0/24  « Internet » simulé : fw (WAN), cloud-gw, ext, et la VM (.254, routeur FAI)
#   lab-lan  10.1.10.0/24    LAN : fw (LAN), le poste (= la VM, .10), client, intrus
#   lab-srv  10.1.20.0/24    SRV : fw (OPT1), srv-int
#   lab-dmz  10.1.30.0/24    DMZ : fw (OPT2), web
#   lab-vpc  10.101.1.0/24   VPC « cloud » : cloud-gw (côté privé)
#
# Principe de filtrage de la VM hôte : elle ne route RIEN entre les zones du lab
# (c'est le rôle de pfSense). Elle fait seulement :
#   - le « fournisseur d'accès » : lab-wan -> Internet, avec NAT ;
#   - l'accès de Greenbone/Zabbix (Docker) aux zones, sous l'adresse du poste.
set -euo pipefail
. /opt/lab/lab.conf

UP=$(ip -4 route show default | awk '{print $5; exit}')

cmd=${1:-start}
if [ "$cmd" = stop ]; then
  iptables -D FORWARD -j LAB-FWD 2>/dev/null || true
  iptables -D INPUT -j LAB-IN 2>/dev/null || true
  iptables -t nat -D POSTROUTING -s "$NET_WAN" -o "$UP" -j MASQUERADE 2>/dev/null || true
  exit 0
fi

# --- Ponts --------------------------------------------------------------
for br in lab-wan lab-lan lab-srv lab-dmz lab-vpc; do
  ip link show "$br" >/dev/null 2>&1 || ip link add "$br" type bridge
  ip link set "$br" type bridge stp_state 0
  ip link set "$br" up
done
ip addr replace "$HOTE_WAN/24" dev lab-wan
ip addr replace "$HOTE_LAN/24" dev lab-lan

# Le poste joint les autres zones en passant par pfSense (comme un vrai poste du LAN)
for n in "$NET_SRV" "$NET_DMZ" "$NET_VPC"; do
  ip route replace "$n" via "$FW_LAN" dev lab-lan
done

sysctl -qw net.ipv4.ip_forward=1
sysctl -qw net.ipv6.conf.lab-wan.disable_ipv6=1 net.ipv6.conf.lab-lan.disable_ipv6=1 \
           net.ipv6.conf.lab-srv.disable_ipv6=1 net.ipv6.conf.lab-dmz.disable_ipv6=1 \
           net.ipv6.conf.lab-vpc.disable_ipv6=1

# --- Transit (FORWARD) --------------------------------------------------
iptables -N LAB-FWD 2>/dev/null || true
iptables -F LAB-FWD
# 1. Trames commutées à l'intérieur d'un pont (br_netfilter) : on laisse passer.
#    Sans cette règle, la politique DROP de Docker bloque le trafic entre machines d'un même segment.
iptables -A LAB-FWD -m physdev --physdev-is-bridged -j ACCEPT
# 2. lxdbr0 (réseau d'installation des conteneurs) : sortie Internet.
iptables -A LAB-FWD -i lxdbr0 -j ACCEPT
iptables -A LAB-FWD -o lxdbr0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
# 3. « FAI » : le WAN simulé sort vers Internet, jamais vers les réseaux privés de la plateforme.
iptables -A LAB-FWD -i lab-wan -o "$UP" -d 10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,100.64.0.0/10 -j DROP
iptables -A LAB-FWD -i lab-wan -o "$UP" -j ACCEPT
iptables -A LAB-FWD -i "$UP" -o lab-wan -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
# 4. Outils Docker (Greenbone, Zabbix) -> zones du lab, via pfSense, sous l'adresse du poste.
iptables -A LAB-FWD -o lab-lan -s 172.16.0.0/12 -j ACCEPT
iptables -A LAB-FWD -i lab-lan -d 172.16.0.0/12 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
# 5. Agents Zabbix actifs (srv-int, etc.) -> serveur Zabbix publié sur 10.1.10.10:10051
iptables -A LAB-FWD -i lab-lan -d 172.16.0.0/12 -p tcp --dport 10051 -m conntrack --ctstate DNAT -j ACCEPT
# 6. Tout autre transit touchant le lab est refusé (pas de raccourci autour de pfSense).
iptables -A LAB-FWD -i lab-+ -j DROP
iptables -A LAB-FWD -o lab-+ -j DROP
iptables -C FORWARD -j LAB-FWD 2>/dev/null || iptables -I FORWARD 1 -j LAB-FWD

# --- Entrant vers la VM hôte depuis le lab (INPUT) -----------------------
iptables -N LAB-IN 2>/dev/null || true
iptables -F LAB-IN
iptables -A LAB-IN -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A LAB-IN -p icmp -j ACCEPT
iptables -A LAB-IN -i lab-wan -j DROP          # rien depuis « Internet » vers le poste
iptables -A LAB-IN -i lab-vpc -j DROP
iptables -A LAB-IN -i lab-srv -j DROP
iptables -A LAB-IN -i lab-dmz -j DROP
iptables -A LAB-IN -i lab-lan -j DROP
iptables -C INPUT -j LAB-IN 2>/dev/null || iptables -I INPUT 1 -j LAB-IN

# --- NAT du « FAI » ------------------------------------------------------
iptables -t nat -C POSTROUTING -s "$NET_WAN" -o "$UP" -j MASQUERADE 2>/dev/null \
  || iptables -t nat -A POSTROUTING -s "$NET_WAN" -o "$UP" -j MASQUERADE

echo "lab-net : ponts et filtrage en place (sortie $UP)"
