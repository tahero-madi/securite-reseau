# TP7 — Supervision et journalisation

**Jour 4, 09:40 · 1 h 15.** Objectifs : centraliser les journaux de pfSense et des serveurs sur un collecteur rsyslog ; superviser pfSense en SNMPv3 et `srv-int` par agent avec Zabbix ; créer une alerte utile à la sécurité et vérifier qu'elle se déclenche.

**Prérequis** : module 7, TP3 terminé (règles L4 et S4 : flux de l'agent Zabbix), TP5 conseillé (alertes Suricata envoyées au journal système). **Livrable** : preuve de centralisation des journaux, alerte Zabbix déclenchée, dans `~/livrables`.

**Déroulé** : étapes 1 à 5 (journalisation centralisée) 30 min · étapes 6 à 11 (supervision Zabbix) 45 min.

> **Instantané conseillé.** Avant de commencer, prenez un instantané de pfSense depuis le portail (par exemple `avant-tp7`).

## Étape 1 — Vérifier le collecteur

**Pourquoi.** Un attaquant qui prend la main sur une machine efface ses traces dans les journaux de cette machine. Envoyés au fil de l'eau vers un collecteur séparé, les journaux échappent à cet effacement, et tous les événements se retrouvent au même endroit, ce qui permet de les corréler. Sur `srv-int`, le service rsyslog joue ce rôle de collecteur.

Depuis la Kali :

```bash
ssh formation@10.1.20.10
sudo ss -tulnp | grep ':514 '
cat /etc/rsyslog.d/10-collecteur.conf
```

**Ligne par ligne.**

- `ssh formation@10.1.20.10` : session sur `srv-int` (règle L4). Les commandes suivantes s'exécutent sur `srv-int`.
- `sudo ss -tulnp` : liste les ports en écoute, TCP (`-t`) et UDP (`-u`), en écoute seulement (`-l`), sans traduire les numéros en noms (`-n`), avec le programme qui les tient (`-p`, d'où `sudo`).
- `| grep ':514 '` : ne garde que le port 514, celui de syslog. Vous devez voir deux lignes, `udp` et `tcp`, tenues par `rsyslogd`.
- `cat /etc/rsyslog.d/10-collecteur.conf` : affiche la configuration du collecteur. Repérez :
  - `module(load="imudp")` et `module(load="imtcp")` : réception en UDP et en TCP ;
  - `template(name="ParHote" … "/var/log/remote/%HOSTNAME%.log")` : un fichier par machine émettrice, nommé d'après le nom qu'elle donne dans ses messages ;
  - `ruleset(name="distant") { … stop }` : les messages reçus du réseau sont rangés dans ces fichiers, et seulement là (ils ne se mélangent pas aux journaux de `srv-int` lui-même).

Gardez cette session ouverte.

## Étape 2 — Envoyer les journaux de pfSense

**Pourquoi.** pfSense est la source la plus riche du laboratoire : refus et autorisations du pare-feu, alertes Suricata (TP5), négociations IPsec (TP6), connexions à l'interface d'administration (TP4).

*Status → System Logs → Settings*, section *Remote Logging Options* :

| Champ | Valeur |
|---|---|
| *Enable Remote Logging* | coché |
| *Source Address* | `SRV` (affiché parfois `OPT1`) |
| *IP Protocol* | `IPv4` |
| *Remote log servers* | `10.1.20.10:514` |
| *Remote Syslog Contents* | `Everything` |

Puis, plus haut sur la même page, section *General Logging Options* :

| Champ | Valeur |
|---|---|
| *Log Message Format* | `syslog (RFC 5424, with RFC 3339 microsecond-precision timestamps)` |

*Save*.

**Ligne par ligne.**

- *Source Address* `SRV` : pfSense envoie ses journaux depuis son adresse sur le réseau SRV (10.1.20.1), la plus proche du collecteur.
- *Remote log servers* : le collecteur, port 514 ; pfSense émet en UDP.
- *Everything* : tous les journaux, dont le pare-feu, Suricata, IPsec et les authentifications.
- *Log Message Format* RFC 5424 : chaque message porte le nom de pfSense et une heure **avec son fuseau** (`+01:00`). Le format par défaut (BSD, RFC 3164) n'envoie ni l'un ni l'autre. Le collecteur nomme alors le fichier d'après l'adresse émettrice (`_gateway.log` : c'est le nom que `srv-int` donne à sa passerelle par défaut), et il lit l'heure locale de pfSense comme si c'était l'heure UTC, d'où une heure d'écart en hiver. Exactement le problème de corrélation de l'étape 4.

Le trafic émis par pfSense lui-même n'est pas soumis aux règles de l'interface SRV : aucune règle à ajouter.

## Étape 3 — Envoyer les journaux de `web`

**Pourquoi.** Le serveur exposé est la cible la plus probable : ses journaux (connexions SSH, services) doivent quitter la machine au plus vite. Ce flux traverse la frontière DMZ → SRV : c'est exactement le type de « flux justifié » qu'une matrice de flux doit décrire, et qu'une règle précise doit autoriser.

Dans pfSense, *Firewall → Rules → DMZ* (affiché parfois `OPT2`), *Add* (flèche vers le haut) :

| Champ | Valeur |
|---|---|
| *Action* | `Pass` |
| *Protocol* | `TCP` |
| *Source* | `Address or Alias` : `H_web` |
| *Destination* | `Address or Alias` : `H_srv_int` |
| *Destination Port Range* | `514` |
| *Description* | `D5 Journaux de web vers le collecteur` |

*Save*. Vérifiez que D5 est **au-dessus** de D4, puis *Apply Changes*. Ajoutez D5 à votre matrice de flux.

Puis, depuis un second terminal de la Kali :

```bash
ssh formation@10.1.30.10
echo '*.* @@10.1.20.10:514' | sudo tee /etc/rsyslog.d/90-forward.conf
sudo systemctl restart rsyslog
logger -p auth.warning "TP7 test de transfert depuis web"
```

**Ligne par ligne.**

- `ssh formation@10.1.30.10` : session sur `web` (règle L4).
- `echo '*.* @@10.1.20.10:514'` : une règle rsyslog : `*.*` = tous les messages, de toutes origines et de toutes gravités ; `@@` = envoyer en **TCP** (un seul `@` signifierait UDP) ; vers le collecteur, port 514.
- `| sudo tee /etc/rsyslog.d/90-forward.conf` : écrit cette ligne dans un fichier de configuration de rsyslog (`tee` sous `sudo`, car le dossier appartient à `root`).
- `sudo systemctl restart rsyslog` : recharge rsyslog avec la nouvelle règle.
- `logger -p auth.warning "…"` : écrit un message de test dans le journal local, catégorie `auth`, gravité `warning` ; rsyslog le transfère aussitôt.

TCP plutôt qu'UDP : en UDP, un message perdu l'est sans que personne le sache ; en TCP, l'émetteur sait si le collecteur a reçu. `cloud-gw`, lui, est hors du site : ses journaux restent « chez le fournisseur », comme dans un vrai cloud.

## Étape 4 — Vérifier les horloges

**Pourquoi.** Corréler, c'est mettre bout à bout des événements venus de machines différentes. Si une horloge a deux minutes d'écart, la chronologie est fausse, et une preuve horodatée peut être contestée. Toutes les machines doivent être synchronisées sur la même source.

Sur `srv-int` puis sur `web` :

```bash
timedatectl
```

**Ligne par ligne.**

- `timedatectl` : affiche l'état de l'horloge. Vérifiez :
  - `System clock synchronized: yes` : l'horloge est synchronisée par NTP ;
  - `NTP service: active` : le service de synchronisation tourne ;
  - `Time zone` : le fuseau ; une différence de fuseau n'est pas un écart d'horloge, mais elle complique la lecture : en analyse d'incident, on raisonne en UTC.

Dans pfSense, *Status → NTP* : au moins un serveur doit avoir l'état *Active Peer* (ou *Candidate*).

> **Si une machine n'est pas synchronisée** : `srv-int` et `web` prennent l'heure sur pfSense ; vérifiez que les règles S2 et D2 du TP3 (UDP 123 vers pfSense) sont bien en place.

## Étape 5 — Retrouver les événements au même endroit

**Pourquoi.** On provoque deux événements de nature différente (un refus du pare-feu, une tentative de connexion sur un serveur) et on vérifie qu'ils arrivent tous les deux, horodatés, sur le collecteur.

Dans un terminal de la Kali :

```bash
nc -vz -w 3 10.1.30.10 21
ssh -o PubkeyAuthentication=no inconnu@10.1.30.10
```

**Ligne par ligne.**

- `nc -vz -w 3 10.1.30.10 21` : tente le port FTP de `web`. Aucune règle du LAN ne l'autorise : refus journalisé par L10.
- `ssh -o PubkeyAuthentication=no inconnu@10.1.30.10` : tente une connexion SSH sur `web` avec un compte qui n'existe pas. Tapez un mot de passe quelconque, puis `Ctrl+C`.

Sur `srv-int` :

```bash
sudo ls -l /var/log/remote/
sudo grep -h 'filterlog' /var/log/remote/*.log | grep ',10.1.10.10,10.1.30.10,' | tail -n 3
sudo grep -h -e 'inconnu' -e 'TP7' /var/log/remote/web.log | tail -n 5
```

**Ligne par ligne.**

- `sudo ls -l /var/log/remote/` : un fichier par machine émettrice : `web.log`, et pour pfSense un fichier à son nom d'hôte (par exemple `pfSense.home.arpa.log`). Un fichier `_gateway.log` contient les messages reçus avant le passage au format RFC 5424.
- `sudo grep -h 'filterlog' /var/log/remote/*.log` : les lignes du filtre de pfSense, dans tous les fichiers du collecteur.
- `| grep ',10.1.10.10,10.1.30.10,'` : seulement celles dont la source est la Kali et la destination `web`. Les champs sont séparés par des virgules : numéro de règle, sous-numéro, ancre, identifiant de la règle (*tracker*), carte réseau, `match`, `block` ou `pass`, sens, version IP, … puis protocole, source, destination, ports. Repérez `block`, `10.1.10.10`, `10.1.30.10` et le port `21`.
- `| tail -n 3` : seulement les trois dernières.
- `sudo grep -h -e 'inconnu' -e 'TP7' /var/log/remote/web.log` : les lignes de `web` contenant `inconnu` (`Invalid user inconnu from 10.1.10.10`) ou le message de test de l'étape 3.

Vous verrez sans doute aussi des refus de `10.1.30.10` vers une adresse d'Internet, port 443 : c'est `web` qui tente de sortir (mises à jour automatiques, par exemple), et le filtrage sortant de la DMZ l'en empêche. C'est le comportement voulu, et une bonne question pour un analyste : quel programme, sur `web`, essaie de sortir ?

Capturez l'écran : un refus du pare-feu et un événement de `web`, horodatés, au même endroit. C'est votre preuve de centralisation.

## Étape 6 — Ouvrir Zabbix

**Pourquoi.** Les journaux racontent ce qui s'est passé ; la supervision dit, en continu, si tout va bien, et alerte dès que ce n'est plus le cas. Zabbix tourne sur votre Kali, dans des conteneurs ; vu du réseau, il a l'adresse de la Kali, `10.1.10.10`.

Dans un terminal de la Kali :

```bash
docker compose -f /opt/zabbix/compose.yaml ps
```

- `docker compose … ps` : liste les conteneurs de Zabbix (base de données, serveur, interface web). Les trois doivent être à l'état `running` (ou `Up`).

Ouvrez Firefox sur `http://127.0.0.1:8080`, connectez-vous avec `Admin` / `zabbix`. Changez aussitôt ce mot de passe : *User settings → Profile → Change password*. Un mot de passe par défaut sur un outil de supervision, qui connaît toutes les machines et parfois leurs secrets, est un constat d'audit majeur.

## Étape 7 — SNMPv3 sur pfSense

**Pourquoi.** SNMP permet d'interroger un équipement (interfaces, trafic, charge). Les versions 1 et 2c s'authentifient par une simple « communauté » qui circule en clair, souvent `public`. Seule la version 3, au niveau *authPriv*, authentifie l'interrogateur et chiffre les échanges. Le service SNMP intégré de pfSense ne parle que v1/v2c : il faut le paquet **NET-SNMP**.

1. *Services → SNMP* (le service intégré, sans « NET-SNMP » dans le nom) : *Enable* doit être **décoché** ; s'il est coché, décochez-le et cliquez sur *Save*. Ce service, `bsnmpd`, ne parle que v1/v2c et occuperait le port 161 : l'agent NET-SNMP ne pourrait pas démarrer.
2. *System → Package Manager → Available Packages* : installez **NET-SNMP** (une minute environ).
3. *Services → SNMP (NET-SNMP)*. Le paquet a deux parties : **snmpd**, l'agent qui répond aux interrogations (c'est lui qu'on configure), et **snmptrapd**, qui reçoit des alertes SNMP (*traps*) d'autres équipements (inutile ici, à laisser désactivé). Si la page affiche *SNMP Trap Daemon Configuration*, vous êtes dans la seconde : cliquez sur l'onglet *[SNMP Daemon]*. Dans la partie snmpd :
   - onglet *General* : cochez *Enable snmpd* ; dans *Interface Binding*, une seule ligne : *Transport Type* `UDP`, *IP Address/Hostname* `10.1.10.1`, *Port* `161` ; *Save* ;
   - onglet *Host Information* : *Location* `Labo 3-020`, *Contact* votre nom ; *Save* ;
   - onglet *Users*, *Add* : *Username* `zbx-ro`, *Entry Type* `User Entry (USM)`, *Read/Write Access* `Read Only`, *Authentication Type* `SHA`, *Password* `Zbx-Auth-3020`, *Privacy Protocol* `AES`, *Passphrase* `Zbx-Priv-3020`, *Min USM Security Level* `Private (Encryption Required)` ; *Save* ;
   - onglet *Communities* : la liste doit rester **vide**.
4. *Firewall → Rules → LAN*, *Add* (flèche vers le haut) : *Pass*, *Protocol* `UDP`, *Source* `H_poste_admin`, *Destination* `LAN address`, port `161`, *Description* `L11 Supervision SNMPv3 de pfSense`. Vérifiez que L11 est au-dessus de L10, *Save*, *Apply Changes*.

**Ligne par ligne.**

- *Interface Binding* `UDP` `10.1.10.1` `161` : l'agent n'écoute que sur l'adresse LAN de pfSense, port 161.
- Utilisateur `zbx-ro`, `Read Only` : un compte dédié à la supervision, qui ne peut rien modifier.
- *Min USM Security Level* `Private` : l'agent refuse toute requête de cet utilisateur qui ne serait pas à la fois authentifiée et chiffrée (*authPriv*).
- `SHA` et son mot de passe : authentification de l'interrogateur (HMAC-SHA).
- `AES` et sa phrase secrète : chiffrement des échanges.
- Aucune communauté : ni v1 ni v2c.
- Écoute sur l'adresse LAN seulement, règle L11 depuis `H_poste_admin` seulement : le service n'est joignable que depuis le superviseur.

Testez depuis un terminal de la Kali :

```bash
snmpwalk -v3 -l authPriv -u zbx-ro -a SHA -A 'Zbx-Auth-3020' -x AES -X 'Zbx-Priv-3020' 10.1.10.1 system
snmpwalk -v2c -c public -t 2 -r 0 10.1.10.1 system
```

**Ligne par ligne.**

- `snmpwalk` : parcourt une branche de l'arbre SNMP de l'équipement.
- `-v3` : version 3.
- `-l authPriv` : niveau de sécurité « authentifié et chiffré ».
- `-u zbx-ro` : le nom d'utilisateur.
- `-a SHA -A '…'` : protocole et mot de passe d'authentification.
- `-x AES -X '…'` : protocole et phrase secrète de chiffrement.
- `10.1.10.1 system` : l'adresse LAN de pfSense, et la branche `system` (nom, description, durée de fonctionnement, emplacement, contact).
- `snmpwalk -v2c -c public -t 2 -r 0 …` : la même question en v2c avec la communauté `public`, délai de 2 secondes (`-t 2`), sans nouvel essai (`-r 0`). Résultat attendu : `Timeout: No Response`.

## Étape 8 — Superviser pfSense dans Zabbix

**Pourquoi.** On déclare pfSense dans Zabbix avec les mêmes paramètres SNMPv3 ; Zabbix l'interrogera toutes les minutes et tracera l'état et le trafic de ses interfaces.

Dans Zabbix, *Data collection → Hosts → Create host* :

| Champ | Valeur |
|---|---|
| *Host name* | `pfSense` |
| *Templates* | `PFSense by SNMP` |
| *Host groups* | `Lab` (tapez le nom, puis *(new)*) |
| *Interfaces* | *Add* → `SNMP` : `10.1.10.1`, port `161` |
| *SNMP version* | `SNMPv3` |
| *Security name* | `zbx-ro` |
| *Security level* | `authPriv` |
| *Authentication protocol* | `SHA1` |
| *Authentication passphrase* | `Zbx-Auth-3020` |
| *Privacy protocol* | `AES128` |
| *Privacy passphrase* | `Zbx-Priv-3020` |

*Add*.

**Ligne par ligne.**

- *Templates* `PFSense by SNMP` : un modèle fourni avec Zabbix, qui crée automatiquement les éléments à collecter (interfaces, trafic, disponibilité). Certains éléments propres au filtre de pfSense reposent sur le service SNMP intégré et resteront *Not supported* avec NET-SNMP ; les interfaces, elles, remontent.
- `SHA1`, `AES128` : les noms Zabbix des protocoles `SHA` et `AES` choisis dans pfSense.

Après deux à trois minutes, *Monitoring → Hosts* : l'icône `SNMP` de `pfSense` est verte. *Monitoring → Latest data*, filtre sur `pfSense` : les interfaces et leur trafic apparaissent.

> **Si l'icône reste rouge** : refaites le test `snmpwalk` de l'étape 7 ; s'il fonctionne, comparez caractère par caractère les paramètres saisis dans Zabbix.

## Étape 9 — Superviser `srv-int` par agent

**Pourquoi.** Sur un serveur, un agent installé localement voit ce que SNMP ne voit pas : processus, espace disque, contenu des journaux. En mode **actif**, c'est l'agent qui contacte le serveur Zabbix pour recevoir la liste de ce qu'il doit surveiller et renvoyer les résultats. Deux flux traversent donc pfSense : Kali → `srv-int` TCP 10050 (règle L4) et `srv-int` → Kali TCP 10051 (règle S4).

*Data collection → Hosts → Create host* :

| Champ | Valeur |
|---|---|
| *Host name* | `srv-int` |
| *Templates* | `Linux by Zabbix agent active` |
| *Host groups* | `Lab` |
| *Interfaces* | *Add* → `Agent` : `10.1.20.10`, port `10050` |

*Add*.

**Ligne par ligne.**

- *Host name* `srv-int` : doit être **exactement** le nom déclaré dans la configuration de l'agent (`Hostname=srv-int`) ; c'est par ce nom que l'agent actif se présente.
- *Linux by Zabbix agent active* : charge, mémoire, disques, processus, interfaces, collectés par l'agent en mode actif.

Après deux à trois minutes, l'icône `ZBX` de `srv-int` est verte, et *Latest data* affiche ses mesures.

## Étape 10 — Créer une alerte de sécurité

**Pourquoi.** La supervision n'est pas que de la disponibilité. Une série d'échecs de connexion SSH en quelques minutes est le signe d'une attaque par force brute, ou d'un compte que quelqu'un essaie de deviner. On demande à l'agent de lire le journal d'authentification et à Zabbix d'alerter au-delà d'un seuil.

*Data collection → Hosts*, ligne `srv-int`, *Items → Create item* :

| Champ | Valeur |
|---|---|
| *Name* | `Échecs d'authentification SSH` |
| *Type* | `Zabbix agent (active)` |
| *Key* | `log[/var/log/auth.log,"sshd:auth.*authentication failure"]` |
| *Type of information* | `Log` |
| *Update interval* | `30s` |

*Add*. Puis *Triggers → Create trigger* :

| Champ | Valeur |
|---|---|
| *Name* | `Force brute SSH possible sur srv-int` |
| *Severity* | `High` |
| *Expression* | `count(/srv-int/log[/var/log/auth.log,"sshd:auth.*authentication failure"],2m)>=5` |

*Add*.

**Ligne par ligne.**

- *Type* `Zabbix agent (active)` : la lecture d'un journal ne se fait qu'en mode actif ; l'agent garde sa position dans le fichier et n'envoie que les nouvelles lignes.
- `log[/var/log/auth.log,"sshd:auth.*authentication failure"]` : lit `/var/log/auth.log` et ne retient que les lignes qui correspondent à l'expression régulière `sshd:auth.*authentication failure`, c'est-à-dire la ligne `pam_unix(sshd:auth): authentication failure; … rhost=10.1.10.10 user=formation`. Le module PAM l'écrit à chaque mot de passe refusé, quelle que soit la méthode utilisée par le client SSH. Les lignes `Failed password for …` ou `Failed keyboard-interactive/pam for …`, plus connues, ne sont pas toujours écrites : avec un seul essai par connexion, le client coupe avant que `sshd` les journalise. Un filtre sur `Failed password` resterait muet, sans aucun message d'erreur. L'agent peut lire ce fichier parce que son compte `zabbix` est membre du groupe `adm`.
- *Type of information* `Log` : chaque valeur est une ligne de texte horodatée.
- `count(/srv-int/log[…],2m)>=5` : le déclencheur passe en *Problem* si l'élément a reçu au moins 5 lignes dans les 2 dernières minutes. Il revient de lui-même à *OK* quand les échecs cessent.

## Étape 11 — Déclencher l'alerte

**Pourquoi.** Une alerte qui n'a jamais été déclenchée volontairement est une alerte dont on ne sait pas si elle fonctionne.

Dans un terminal de la Kali :

```bash
for i in 1 2 3 4 5 6; do sshpass -p 'mauvais' ssh -o PubkeyAuthentication=no -o NumberOfPasswordPrompts=1 formation@10.1.20.10 true; done
```

**Ligne par ligne.**

- `for i in 1 2 3 4 5 6; do … ; done` : répète six fois la commande.
- `sshpass -p 'mauvais'` : fournit automatiquement le mot de passe `mauvais` quand `ssh` le demande.
- `-o PubkeyAuthentication=no` : force l'authentification par mot de passe.
- `-o NumberOfPasswordPrompts=1` : un seul essai par connexion, donc une ligne `authentication failure` par tour.
- `formation@10.1.20.10 true` : le compte visé, et une commande sans effet qui ne serait exécutée qu'en cas de succès.

Six messages `Permission denied` s'affichent : c'est normal. Vérifiez ensuite dans Zabbix :

- *Monitoring → Latest data*, filtre sur `srv-int` : l'élément `Échecs d'authentification SSH` affiche des lignes `pam_unix(sshd:auth): authentication failure …` dans les 30 secondes ;
- *Monitoring → Problems* : au bout d'une minute environ, `Force brute SSH possible sur srv-int` apparaît. Il disparaît de lui-même deux minutes après le dernier échec.

Capturez l'écran du problème.

> **Si *Latest data* reste vide** : dans *Data collection → Hosts*, l'icône **ZBX** de `srv-int` doit être verte (sinon : règle S4, ou *Host name* différent de `srv-int`) ; dans la liste des éléments, une icône rouge signale un élément *Not supported*, avec la raison au survol (souvent : *Type of information* laissé sur `Numeric`). Sur `srv-int`, `sudo journalctl -u ssh --since "-10 min"` montre si les tentatives sont bien arrivées.

> **Pour aller plus loin (hors du temps du TP).** La capture `~/TP/tp7-incident.pcap` a été prise dans la DMZ d'une PME la nuit d'une intrusion. Avec Wireshark (*Statistics → Conversations*, filtres `http.request`, `http.response.code == 200`, `dns.qry.name.len > 50`), reconstituez la chronologie de l'attaque et rédigez une fiche d'incident à partir du modèle `tp7/modeles/fiche-incident.md` du dépôt. La solution est dans le corrigé.

> **Défi ★.** Chiffrez le transport des journaux. Sur `srv-int`, renommez `/etc/rsyslog.d/20-tls.conf.exemple` en `20-tls.conf` et redémarrez rsyslog : il écoute aussi en TLS sur le port 6514. Configurez `web` pour émettre en TLS vers ce port (paquet `rsyslog-gnutls`, pilote `gtls`, AC du laboratoire), ajustez la règle D5, et vérifiez dans Wireshark que les messages ne sont plus lisibles.

**Livrable** (dans `~/livrables`) :

- la capture d'écran de l'étape 5 (un refus du pare-feu et un événement de `web` sur le collecteur) ;
- la capture d'écran de l'étape 11 (alerte Zabbix en *Problem*).

## Questions de validation

1. Pourquoi centraliser les journaux hors des machines qui les produisent ?
2. Pourquoi faut-il SNMPv3 en *authPriv*, et pas v2c ?
3. Pourquoi l'élément qui lit le journal d'authentification doit-il être de type *actif* ?
4. Pourquoi un filtre sur `Failed password` serait-il resté muet dans ce laboratoire, et comment l'auriez-vous découvert ?

---

[← TP6](../tp6/README.md) · [Sommaire](../README.md) · [Corrigé](corrige/README.md) · [En cas de blocage](../en-cas-de-blocage.md) · [TP8 →](../tp8/README.md)
