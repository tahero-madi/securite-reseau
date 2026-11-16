# Corrigé du TP2

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

**Préparation.** Le flux Greenbone se charge à l'installation de la Kali (`prep.sh`) et doit être « Current » dans *Feed Status* avant l'instantané de départ : le vérifier sur chaque environnement la veille. Si un apprenant voit des tâches sans résultat, c'est presque toujours le flux encore en cours de chargement ou un scan lancé avant que `ospd-openvas` ne soit prêt (relancer). Le scanner sort sous l'adresse de la Kali (10.1.10.10) : à l'état initial, les règles « HRA : tout autoriser » de pfSense laissent tout passer. Si la Kali manque de mémoire pendant un scan (12 Go pour Greenbone, Zabbix et le bureau), arrêter Zabbix le temps du TP : `sudo docker compose -f /opt/zabbix/compose.yaml stop`.

**Lancement et suivi.** L'erreur la plus fréquente : créer la tâche sans la lancer (état **New**). Il faut cliquer sur ▶ dans la colonne *Actions*. Le scan est terminé quand *Status* indique **Done** ; si la tâche passe en *Interrupted*, vérifier dans *Feed Status* que le flux est « Current » et que la Kali a assez de mémoire, puis relancer.

**Étapes 3 à 8.** Résultats typiques : `web` remonte de nombreuses vulnérabilités élevées/critiques réelles via ses services anciens volontairement non durcis (FTP, Telnet, versions obsolètes) et ses applications vulnérables (DVWA, Juice Shop). Sur `srv-int` à jour, le scan non authentifié peut signaler des « versions anciennes » sur la base de bannières alors qu'Ubuntu rétroporte les correctifs → faux positif, à confirmer en authentifié. Le point clé : montrer la différence de couverture et de fiabilité. Les paquets de service de `web` (nginx, PHP, MariaDB, vsftpd, snmpd…) ont été installés dans leur version de sortie d'Ubuntu 24.04 sans les mises à jour : le scan authentifié (Notus) remonte donc de nombreux correctifs manquants réels, que `apt install --only-upgrade` corrige pour le contre-scan.

Compte de scan : insister sur le principe (dédié, clé, droits minimaux, restriction par source avec `from="10.1.10.10"`, journalisé). Faire constater qu'aucun `sudo` n'est nécessaire pour un scan de correctifs sur Ubuntu (lecture de `dpkg`). Ne jamais utiliser un compte root réutilisé.

**Liste de ports et SNMP.** Avec « All IANA assigned TCP » seule, le scan non authentifié ne voit pas SNMP : 0 Critical, 0 High sur `web` (essai réel). Avec la liste `IANA-TCP+SNMP`, Greenbone teste UDP 161 et signale la communauté par défaut `public` acceptée par `web`, en général en sévérité High (lecture de la configuration, des interfaces, des processus…). Message : la couverture d'un scan dépend de la liste de ports ; la fixer, c'est décider de ce qu'on ne verra pas. Si la copie n'affiche pas 1 port UDP, la plage a été ajoutée en TCP.

**Scan non authentifié contre authentifié (essai réel).** Non authentifié (web et srv-int) : 0 Critical, 0 High, 5 Medium, 6 Low, sévérité maximale 5.0 — Greenbone ne voit que ce qui s'observe de l'extérieur (typiquement : FTP et Telnet en clair, TLS 1.0/1.1, fichiers exposés), car la bannière « nginx 1.24.0 (Ubuntu) » ne dit rien des correctifs appliqués par Ubuntu. Authentifié (web seul) : 8 Critical, 21 High, 34 Medium, 5 Low, sévérité maximale 9.8 — les correctifs de sécurité Ubuntu (USN) manquants des paquets restés en version de sortie. C'est l'argument central du TP.

**Défi ★ nikto.** nikto relève ce qui relève du serveur et de l'application web : en-têtes de sécurité absents (`X-Frame-Options`, `X-Content-Type-Options`), cookies sans `HttpOnly`, version du serveur, répertoires et fichiers intéressants (dont, selon la durée, `/.git/`), page de connexion de DVWA. Il ne trouve pas les injections SQL ni les XSS de DVWA : il faudrait un scanner applicatif qui explore et soumet les formulaires (OWASP ZAP, Burp) ou un test manuel, ce qui sort du cadre de la formation. À retenir : scanner de vulnérabilités, scanner web et test d'intrusion sont complémentaires.

**Étape 9.** Les apprenants doivent articuler les trois signaux : CVSS (sévérité), EPSS (probabilité), KEV (exploitation avérée) + exposition de l'actif. Attendu : une vulnérabilité KEV sur `web` (exposé) passe avant une CVSS 9.8 théorique sur un hôte interne non exposé. Vérifier qu'ils consultent réellement KEV et EPSS et ne se fient pas au seul score.

**Défi ★ — exemple de script.**

```python
import csv
ordre = {"Critical": 4, "High": 3, "Medium": 2, "Low": 1, "Log": 0}
with open("/home/formation/livrables/tp2-scan-auth.csv", newline="") as f:
    lignes = list(csv.DictReader(f))
lignes.sort(key=lambda r: (ordre.get(r["Severity"], 0), float(r["CVSS"] or 0), int(r["QoD"] or 0)), reverse=True)
for r in lignes[:5]:
    print(r["Severity"], r["CVSS"], r["QoD"] + " %", r["IP"], r["Port"], r["NVT Name"], r["CVEs"], sep=" | ")
```

Point de discussion : le tri par CVSS ignore l'exposition de la machine, la probabilité d'exploitation (EPSS) et l'exploitation avérée (KEV) ; à CVSS égal, une vulnérabilité exposée sur Internet et au KEV passe en premier.

**Résultats réels (essai sur la plateforme Hexceos).**

Les deux rapports complets de cet essai, au format PDF, sont disponibles si votre scan n'a pas abouti ou pour comparer avec le vôtre :

- [scan non authentifié de web et srv-int](rapports/scan-non-authentifie.pdf) (15 pages, 13 résultats) ;
- [scan authentifié de web](rapports/scan-authentifie.pdf) (115 pages, 70 résultats).

Ces rapports n'affichent que les résultats de QoD 70 % ou plus : 126 résultats bruts au départ pour le scan non authentifié. Le scan non authentifié a été lancé avec la liste de ports par défaut, sans UDP, d'où l'absence de SNMP.

*Non authentifié (web et srv-int)*, 13 résultats, aucun High :
- web : dépôt Git accessible (« Source Control Management (SCM) Files/Folders Accessible », 5.0, ports 80 et 443), « Cleartext Transmission of Sensitive Information via HTTP » (4.8), « FTP Unencrypted Cleartext Login » (4.8), « SSL/TLS: Deprecated TLSv1.0 and TLSv1.1 » (4.3, QoD 98 %), algorithmes MAC faibles en SSH, horodatages TCP et ICMP (2.x) ;
- srv-int : « SSL/TLS: Renegotiation DoS » sur LDAP 389 et 636 (5.0), algorithmes MAC faibles en SSH, horodatages ;
- Telnet n'apparaît pas en tant que tel : le scan non authentifié ne le signale pas comme vulnérabilité. Et sans UDP dans la liste de ports, SNMP non plus.

*Authentifié (web)*, 70 résultats, dont 56 avis Ubuntu (USN) en QoD 97 % ; sévérité maximale 9.8. Paquets les plus cités :
- **nginx** : 17 avis, jusqu'à 8.2 (USN-8563, 8210, 8955, 8354, 8458, 8271…) ; version installée `1.24.0-2ubuntu7`, corrigée à partir de `1.24.0-2ubuntu7.14` (USN-8563-1) ;
- **PHP 8.3** : 7 avis, dont 4 à 9.8 ;
- brotli, socat, libdbi-perl (9.8), pyjwt (9.1), noyau linux (8.4 et 7.8), inetutils (7.8, c'est le paquet de telnetd), net-snmp (7.5), libxml2, pcre2, zlib, mariadb, glibc, apt…

**Choisir une remédiation qui marche.** Le paquet à corriger se lit dans le résultat USN : son résumé nomme le paquet (« missing an update for the 'nginx' package(s) »). Pour lister les paquets les plus cités du rapport : `grep -o "update for the '[^']*'" ~/livrables/tp2-scan-auth.csv | sort | uniq -c | sort -rn | head`. `apt-cache policy` doit proposer une version plus récente que la version installée ; sinon (correctif réservé à Ubuntu Pro pour les paquets de *universe*, ou dépôts injoignables), en choisir un autre.

- **nginx** est le meilleur exemple : `sudo apt install --only-upgrade nginx` ; au contre-scan, les avis nginx disparaissent d'un coup (17 résultats, dont 10 High).
- **PHP** : `sudo apt install --only-upgrade 'php8.3*'` (plusieurs paquets pour un même avis).
- **Noyau** : le paquet se met à jour, mais le correctif ne s'applique qu'au redémarrage ; le scan authentifié vérifie la version du paquet installé, pas celle du noyau en cours d'exécution. Bon point de discussion.
- **Cas 2** : désactiver `vsftpd` fait disparaître « FTP Unencrypted Cleartext Login » du contre-scan non authentifié ; en revanche, désactiver Telnet ne change rien au scan non authentifié (il ne le signalait pas) et l'avis USN d'inetutils reste dans le scan authentifié, puisque le paquet est toujours installé.

**Étapes 10 et 11.** Exemples de remédiation faciles à démontrer : `sudo apt install --only-upgrade nginx` (ou `php8.3-fpm`), désactiver Telnet (`sudo systemctl disable --now openbsd-inetd`) ou SNMP (`snmpd`), durcir `sshd_config` (si une règle de conformité le remonte), mettre à jour un paquet applicatif non critique. L'essentiel pédagogique est la **boucle** correction → contre-scan → disparition du résultat.

**Questions.** 1 : il lit l'état réel des paquets installés et des correctifs via un compte, au lieu de déduire d'une bannière. 2 : vérifier manuellement (QoD faible = détection peu fiable) : confirmer l'existence du service/version, écarter le faux positif, sinon ne pas gaspiller d'effort. 3 : compte dédié, clé SSH, droits de lecture minimaux, restriction à l'IP du scanner, activation seulement pendant les fenêtres de scan, rotation du secret, journalisation.

---

[← TP1](../../tp1/README.md) · [Sommaire](../../README.md) · [Énoncé](../README.md) · [En cas de blocage](../../en-cas-de-blocage.md) · [TP3 →](../../tp3/README.md)
