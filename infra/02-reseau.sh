#!/usr/bin/env bash
# Étape 2 — Ponts du lab et filtrage de la VM hôte (service lab-net)
. "$(dirname "$0")/commun.sh"
exige_root

titre "Installation du service lab-net"
install -m 755 "$KIT/reseau/lab-net.sh" $LAB/lab-net.sh
install -m 644 "$KIT/reseau/lab-net.service" /etc/systemd/system/lab-net.service
modprobe br_netfilter 2>/dev/null || true
echo br_netfilter > /etc/modules-load.d/lab-3020.conf
systemctl daemon-reload
systemctl enable lab-net.service >/dev/null
systemctl restart lab-net.service
ok "service lab-net actif et lancé à chaque démarrage"

titre "Contrôle rapide"
for br in lab-wan lab-lan lab-srv lab-dmz lab-vpc; do
  ip link show "$br" >/dev/null 2>&1 && ok "pont $br" || ko "pont $br absent"
done
ip -4 addr show lab-lan | grep -q "$HOTE_LAN" && ok "poste : $HOTE_LAN sur lab-lan" || ko "adresse LAN du poste"
ip -4 addr show lab-wan | grep -q "$HOTE_WAN" && ok "routeur FAI : $HOTE_WAN sur lab-wan" || ko "adresse WAN de la VM"
iptables -C FORWARD -j LAB-FWD 2>/dev/null && ok "chaîne LAB-FWD branchée" || ko "LAB-FWD"

# Test de pont identique à celui validé sur la VM Hexceos
titre "Test d'un pont entre deux conteneurs jetables"
lxc launch "$IMAGE_LXD" t-a -q -p lab && lxc launch "$IMAGE_LXD" t-b -q -p lab
for c in t-a t-b; do lxc config device add $c eth0 nic nictype=bridged parent=lab-vpc name=eth0 >/dev/null; done
sleep 4
lxc exec t-a -- sh -c "ip link set eth0 up; ip addr add 10.101.1.201/24 dev eth0"
lxc exec t-b -- sh -c "ip link set eth0 up; ip addr add 10.101.1.202/24 dev eth0"
if lxc exec t-a -- ping -c2 -W3 10.101.1.202 >/dev/null; then ok "pont fonctionnel"; else ko "pont bloqué"; fi
lxc delete -f t-a t-b
