#!/usr/bin/env bash
# =====================================================================
#  Lab 3-020 : positionne le mot de passe admin de Greenbone sur une Kali déjà installée
#    curl -fsSL https://raw.githubusercontent.com/tahero-madi/securite-reseau/main/hexceos/greenbone-mdp.sh | sudo bash
#  Si gvmd n'est pas encore prêt, un réessai automatique est programmé (toutes les 2 minutes).
# =====================================================================
set -uo pipefail
main() {
  [ "$(id -u)" -eq 0 ] || { echo "À lancer avec sudo"; exit 1; }
  BASE=${LAB_BASE:-https://raw.githubusercontent.com/tahero-madi/securite-reseau/main}
  D=$(mktemp -d)
  curl -fsSL -o "$D/lab.conf" "$BASE/hexceos/lab.conf" || { echo "lab.conf introuvable"; exit 1; }
  curl -fsSL -o "$D/kali.sh" "$BASE/hexceos/roles/kali.sh" || { echo "kali.sh introuvable"; exit 1; }
  # On n'exécute que la partie « mot de passe » du script de la Kali
  {
    echo 'set -uo pipefail'
    echo ". $D/lab.conf"
    echo 'GB=/opt/greenbone'
    sed -n '/^# Mot de passe admin : gvmd/,/^GSA_URL=/p' "$D/kali.sh" | sed '$d'
  } > "$D/mdp.sh"
  bash "$D/mdp.sh" </dev/null
  rm -rf "$D"
}
main "$@"
