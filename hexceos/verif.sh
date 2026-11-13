#!/usr/bin/env bash
# =====================================================================
#  Lab 3-020 sur Hexceos : vérification d'un environnement, depuis la Kali
#    curl -fsSL https://raw.githubusercontent.com/tahero-madi/securite-reseau/main/hexceos/verif.sh | bash
#  À lancer après prep.sh sur les 5 VM, et AVANT le TP 3 (les règles « tout autoriser »
#  de pfSense doivent encore être en place).
# =====================================================================
set -uo pipefail

main() {
  VERT='\033[32m'; ROUGE='\033[31m'; JAUNE='\033[33m'; RAZ='\033[0m'
  E=0; A=0
  ok()   { echo -e "  ${VERT}[OK]${RAZ} $*"; }
  ko()   { echo -e "  ${ROUGE}[KO]${RAZ} $*"; E=$((E+1)); }
  avert(){ echo -e "  ${JAUNE}[!!]${RAZ} $*"; A=$((A+1)); }
  tcp()  { nc -z -w3 "$1" "$2" >/dev/null 2>&1; }
  port() { if tcp "$2" "$3"; then ok "$1 $2:$3"; else ko "$1 $2:$3 injoignable"; fi; }

  echo "== Routage (tout doit passer par pfSense)"
  [ "$(ip -4 route show default | wc -l)" -eq 1 ] && ip -4 route show default | grep -q 'via 10.1.10.1 ' \
    && ok "route par défaut unique via 10.1.10.1" || ko "route par défaut : $(ip -4 route show default | tr '\n' ';')"
  for d in 10.1.20.10 10.1.30.10 10.10.0.30 10.10.0.40 1.1.1.1; do
    ip route get $d | grep -q 'via 10.1.10.1 ' && ok "$d joint via pfSense" || ko "$d : $(ip route get $d | head -1)"
  done
  getent hosts github.com >/dev/null && ok "DNS (via pfSense)" || ko "DNS : github.com non résolu"
  [ "$(curl -s -o /dev/null -m 8 -w '%{http_code}' https://github.com || true)" != 000 ] && ok "accès Internet" || ko "pas d'accès Internet"

  echo "== pfSense"
  port "interface web" 10.1.10.1 443

  echo "== srv-int (10.1.20.10)"
  for p in 22 389 636 514 10050; do port "srv-int" 10.1.20.10 $p; done
  if command -v ldapsearch >/dev/null; then
    ldapsearch -x -LLL -H ldap://10.1.20.10 -b dc=lab,dc=local uid=alice uid 2>/dev/null | grep -q 'uid: alice' \
      && ok "annuaire LDAP (alice trouvée)" || ko "annuaire LDAP : alice introuvable"
  fi

  echo "== web (10.1.30.10)"
  for p in 21 22 23 80 443; do port "web" 10.1.30.10 $p; done
  tcp 10.1.30.10 3000 && ok "web 10.1.30.10:3000 (Juice Shop)" || avert "Juice Shop (3000) absent : facultatif"
  curl -s -m 5 http://10.1.30.10/dvwa/login.php | grep -qi dvwa && ok "DVWA" || ko "DVWA ne répond pas"
  if command -v snmpget >/dev/null; then
    snmpget -v2c -c public -t 2 -r 1 10.1.30.10 1.3.6.1.2.1.1.5.0 >/dev/null 2>&1 \
      && ok "SNMP v2c « public » (cible héritée)" || ko "SNMP de web ne répond pas"
  fi

  echo "== Machines du WAN"
  port "cloud-gw" 10.10.0.30 22
  port "ext" 10.10.0.40 22

  echo "== Outils du poste"
  if docker compose version >/dev/null 2>&1 || sudo -n docker compose version >/dev/null 2>&1; then ok "docker compose"; else ko "docker compose absent"; fi
  [ "$(curl -s -o /dev/null -m 5 -w '%{http_code}' http://127.0.0.1:8080/ || true)" != 000 ] && ok "Zabbix http://127.0.0.1:8080" || ko "Zabbix ne répond pas"
  if [ "$(curl -s -o /dev/null -m 5 -w '%{http_code}' http://127.0.0.1/ || true)" != 000 ]; then ok "Greenbone http://127.0.0.1"
  elif [ "$(curl -sk -o /dev/null -m 5 -w '%{http_code}' https://127.0.0.1/ || true)" != 000 ]; then ok "Greenbone https://127.0.0.1"
  elif [ "$(curl -s -o /dev/null -m 5 -w '%{http_code}' http://127.0.0.1:9392/ || true)" != 000 ]; then ok "Greenbone http://127.0.0.1:9392"
  else ko "Greenbone (GSA) ne répond pas"; fi
  if [ -f /var/lib/lab-greenbone-mdp.ok ]; then ok "mot de passe admin de Greenbone positionné"
  elif systemctl is-active -q lab-greenbone-mdp.timer 2>/dev/null; then avert "mot de passe admin de Greenbone pas encore positionné (réessai automatique ; en attendant : admin / admin)"
  else avert "mot de passe admin de Greenbone : à vérifier (connexion admin / Greenbone-3020)"; fi
  export PATH="$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/sbin"
  for o in nmap wireshark arpwatch arpspoof radtest testssl.sh ssh-audit snmpwalk ftp; do
    if command -v $o >/dev/null; then ok "$o ($(command -v $o))"
    elif [ $o = testssl.sh ] && command -v testssl >/dev/null; then avert "testssl.sh absent, mais testssl présent : sudo ln -sf $(command -v testssl) /usr/local/bin/testssl.sh"
    else avert "$o absent"; fi
  done
  # Les fichiers sont dans le dossier de l'utilisateur, même si le script est lancé avec sudo
  HU=$HOME
  if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != root ]; then HU=$(getent passwd "$SUDO_USER" | cut -d: -f6); fi
  for f in identifiants-lab.txt tp1-arp-demo.pcap tp1-ftp-clear.pcap tp7-incident.pcap mandat-audit-TP8.pdf; do
    [ -s "$HU/TP/$f" ] && ok "$HU/TP/$f" || ko "$HU/TP/$f manquant"
  done

  echo
  if [ $E -eq 0 ]; then echo -e "${VERT}== Environnement prêt ($A avertissement(s))${RAZ}"
  else echo -e "${ROUGE}== $E point(s) en échec, $A avertissement(s)${RAZ}"; fi
  echo "Rappel : le flux Greenbone doit être « Current » (GSA → Administration → Feed Status) avant l'instantané."
}

main "$@"
