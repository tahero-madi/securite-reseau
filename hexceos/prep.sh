#!/usr/bin/env bash
# =====================================================================
#  Lab 3-020 sur Hexceos : installation des logiciels d'une VM
#  À lancer sur chaque VM, APRÈS reseau.sh :
#    curl -fsSL https://raw.githubusercontent.com/tahero-madi/securite-reseau/main/hexceos/prep.sh | sudo bash
#  La machine est reconnue à son adresse IP. Journal : /var/log/lab-prep.log
#  Le script peut être relancé (il reprend ce qui manque).
# =====================================================================
set -uo pipefail

main() {
  BASE=${LAB_BASE:-https://raw.githubusercontent.com/tahero-madi/securite-reseau/main}
  [ "$(id -u)" -eq 0 ] || { echo "À lancer avec sudo"; exit 1; }

  a_ip() { ip -o -4 addr show | grep -q "inet $1/"; }
  if   a_ip 10.1.10.10; then ROLE=kali;     GW=10.1.10.1
  elif a_ip 10.1.20.10; then ROLE=srv-int;  GW=10.1.20.1
  elif a_ip 10.1.30.10; then ROLE=web;      GW=10.1.30.1
  elif a_ip 10.10.0.30; then ROLE=cloud-gw; GW=10.10.0.1
  elif a_ip 10.10.0.40; then ROLE=ext;      GW=10.10.0.1
  else echo "Machine non reconnue (aucune adresse du lab)"; ip -br a; exit 1
  fi
  echo "== Machine reconnue : $ROLE"

  # Le réseau doit avoir été préparé par reseau.sh (sortie par pfSense)
  if ! ip -4 route show default | grep -q "via $GW "; then
    echo "La route par défaut ne passe pas par $GW : lancez d'abord reseau.sh."
    exit 1
  fi

  LAB_USER=${SUDO_USER:-}
  [ -n "$LAB_USER" ] && [ "$LAB_USER" != root ] || LAB_USER=$(getent passwd 1000 | cut -d: -f1)
  export LAB_USER LAB_BASE=$BASE ROLE

  D=/root/lab-prep
  install -d -m 700 "$D"
  for f in lab.conf roles/commun.sh "roles/$ROLE.sh"; do
    if ! curl -fsSL -o "$D/$(basename "$f")" "$BASE/hexceos/$f"; then
      echo "Téléchargement impossible : $BASE/hexceos/$f"; exit 1
    fi
  done

  echo "== Installation en cours (journal : /var/log/lab-prep.log) — de 5 à 30 minutes selon la machine"
  ( cd "$D" && bash ./commun.sh && bash "./$ROLE.sh" ) </dev/null 2>&1 | tee /var/log/lab-prep.log \
      | grep --line-buffered -E '^(==|\[OK\]|\[!!\]|\[KO\])'
  if grep -q '^\[KO\]' /var/log/lab-prep.log; then
    echo "== $ROLE : échec, voir /var/log/lab-prep.log (fin du journal ci-dessous)"
    tail -n 20 /var/log/lab-prep.log
    exit 1
  fi
  echo "== $ROLE : installation terminée"
}

main "$@"
