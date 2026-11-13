#!/usr/bin/env bash
# ext (WAN, 203.0.113.31) : machine « Internet » pour tester la publication (TP 3),
# déclencher Suricata (TP 5) et vérifier l'exposition (TP 8).
set -Eeuo pipefail
trap 'echo "[KO] ext ligne $LINENO : $BASH_COMMAND" >&2' ERR
. /root/lab.conf
export DEBIAN_FRONTEND=noninteractive
apt-get install -y -q nmap testssl.sh ssh-audit
echo "[OK] ext provisionné"
