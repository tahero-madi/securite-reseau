# Corrigé du TP7

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

**Préparation.** La capture `tp7-incident.pcap` (924 paquets, 18 min) est dans `~/TP` de chaque Kali (et dans le dossier `fichiers/` du dépôt) ; elle est générée par `generer_captures.py --tp7` (trafic simulé, contenu inerte). Elle vient d'une autre PME : ses adresses (203.0.113.12, 198.51.100.x) ne sont pas celles du laboratoire.

**Partie A.** Objectif : un refus pfSense **et** un événement serveur visibles au même endroit (`/var/log/remote/pfSense.log` ou selon le nom d'hôte de pfSense, `/var/log/remote/web.log`), horodatés de façon cohérente. Piège fréquent : la règle DMZ → SRV 514 oubliée après le TP 3 (rien n'arrive de `web` ; le refus apparaît dans les journaux de pfSense — bon support de discussion). Défi TLS : renommer `/etc/rsyslog.d/20-tls.conf.exemple` sur `srv-int` et configurer l'émetteur en `gtls` avec l'AC du lab ; en production, le chiffrement du transport syslog est la norme. Le collecteur est un actif à protéger.

**Partie B.** SNMPv3 authPriv obligatoire : refuser v2c. Le service SNMP natif de pfSense (bsnmpd) ne fait que v2c : c'est l'occasion de montrer qu'un équipement « supporte SNMP » ne veut pas dire « supporte SNMPv3 ». Si le *Host* `srv-int` reste gris : nom d'hôte différent de `Hostname=srv-int`, ou flux 10050/10051 fermés par pfSense. Pour SNMPv3, la règle LAN vers pfSense en UDP 161 est souvent oubliée après le TP 3. Le trigger « échecs d'authentification » relie supervision et sécurité. Vérifier que la condition se déclenche réellement (générer les échecs SSH).

**Partie C.** Guider la **méthode** plus que la « réponse » : hiérarchie des protocoles → conversations → suivi de flux → export d'objets → qualification ATT&CK. Faire verbaliser la chronologie. Solution (UTC, 12/11/2026) :

| Heure | Fait observé | Filtre utile | ATT&CK |
|---|---|---|---|
| 03:12:04 | Balayage SYN de ~235 ports depuis 198.51.100.66 ; ouverts : 21, 22, 23, 80, 443, 3000 | `tcp.flags.syn==1 && tcp.flags.ack==0` | T1046 / T1595 |
| 03:14:31 | Énumération web (User-Agent Nikto/2.5.0) : 404 en série, puis **200 sur `/.git/config`** révélant `deploy:Deploy2019!` | `http.request` | T1595.003, T1552.001 |
| 03:17:12 | Connexion DVWA avec les identifiants par défaut `admin/password` | `http.request.method=="POST"` | T1078.001 |
| 03:17:3x–03:18 | Injection de commande (`ip=127.0.0.1;id`, puis `cat /etc/hostname`, puis `curl … /a`) | `http.request.uri contains "exec"` | T1190, T1059.004 |
| ~03:18 | `web` télécharge `/a` depuis 198.51.100.77:8080 | `ip.dst==198.51.100.77` | T1105 |
| 03:19:02 → 03:30 | Balise `GET /b?id=web-dmz` toutes les ~30 s vers 198.51.100.77:8080 (réponse `sleep`) | *Statistics → Conversations* | T1071.001 |
| 03:24:10 | 18 requêtes DNS TXT très longues vers **198.51.100.53** en direct (contourne le résolveur de pfSense) : `<base32>.<n>.t.update-check.example` | `dns.qry.name.len > 50` | T1071.004, T1048 |
| 03:27:40 | `POST /u` de `export-clients.csv` (~600 lignes, données personnelles) | *File → Export Objects → HTTP* | T1041 |

IOC : 198.51.100.66 (source de l'attaque), 198.51.100.77:8080 (C2/exfiltration), 198.51.100.53 et le domaine `update-check.example` (tunnel DNS), URI `/b?id=web-dmz` et `/u`, User-Agent `Nikto/2.5.0`, compte `deploy` à révoquer. Causes racines à faire émerger : publication 1:1 au lieu d'un port forward 443, dépôt `.git` dans la racine web, identifiants par défaut, **absence de filtrage sortant** depuis la DMZ (C2, DNS direct et exfiltration auraient échoué avec la matrice du TP 3).

**Partie D.** Une bonne fiche distingue les faits (observés dans la capture) des hypothèses, propose un confinement **réaliste au vu de leur propre architecture** (blocage de 198.51.100.0/24 en sortie de DMZ, DNS sortant autorisé uniquement vers le résolveur de pfSense, retrait de la publication, isolement de `web`, révocation du compte `deploy`) et liste des IOC exploitables. Les données exfiltrées étant des données personnelles de clients : notification à la CNIL sous 72 h (RGPD art. 33) à discuter, et éventuellement NIS 2 selon le statut de l'entité.

**Questions.** 1 : disponibilité (survivent à la compromission de la source), intégrité (un attaquant local ne peut pas les effacer), corrélation (vue unique), conformité. 2 : `tcp.flags.syn==1 && tcp.flags.ack==0` (beaucoup, vers des ports variés, sans réponse). 3 : régularité temporelle des connexions vers une même destination externe (battement), faible volume montant/descendant constant, destination non légitime, éventuellement empreinte TLS atypique — contrairement à un trafic humain irrégulier.

---

[← TP6](../../tp6/README.md) · [Sommaire](../../README.md) · [Énoncé](../README.md) · [En cas de blocage](../../en-cas-de-blocage.md) · [TP8 →](../../tp8/README.md)
