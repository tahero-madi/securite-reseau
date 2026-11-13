#!/usr/bin/env bash
# intrus (LAN, 10.1.10.66) : poste compromis utilisé par le formateur pour la
# démonstration encadrée d'usurpation ARP du TP 1 (commande « lab demo-arp »).
set -Eeuo pipefail
trap 'echo "[KO] intrus ligne $LINENO : $BASH_COMMAND" >&2' ERR
. /root/lab.conf
export DEBIAN_FRONTEND=noninteractive
apt-get install -y -q dsniff nmap
echo "[OK] intrus provisionné"
