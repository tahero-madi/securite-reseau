# En cas de blocage

Commencez par vérifier, dans le portail, que les 6 machines sont « En marche ». Puis cherchez votre symptôme ci-dessous.

| Symptôme | Cause probable | Remède |
| --- | --- | --- |
| La Kali n'a plus accès à rien | Route ou adresse perdue | `ip -br a` et `ip route` : il faut `10.1.10.10/24` sur `eth0` et une seule route `default via 10.1.10.1`. Sinon, relancer `curl -fsSL https://raw.githubusercontent.com/tahero-madi/securite-reseau/main/hexceos/reseau.sh \| sudo bash` (demander au formateur si la Kali n'a plus Internet) |
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
| Suricata ne lève aucune alerte (TP5) | `HOME_NET` mal défini, règles non téléchargées, instance non redémarrée, ou trafic chiffré | *Home Net* = la Pass List `lab_home` (alias `N_LAB` : 10.1.0.0/16 **et** 10.10.0.20, sans les réseaux auto-générés) ; onglet *Updates* ; redémarrer l'instance ; tester sur le port 80 publié temporairement |
| La session SSH vers `ext` se fige, `ext` ne joint plus rien (TP5) | `ext` bloqué par Suricata en mode IPS | *Services → Suricata → Blocks* : supprimer `10.10.0.40` ; repasser *Block Offenders* décoché en fin de TP |
| Règle Suricata personnalisée refusée (TP5) | `sid` en double ou erreur de syntaxe | Donner à chaque règle un `sid` unique (9000001 et suivants, sans doublon) ; lire le journal de l'instance |
| Phase 1 IPsec montée, phase 2 absente (TP6) | Sélecteurs de trafic ou propositions ESP différents | Comparer les deux côtés : réseaux locaux et distants, `esp_proposals` ; `sudo swanctl --list-sas` |
| Tunnel monté, mais srv-int ne joint pas 10.101.1.1 (TP6) | Règle S6 absente ou sous S5 | S6 (`H_srv_int` → `H_vpc_app`, `P_cloud`) au-dessus de S5 ; le refus apparaît dans *Status → System Logs → Firewall* sur l'interface SRV |
| Phase 1 refusée : `NO_PROPOSAL_CHOSEN` ou `AUTHENTICATION_FAILED` (TP6) | Algorithmes différents, ou clé et identités différentes | *Status → System Logs → IPsec* ; comparer AES256-GCM 128 bits, SHA256, groupe 19 des deux côtés, la clé, *My/Peer IP address* |
| La connexion s'ouvre dans le tunnel, mais les transferts bloquent (TP6) | MTU réduite par l'encapsulation | Ajuster le MSS TCP (*MSS clamping*) sur le tunnel |
| Aucun journal de `web` reçu sur srv-int (TP7) | Règle D5 absente ou sous D4, ou envoi en UDP (`@`) au lieu de TCP (`@@`) | D5 : `H_web` → `H_srv_int` TCP 514, au-dessus de D4 ; `@@10.1.20.10:514` sur `web` ; `sudo ss -tulnp \| grep 514` sur srv-int |
| Zabbix ne remonte rien (TP7) | Flux 10050, 10051 ou 161 fermés, nom d'hôte différent | Ouvrir Kali → srv-int TCP 10050, srv-int → Kali TCP 10051, Kali → pfSense UDP 161 ; le *Host* doit s'appeler exactement `srv-int` |
| Laboratoire entièrement cassé | Configuration corrompue | Restaurer l'instantané de la machine concernée depuis le portail ; en dernier recours, demander au formateur de recréer l'environnement |

Toujours bloqué ? Notez la commande, le message d'erreur exact et ce que vous attendiez, puis appelez le formateur.

---

[Sommaire](README.md)
