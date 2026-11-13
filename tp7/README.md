# TP7 — Supervision, journalisation et analyse d'incident

**Jour 4, 09:40 · 2 h 20, pause incluse.** Objectifs : centraliser les journaux (pfSense + serveurs → rsyslog) ; superviser avec Zabbix (dont SNMPv3) ; analyser une capture d'intrusion avec Wireshark ; rédiger une fiche d'incident.

**Prérequis** : module 7, TP précédents. **Livrable** (dans `~/livrables`) : preuve de centralisation des journaux, un tableau de bord / déclencheur Zabbix fonctionnel, une `fiche-incident` complétée à partir de la capture fournie.

## Partie A — Journalisation centralisée (30 min)

1. Sur `srv-int` (`ssh formation@10.1.20.10`), le service **rsyslog** joue le collecteur central : il range les messages reçus dans un fichier par machine, sous `/var/log/remote/`. Vérifiez qu'il écoute (UDP et TCP 514 ; TLS 6514 en défi) :

```bash
sudo ss -tulnp | grep -E '514|6514'
```

2. Configurez `fw` pour envoyer ses journaux : *Status → System Logs → Settings → Remote Logging*, serveur `10.1.20.10:514`, sélectionnez *Firewall events* et *System events*. Le message part de l'interface SRV de pfSense (10.1.20.1).
3. Configurez `web` pour relayer son syslog vers le collecteur, en TCP :

```bash
echo '*.* @@10.1.20.10:514' | sudo tee /etc/rsyslog.d/90-forward.conf
sudo systemctl restart rsyslog
```

Ce flux DMZ → SRV doit être autorisé par une règle précise sur l'interface DMZ de pfSense (`H_web` → `H_srv_int` TCP 514) : c'est typiquement le « flux justifié » de votre matrice du TP 3. `cloud-gw`, lui, est hors du site : ses journaux restent chez le « fournisseur » (journal de flux local du TP 6), comme les Flow Logs d'un vrai cloud.
4. Générez des événements (un refus de pare-feu depuis une source interdite, une connexion SSH). Sur `srv-int`, vérifiez leur arrivée :

```bash
sudo tail -f /var/log/remote/*.log
```

Montrez qu'un refus pfSense et un événement serveur apparaissent, horodatés, au même endroit.

> **Horloge.** Vérifiez que toutes les machines sont à l'heure (NTP) et en UTC. Un écart d'horloge rend la corrélation fausse. Sur chaque machine Linux : `timedatectl` (ligne *System clock synchronized: yes*) ; `srv-int` et `web` prennent l'heure sur pfSense, qui la prend lui-même sur Internet : vérifiez-la dans *Status → NTP*. Si une machine n'est pas synchronisée, vérifiez que votre matrice du TP 3 autorise bien NTP (UDP 123) vers pfSense.

## Partie B — Supervision Zabbix (35 min)

5. Ouvrez l'interface Zabbix, hébergée sur votre Kali : `http://127.0.0.1:8080` (compte `Admin` / `zabbix`). Changez le mot de passe `Admin`. Comme Greenbone, le serveur Zabbix est vu du réseau comme le poste `10.1.10.10`.
6. **SNMPv3 sur pfSense** : le service SNMP intégré de pfSense ne parle que v1/v2c. Installez le paquet **NET-SNMP** (*System → Package Manager*), puis dans *Services → SNMP (NET-SNMP)* créez un utilisateur v3 dédié, niveau *authPriv*, SHA + AES, en lecture seule ; limitez l'écoute à l'interface LAN et l'accès à l'adresse du superviseur `10.1.10.10`. Ne laissez aucune communauté v1/v2c active. Côté filtrage, autorisez sur l'interface LAN `H_poste_admin → LAN address` en UDP 161. Testez depuis la Kali : `snmpwalk -v3 -l authPriv -u <utilisateur> -a SHA -A <mdp> -x AES -X <mdp> 10.1.10.1 system`.
7. Dans Zabbix : créez un *Host* `fw`, interface SNMP (v3, mêmes paramètres), associez un template SNMP. Vérifiez la remontée (interfaces, trafic). Créez un *Host* nommé exactement `srv-int` (le nom déclaré dans la configuration de son agent), interface agent `10.1.20.10:10050`, template *Linux by Zabbix agent active*. Deux flux sont nécessaires à travers pfSense : Kali → srv-int TCP 10050 (interrogation) et srv-int → Kali `10.1.10.10` TCP 10051 (agent actif). Ajoutez-les à vos règles si le TP 3 les a fermés.
8. Créez un **trigger** utile pour la sécurité : par exemple, surveillance du log des échecs d'authentification (item de type *Zabbix agent (active)*, clé `log[/var/log/auth.log,"Failed password"]`, type d'information *Log*) qui déclenche une alerte au-delà d'un seuil, ou l'alerte « interface down », ou « nouvel hôte détecté ».
9. Provoquez la condition (plusieurs `ssh` en échec vers `srv-int`) et vérifiez le passage du trigger en *Problem*.

> **Défi ★.** Créez un graphe combinant le trafic WAN de pfSense et le nombre d'alertes Suricata (via un item personnalisé lisant le compteur d'alertes). Objectif : visualiser une corrélation entre pic de trafic et pic d'alertes.

## Partie C — Analyse d'une capture d'intrusion (40 min)

La capture `~/TP/tp7-incident.pcap` a été prise par la **sonde de la DMZ** (port miroir de `web`) d'une PME dont l'architecture ressemble à la vôtre, la nuit d'un incident. À l'époque, `web` était publié sur Internet par un NAT 1:1 (adresse publique 203.0.113.12, tous ports). Analysez-la **méthodiquement** avec Wireshark (horaires en UTC : *View → Time Display Format → UTC Date and Time of Day*).

10. **Vue d'ensemble** : *Statistics → Protocol Hierarchy*, puis *Conversations*. Repérez les hôtes qui parlent le plus, les protocoles inhabituels.
11. **Reconstituer la chronologie** :
    - Y a-t-il une phase de **reconnaissance** (balayage : beaucoup de SYN sans réponse) ? Filtre `tcp.flags.syn==1 && tcp.flags.ack==0`.
    - Une **exploitation** ou un accès à un service exposé ? Suivez les flux HTTP (`http.request`), cherchez des URI suspectes, des codes de réponse anormaux.
    - Des **identifiants en clair** ? Filtres `ftp`, `http.authorization`, `telnet`.
    - Un **canal sortant** / une balise ? Connexions régulières vers une même destination externe ; requêtes DNS anormalement longues (`dns.qry.name`).
    - Une **exfiltration** ? Volumes sortants, transfert de fichier (*Export Objects*).
12. Reliez vos observations aux **tactiques ATT&CK** (reconnaissance, accès initial, C2, exfiltration) et dressez une chronologie horodatée.

## Partie D — Fiche d'incident (25 min)

13. Rédigez `fiche-incident` selon le modèle du module 7 : identifiant/date, détection, périmètre (hôtes, données), **chronologie horodatée**, techniques ATT&CK, actions de confinement proposées (quelles règles pare-feu ? quel isolement ?), éradication, rétablissement, indicateurs de compromission relevés (IP, domaines, URI), et obligations de notification éventuelles.

**Livrable** (dans `~/livrables`) : preuve de centralisation (capture d'écran des logs agrégés), trigger Zabbix en *Problem*, `fiche-incident`.

## Questions de validation

1. Pourquoi centraliser les journaux hors des machines qui les produisent ?
2. Quel filtre Wireshark met en évidence un balayage TCP SYN ?
3. Dans la capture, quel élément vous ferait conclure à un canal de commande (C2) plutôt qu'à du trafic légitime ?

---

[← TP6](../tp6/README.md) · [Sommaire](../README.md) · [Corrigé](corrige/README.md) · [En cas de blocage](../en-cas-de-blocage.md) · [TP8 →](../tp8/README.md)
