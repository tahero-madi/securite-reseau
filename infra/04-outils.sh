#!/usr/bin/env bash
# Étape 4 — Outils de sécurité sur la VM hôte (Docker) : Greenbone Community Edition et Zabbix 7.0
. "$(dirname "$0")/commun.sh"
exige_root

titre "Zabbix 7.0"
install -d $LAB/zabbix
install -m 644 "$KIT/outils/zabbix-compose.yaml" $LAB/zabbix/compose.yaml
printf 'PW_ZABBIX_DB=%s\n' "$PW_ZABBIX_DB" > $LAB/zabbix/.env; chmod 600 $LAB/zabbix/.env
docker compose -f $LAB/zabbix/compose.yaml --env-file $LAB/zabbix/.env pull -q
docker compose -f $LAB/zabbix/compose.yaml --env-file $LAB/zabbix/.env up -d
ok "Zabbix démarré : http://127.0.0.1:8080 (Admin / zabbix)"

titre "Greenbone Community Edition"
GB=/opt/greenbone; install -d $GB
curl -fsSL https://greenbone.github.io/docs/latest/_static/compose.yaml -o $GB/compose.yaml \
  || meurt "Téléchargement du compose Greenbone impossible"
GBC=(docker compose -f $GB/compose.yaml -p greenbone-community-edition)
"${GBC[@]}" pull -q
"${GBC[@]}" up -d
info "attente de gvmd (création automatique du compte admin)…"
admin_present() { "${GBC[@]}" exec -T -u gvmd gvmd gvmd --get-users 2>/dev/null | grep -qx admin; }
if attendre 900 admin_present; then
  "${GBC[@]}" exec -T -u gvmd gvmd gvmd --user=admin --new-password="$PW_GREENBONE" >/dev/null
else
  "${GBC[@]}" exec -T -u gvmd gvmd gvmd --create-user=admin --password="$PW_GREENBONE" >/dev/null
fi
ok "compte admin Greenbone positionné"
# Adresse de la console GSA selon la version du compose (affichée par « lab urls »)
if grep -qE '127\.0\.0\.1:443:' $GB/compose.yaml; then GSA_URL="https://127.0.0.1"
else GSA_URL="http://127.0.0.1:9392"; fi
echo "$GSA_URL" > $LAB/gsa.url
ok "console GSA : $GSA_URL"
info "Le flux de vulnérabilités se charge en arrière-plan (30 min à 2 h selon le débit)."

titre "Étape 4 terminée"
info "Vérifiez dans GSA (Administration → Feed Status) que tous les flux sont « Current »"
info "AVANT de prendre l'instantané final du modèle."
