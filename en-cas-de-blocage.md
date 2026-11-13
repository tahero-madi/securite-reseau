# En cas de blocage

Commencez par vérifier, dans le portail, que les 6 machines sont « En marche ». Puis cherchez votre symptôme ci-dessous.

| Symptôme | Cause probable | Remède |
| --- | --- | --- |
| La Kali n'a plus accès à rien | Route ou adresse perdue | `ip -br a` et `ip route` : il faut `10.1.10.10/24` sur `eth1` et une seule route `default via 10.1.10.1`. Sinon, relancer `curl -fsSL https://raw.githubusercontent.com/tahero-madi/securite-reseau/main/hexceos/reseau.sh \| sudo bash` (demander au formateur si la Kali n'a plus Internet) |
| Une machine ne répond plus en SSH | Règle pfSense trop stricte, ou service SSH arrêté | Ouvrir sa console dans le portail, puis `ip -br a`, `ip route` et `sudo systemctl status ssh` ; relire les règles de l'interface concernée |
| Interface web de pfSense inaccessible | Vous vous êtes enfermé dehors (règle anti-verrouillage retirée trop tôt) | Console de pfSense dans le portail : option 8 (shell) puis `pfctl -d` pour couper le filtrage le temps de corriger, `pfctl -e` pour le remettre ; ou restaurer l'instantané de pfSense |
| Une règle pfSense semble sans effet | Ordre des règles, mauvaise interface, ou état déjà établi | Les règles s'évaluent de haut en bas, sur l'interface d'entrée ; *Diagnostics → States* pour supprimer les états existants |
| Plus aucun nom ne se résout | DNS vers pfSense bloqué par vos règles | Autoriser UDP/TCP 53 vers l'adresse de pfSense sur chaque interface ; tester avec `getent hosts github.com` |
| Un test de filtrage passe alors qu'il devrait être refusé | Trafic qui contourne pfSense | `traceroute -n <destination>` depuis la source : le premier saut doit être pfSense (10.1.x.1 ou 10.10.0.20). Sinon, une route a été modifiée : appeler le formateur |
| Greenbone vide ou très lent (TP2) | Flux de vulnérabilités encore en chargement | GSA → *Administration → Feed Status* : attendre que tout soit « Current » |
| La Kali rame pendant un scan (TP2) | Mémoire saturée par Greenbone | Arrêter Zabbix pendant le TP2 : `sudo docker compose -f /opt/zabbix/compose.yaml stop` (le relancer avec `start` au TP7) |
| `freeradius -X` refuse de démarrer (TP4) | Une autre instance tourne déjà, ou erreur de syntaxe | `sudo systemctl stop freeradius` avant `freeradius -X` ; lire la première ligne d'erreur |
| `Access-Reject` sans raison apparente (TP4) | Secret partagé différent des deux côtés, ou client non déclaré | Comparer le secret dans `clients.conf` et dans pfSense ; vérifier l'adresse source (10.1.20.1) |
| LDAPS refuse la connexion depuis la Kali (TP4) | Certificat d'AC non fourni, ou mauvais nom | `LDAPTLS_CACERT=~/pki/ca-lab.crt` et le nom `srv-int.lab.local` |
| Suricata ne lève aucune alerte (TP5) | `HOME_NET` contient le WAN, règles non téléchargées, ou trafic chiffré | Vérifier que *Home Net* = la Pass List `lab_home` (10.1.0.0/16 seulement), l'onglet des règles, et tester sur le port 80 publié temporairement |
| Règle Suricata personnalisée refusée (TP5) | `sid` en double ou erreur de syntaxe | Donner à chaque règle un `sid` unique (9000001 et suivants, sans doublon) ; lire le journal de l'instance |
| Phase 1 IPsec montée, phase 2 absente (TP6) | Sélecteurs de trafic ou propositions ESP différents | Comparer les deux côtés : réseaux locaux et distants, `esp_proposals` ; `sudo swanctl --list-sas` |
| Tunnel monté, mais srv-int ne joint pas 10.101.1.1 (TP6) | Règle manquante sur l'interface SRV de pfSense, ou ESP refusé par nftables | Autoriser srv-int → 10.101.1.1 sur SRV ; sur cloud-gw, `ip protocol esp accept` avant le refus |
| Le ping passe dans le tunnel, mais pas les transferts (TP6) | MTU réduite par l'encapsulation | Ajuster le MSS TCP (*MSS clamping*) sur le tunnel |
| Aucun journal reçu sur srv-int (TP7) | Flux syslog bloqué par le TP3, ou mauvais protocole | Autoriser UDP/TCP 514 vers 10.1.20.10 depuis la DMZ ; `sudo ss -tulnp \| grep 514` sur srv-int |
| Zabbix ne remonte rien (TP7) | Flux 10050, 10051 ou 161 fermés, nom d'hôte différent | Ouvrir Kali → srv-int TCP 10050, srv-int → Kali TCP 10051, Kali → pfSense UDP 161 ; le *Host* doit s'appeler exactement `srv-int` |
| Laboratoire entièrement cassé | Configuration corrompue | Restaurer l'instantané de la machine concernée depuis le portail ; en dernier recours, demander au formateur de recréer l'environnement |

Toujours bloqué ? Notez la commande, le message d'erreur exact et ce que vous attendiez, puis appelez le formateur.

---

[Sommaire](README.md)
