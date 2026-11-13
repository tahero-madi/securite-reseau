#!/usr/bin/env bash
# Installation complète du modèle (étapes 1 à 4), puis instructions pour pfSense (étape 5)
#   sudo ./install.sh
set -e
D="$(cd "$(dirname "$0")" && pwd)"
[ "$(id -u)" -eq 0 ] || { echo "Lancez : sudo $0"; exit 1; }
bash "$D/01-hote.sh"
bash "$D/02-reseau.sh"
bash "$D/03-conteneurs.sh"
bash "$D/04-outils.sh"
cat <<FIN

== Étapes 1 à 4 terminées ==
Reste à faire :
  5. sudo ./05-pfsense.sh <netgate-installer-amd64.iso.gz>   puis   pfsense/INSTALLATION-pfsense.md
  6. sudo ./99-verif.sh
  7. sudo lab instantane initial
FIN
