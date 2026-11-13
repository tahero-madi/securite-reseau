#!/usr/bin/env bash
# Vérification du lab (à lancer sur le modèle avant l'instantané, puis sur chaque clone avant J1)
. "$(dirname "$0")/commun.sh"
exige_root
trap - ERR; set +e
export LIBVIRT_DEFAULT_URI=qemu:///system
NB_KO=0
t() { # description commande… (réussite attendue)
  local d=$1; shift
  if "$@" >/dev/null 2>&1; then ok "$d"; else ko "$d"; NB_KO=$((NB_KO+1)); fi
}
tn() { # description commande… (ÉCHEC attendu : chemin censé être fermé)
  local d=$1; shift
  if "$@" >/dev/null 2>&1; then ko "$d (ouvert alors qu'il devrait être fermé)"; NB_KO=$((NB_KO+1)); else ok "$d"; fi
}
dans() { local m=$1; shift; lxc exec "$m" -- "$@"; }
http() { curl -sk -m 8 -o /dev/null -w '%{http_code}' "$1" | grep -qE '^(2|3)'; }

titre "VM hôte"
t "service lab-net actif"                 systemctl is-active lab-net
t "ponts lab-wan/lan/srv/dmz/vpc"         bash -c 'for b in lab-wan lab-lan lab-srv lab-dmz lab-vpc; do ip link show $b >/dev/null || exit 1; done'
t "Internet depuis le poste"               curl -sI -m 8 https://archive.ubuntu.com

titre "pfSense (fw)"
t "VM fw démarrée"                         bash -c 'virsh domstate fw | grep -q running'
t "LAN 10.1.10.1 répond"                   ping -c1 -W2 $FW_LAN
t "interface web https://10.1.10.1"        http https://$FW_LAN

titre "Conteneurs"
for c in $CONTENEURS; do
  t "$c démarré" bash -c "lxc list '^$c\$' -c s --format csv | grep -q RUNNING"
done
t "srv-int joignable (via fw)"             ping -c1 -W2 $IP_SRVINT
t "web joignable (via fw)"                 ping -c1 -W2 $IP_WEB
t "client joignable (LAN)"                 ping -c1 -W2 $IP_CLIENT
t "cloud-gw joignable (WAN)"               ping -c1 -W2 $IP_CLOUDGW_WAN
t "ext joignable (WAN)"                    ping -c1 -W2 $IP_EXT

titre "Services"
for p in 22 389 636; do t "srv-int tcp/$p" nc -zw3 $IP_SRVINT $p; done
t "srv-int FreeRADIUS actif"               dans srv-int systemctl is-active freeradius
t "srv-int rsyslog écoute 514"             bash -c "lxc exec srv-int -- ss -lntu | grep -q ':514 '"
t "LDAPS + compte svc-radius"              ldapsearch -x -H ldaps://srv-int.$DOMAINE -D "cn=svc-radius,ou=services,dc=lab,dc=local" -w "$PW_SVC_RADIUS" -b "ou=people,dc=lab,dc=local" "(uid=alice)" uid
for p in 21 22 23 80 443; do t "web tcp/$p" nc -zw3 $IP_WEB $p; done
t "web DVWA"                               http http://$IP_WEB/dvwa/login.php
if nc -zw3 $IP_WEB 3000; then ok "web Juice Shop (3000)"; else avert "web Juice Shop (3000) absent ou en démarrage (non bloquant)"; fi
t "cloud-gw : service cloud local"         dans cloud-gw curl -sk -m5 -o /dev/null https://$IP_CLOUDGW_VPC
t "cloud-gw : swanctl présent"             dans cloud-gw swanctl --version

titre "Sorties Internet via pfSense"
t "client → Internet"                      dans client curl -sI -m 8 https://archive.ubuntu.com
t "srv-int → DNS via pfSense"              dans srv-int getent hosts archive.ubuntu.com
t "ext → Internet (FAI)"                   dans ext curl -sI -m 8 https://archive.ubuntu.com

titre "Cloisonnement imposé par la VM hôte"
tn "ext ne joint pas le poste (10.1.10.10)"         dans ext nc -zw3 $HOTE_LAN 22
tn "ext ne joint pas srv-int en direct"             dans ext nc -zw3 $IP_SRVINT 22
tn "ext ne joint pas la VM hôte (203.0.113.254)"    dans ext nc -zw3 $HOTE_WAN 22
tn "web ne joint pas la VM hôte côté WAN"          dans web nc -zw3 $HOTE_WAN 22

titre "Outils"
t "Zabbix web http://127.0.0.1:8080"       http http://127.0.0.1:8080
t "Zabbix : srv-int → 10.1.10.10:10051"    dans srv-int nc -zw3 $HOTE_LAN 10051
GSA=$(cat $LAB/gsa.url 2>/dev/null || echo http://127.0.0.1:9392)
t "Greenbone GSA $GSA"                     http "$GSA"
t "Docker → DMZ (scanner → web:80)"        docker run --rm --network zabbix_default busybox nc -zw3 $IP_WEB 80
info "Flux Greenbone : vérifier dans GSA → Administration → Feed Status (tout « Current »)."

titre "Bilan"
if [ $NB_KO -eq 0 ]; then ok "lab conforme"; else ko "$NB_KO point(s) à corriger"; fi
exit $NB_KO
