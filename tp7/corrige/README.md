# Corrigé du TP7

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

**Préparation.** Sur `srv-int`, rsyslog écoute en UDP et TCP 514 et range les messages dans `/var/log/remote/<nom d'hôte>.log` ; le modèle TLS est dans `/etc/rsyslog.d/20-tls.conf.exemple`. L'agent Zabbix de `srv-int` est configuré avec `Server=` et `ServerActive=10.1.10.10`, `Hostname=srv-int`, et son compte est dans le groupe `adm`. Zabbix 7.0 tourne sur la Kali (`/opt/zabbix/compose.yaml`), interface sur `http://127.0.0.1:8080`, port 10051 publié sur 10.1.10.10. La capture `tp7-incident.pcap` (924 paquets, 18 minutes) est dans `~/TP` de chaque Kali et dans le dossier `fichiers/` du dépôt ; elle est générée par `generer_captures.py --tp7` (trafic simulé, contenu inerte). Ses adresses (203.0.113.12, 198.51.100.x) ne sont pas celles du laboratoire.

## Étapes 1 à 5 — Journalisation centralisée

Règle ajoutée :

| N° | Interface | Action | Source | Destination | Port | Rôle |
|---|---|---|---|---|---|---|
| D5 | DMZ | Pass | `H_web` | `H_srv_int` | TCP 514 | Journaux de `web` vers le collecteur, au-dessus de D4 |

Résultat attendu sur `srv-int` : `web.log` et un fichier au nom d'hôte de pfSense (par exemple `pfSense.home.arpa.log`) dans `/var/log/remote/`. Si pfSense est resté au format BSD (RFC 3164) : le fichier s'appelle `_gateway.log` (le message ne porte pas de nom d'hôte, rsyslog résout l'adresse 10.1.20.1, que systemd-resolved nomme `_gateway`), et les heures de pfSense ont une heure d'avance (heure locale de Paris lue comme UTC). Le passage en RFC 5424 corrige les deux : bon support pour l'étape 4 (horodatage et fuseau).

Les refus `10.1.30.10 → <adresse Internet>:443` qui apparaissent aussi sont des tentatives de sortie de `web` (mises à jour automatiques, par exemple), bloquées par le refus final de la DMZ : le filtrage sortant fonctionne. Faire chercher le programme en cause sur `web` (`sudo ss -tnp`, `systemctl list-timers`). Forme générale d'une ligne du filtre (le nom de la carte dépend de la plateforme) :

```text
… pfSense filterlog[…]: 10,,,1000000110,vtnet1,match,block,in,4,0x0,,64,…,tcp,60,10.1.10.10,10.1.30.10,51234,21,0,S,…
```

À lire : numéro de règle, carte du LAN (ici `vtnet1`), `block`, entrant, IPv4, TCP, de 10.1.10.10 vers 10.1.30.10, port 21, drapeau `S` (SYN). Sur `web.log` : `Invalid user inconnu from 10.1.10.10` et le message `TP7 test de transfert depuis web`.

Pièges fréquents :

- D5 oubliée ou placée sous D4 : rien n'arrive de `web` ; le refus `10.1.30.10 → 10.1.20.10:514` apparaît dans les journaux de pfSense (bon support de discussion : le pare-feu documente lui-même le flux manquant) ;
- `@` au lieu de `@@` : envoi en UDP, refusé par D5 qui n'autorise que TCP ;
- *Source Address* laissée sur `Default` : pfSense émet depuis l'adresse de l'interface de sortie, ce qui fonctionne aussi, mais le choix explicite rend le flux prévisible ;
- horloges : `System clock synchronized: no` si S2 ou D2 manquent.

Le collecteur devient un actif critique : il concentre des informations sensibles et une preuve. Il doit être protégé (accès restreint, intégrité, sauvegarde, rétention conforme).

## Étapes 6 à 11 — Zabbix

Règle ajoutée :

| N° | Interface | Action | Source | Destination | Port | Rôle |
|---|---|---|---|---|---|---|
| L11 | LAN | Pass | `H_poste_admin` | LAN address | UDP 161 | Interrogation SNMPv3 de pfSense, au-dessus de L10 |

- `snmpwalk -v3 … system` renvoie `sysDescr`, `sysUpTime`, `sysContact`, `sysName`, `sysLocation` ; la requête v2c `public` aboutit à `Timeout`. Un équipement qui « supporte SNMP » ne supporte pas forcément SNMPv3 : le service intégré de pfSense (bsnmpd) ne fait que v1/v2c.
- *Host* `pfSense` : icône `SNMP` verte ; avec NET-SNMP, les éléments du modèle propres au filtre de pfSense (MIB `BEGEMOT-PF-MIB`) restent *Not supported*, les interfaces fonctionnent.
- *Host* `srv-int` gris ou rouge : nom différent de `srv-int`, ou flux 10050 (L4) / 10051 (S4) fermés. Dans le journal de l'agent (`/var/log/zabbix/zabbix_agentd.log` sur `srv-int`) : `cannot connect to [[10.1.10.10]:10051]` (S4 manquante) ou `host [srv-int] not found` (nom différent).
- Déclencheur : `count(/srv-int/log[/var/log/auth.log,"Failed (password|keyboard-interactive)"],2m)>=5` passe en *Problem* environ une minute après la boucle `sshpass`. S'il reste à *OK* :
  - filtre limité à `Failed password` : sur la plateforme, `sshd` accepte la méthode *keyboard-interactive*, que le client SSH préfère ; les échecs s'écrivent alors `Failed keyboard-interactive/pam for …` et ne correspondent pas (vérifier avec `sudo grep sshd /var/log/auth.log | tail`) ;
  - élément en type passif au lieu d'actif, ou *Type of information* laissé sur *Numeric* (l'élément devient *Not supported*) ;
  - flux 10051 (S4) fermé ou nom d'hôte différent de `srv-int` : l'agent actif ne reçoit pas la liste de ses éléments.

Le déclencheur relie supervision et sécurité : c'est une règle de détection, au même titre qu'une signature Suricata.

## Étapes 12 à 15 — Analyse de la capture

Guider la **méthode** plus que la réponse : hiérarchie des protocoles → conversations → filtres par étape → suivi de flux → export d'objets → qualification ATT&CK. Faire verbaliser la chronologie. Solution (UTC, 12/11/2026) :

| Heure | Fait observé | Filtre utile | ATT&CK |
|---|---|---|---|
| 03:12:04 | Balayage SYN de ~235 ports depuis 198.51.100.66 ; ouverts : 21, 22, 23, 80, 443, 3000 | `tcp.flags.syn==1 && tcp.flags.ack==0` | T1046 / T1595 |
| 03:14:31 | Énumération web (User-Agent `Nikto/2.5.0`) : 404 en série, puis **200 sur `/.git/config`** révélant `deploy:Deploy2019!` | `http.request`, `http.response.code == 200` | T1595.003, T1552.001 |
| 03:17:12 | Connexion DVWA avec les identifiants par défaut `admin/password` | `http.request.method=="POST"` | T1078.001 |
| 03:17:3x–03:18 | Injection de commande (`ip=127.0.0.1;id`, puis `cat /etc/hostname`, puis `curl … /a`) | `http.request.uri contains "exec"` | T1190, T1059.004 |
| ~03:18 | `web` télécharge `/a` depuis 198.51.100.77:8080 | connexions ouvertes par le serveur | T1105 |
| 03:19:02 → 03:30 | Balise `GET /b?id=web-dmz` toutes les ~30 s vers 198.51.100.77:8080 (réponse `sleep`) | *Statistics → Conversations*, *I/O Graphs* | T1071.001 |
| 03:24:10 | 18 requêtes DNS TXT très longues vers **198.51.100.53** en direct (contourne le résolveur) : `<base32>.<n>.t.update-check.example` | `dns.qry.name.len > 50` | T1071.004, T1048 |
| 03:27:40 | `POST /u` de `export-clients.csv` (~600 lignes, données personnelles) | *File → Export Objects → HTTP* | T1041 |

IOC : 198.51.100.66 (source de l'attaque), 198.51.100.77:8080 (C2 et exfiltration), 198.51.100.53 et le domaine `update-check.example` (tunnel DNS), URI `/b?id=web-dmz` et `/u`, User-Agent `Nikto/2.5.0`, compte `deploy` à révoquer, compte DVWA `admin` au mot de passe par défaut.

Causes racines à faire émerger : publication 1:1 (tous les ports) au lieu d'un port forward 443 ; dépôt `.git` dans la racine web ; identifiants par défaut ; injection de commande dans l'application ; **absence de filtrage sortant** depuis la DMZ (le C2, le DNS direct et l'exfiltration auraient échoué avec la matrice du TP3 : D1 n'autorise le DNS que vers pfSense, D4 refuse le reste).

## Étape 16 — Fiche d'incident

Une bonne fiche :

- distingue les faits (observés dans la capture) des hypothèses (par exemple : « le contenu de `/a` est inconnu, probablement un implant » ; « d'autres machines ont-elles été contactées ? » : la sonde DMZ ne le dit pas) ;
- propose un confinement **réaliste au vu de leur architecture** : retrait de la publication 1:1, blocage de 198.51.100.0/24 en entrée et en sortie, DNS sortant de la DMZ autorisé vers le résolveur de pfSense seulement, isolement de `web` (règle de blocage en tête de l'interface DMZ, en conservant la journalisation), révocation du compte `deploy`, changement des mots de passe exposés ;
- prévoit l'éradication (réinstallation de `web` plutôt que nettoyage) et le rétablissement sous surveillance renforcée (règles Suricata sur les IOC) ;
- liste des IOC exploitables ;
- traite les notifications : données personnelles de clients exfiltrées, donc violation de données à notifier à la CNIL dans les 72 heures (RGPD, article 33), et aux personnes concernées si le risque est élevé (article 34) ; NIS 2 selon le statut de l'entité (signalement initial sous 24 heures) ; plainte.

## Défi

Sur `srv-int` : `sudo mv /etc/rsyslog.d/20-tls.conf.exemple /etc/rsyslog.d/20-tls.conf && sudo systemctl restart rsyslog`, puis `ss -tlnp | grep 6514`. Sur `web` : `rsyslog-gnutls`, l'AC du laboratoire, et une action `omfwd` en `StreamDriver="gtls"`, `StreamDriverMode="1"`, port 6514 ; D5 passe en 6514. Le modèle d'écoute est en `Authmode="anon"` (chiffrement sans authentification des émetteurs) : en production, `x509/name` des deux côtés.

## Questions

1. Disponibilité (les journaux survivent à la compromission ou à la panne de la source), intégrité (un attaquant local ne peut pas les effacer), corrélation (vue unique et horodatée), conformité (rétention, preuve).
2. v1/v2c : une communauté envoyée en clair qui fait office de mot de passe, souvent `public`, et aucun chiffrement des réponses (qui révèlent la configuration). v3 *authPriv* : utilisateur authentifié (HMAC) et échanges chiffrés.
3. `tcp.flags.syn==1 && tcp.flags.ack==0` : beaucoup de paquets, depuis une même source, vers des ports variés, la plupart sans réponse.
4. La régularité : des connexions à intervalle fixe (~30 s) vers la même destination externe non légitime, initiées par un serveur qui n'a pas à initier de connexions, avec des requêtes et réponses courtes et identiques (`id=web-dmz`, `sleep`). Un trafic humain est irrégulier.

---

[← TP6](../../tp6/README.md) · [Sommaire](../../README.md) · [Énoncé](../README.md) · [En cas de blocage](../../en-cas-de-blocage.md) · [TP8 →](../../tp8/README.md)
