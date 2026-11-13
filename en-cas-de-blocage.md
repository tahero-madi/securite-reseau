# En cas de blocage

Commencez par `lab statut` : toutes les machines doivent être « running ». Puis cherchez votre symptôme ci-dessous.

| Symptôme | Cause probable | Remède |
| --- | --- | --- |
| Plus rien ne passe entre les machines | Service réseau du laboratoire arrêté | `systemctl status lab-net`, puis `sudo /opt/lab/lab-net.sh start` (relance sans risque) |
| Une machine ne répond plus en SSH | Règle pfSense trop stricte, ou service SSH arrêté | `lab shell <machine>`, puis `ip a` et `sudo systemctl status ssh` ; relire les règles de l'interface concernée |
| Interface web de pfSense inaccessible | Vous vous êtes enfermé dehors (règle anti-verrouillage retirée trop tôt) | `lab console fw` : option 2 pour l'adresse, 3 pour le mot de passe, 4 pour réinitialiser ; ou `lab restaurer <instantané> fw` |
| Une règle pfSense semble sans effet | Ordre des règles, mauvaise interface, ou état déjà établi | Les règles s'évaluent de haut en bas, sur l'interface d'entrée ; *Diagnostics → States* pour supprimer les états existants |
| Greenbone vide ou très lent (TP2) | Flux de vulnérabilités encore en chargement | GSA → *Administration → Feed Status* : attendre que tout soit « Current » |
| `freeradius -X` refuse de démarrer (TP4) | Une autre instance tourne déjà, ou erreur de syntaxe | `sudo systemctl stop freeradius` avant `freeradius -X` ; lire la première ligne d'erreur |
| `Access-Reject` sans raison apparente (TP4) | Secret partagé différent des deux côtés, ou client non déclaré | Comparer le secret dans `clients.conf` et dans pfSense ; vérifier l'adresse source (10.1.20.1) |
| Suricata ne lève aucune alerte (TP5) | `HOME_NET` incorrect, règles non téléchargées, ou trafic chiffré | Vérifier `HOME_NET`, l'onglet des règles, et tester sur le port 80 publié temporairement |
| Règle Suricata personnalisée refusée (TP5) | `sid` en double ou erreur de syntaxe | Donner à chaque règle un `sid` unique (9000001 et suivants, sans doublon) ; lire le journal de l'instance |
| Phase 1 IPsec montée, phase 2 absente (TP6) | Sélecteurs de trafic ou propositions ESP différents | Comparer les deux côtés : réseaux locaux et distants, `esp_proposals` ; `sudo swanctl --list-sas` |
| Le ping passe dans le tunnel, mais pas les transferts (TP6) | MTU réduite par l'encapsulation | Ajuster le MSS TCP (*MSS clamping*) sur le tunnel |
| Aucun journal reçu sur srv-int (TP7) | Flux syslog bloqué par le TP3, ou mauvais protocole | Autoriser UDP/TCP 514 vers 10.1.20.10 ; `sudo ss -tulnp \| grep 514` sur srv-int |
| Zabbix ne remonte rien (TP7) | Flux 10050 ou 10051 fermés, nom d'hôte différent | Ouvrir poste → srv-int TCP 10050 et srv-int → poste TCP 10051 ; le *Host* doit s'appeler exactement `srv-int` |
| Laboratoire entièrement cassé | Configuration corrompue | `lab restaurer <instantané>` ou `lab reset` ; en dernier recours, demander au formateur de réinitialiser la VM depuis la plateforme |

Toujours bloqué ? Notez la commande, le message d'erreur exact et ce que vous attendiez, puis appelez le formateur.

---

[Sommaire](README.md)
