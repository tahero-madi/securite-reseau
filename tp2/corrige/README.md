# Corrigé du TP2

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

**Les rapports de référence.** Les chiffres de ce corrigé viennent d'un essai réel sur la plateforme (13 novembre 2026). Les deux rapports complets, au format PDF, sont disponibles si votre scan n'a pas abouti ou pour comparer avec le vôtre :

- [scan non authentifié de web et srv-int](rapports/scan-non-authentifie.pdf) (15 pages, 13 résultats, 38 minutes) ;
- [scan authentifié de web](rapports/scan-authentifie.pdf) (115 pages, 70 résultats, 37 minutes).

Les deux rapports n'affichent que les résultats de QoD 70 % ou plus, sans les résultats de niveau *Log* : le scan non authentifié comptait 126 résultats bruts avant ce filtre. Le scan non authentifié a été lancé avec la liste de ports « All IANA assigned TCP », sans UDP : SNMP n'y figure donc pas. Vos chiffres peuvent différer un peu : le flux de Greenbone et les correctifs Ubuntu évoluent chaque jour.

**Préparation.** Le flux Greenbone se charge à l'installation de la Kali (`prep.sh`) et doit être « Current » dans *Feed Status* avant l'instantané de départ : le vérifier sur chaque environnement la veille. Si un apprenant voit des tâches sans résultat, c'est presque toujours le flux encore en cours de chargement ou un scan lancé avant que `ospd-openvas` ne soit prêt (relancer). Le scanner sort sous l'adresse de la Kali (10.1.10.10) : à l'état initial, les règles « HRA : tout autoriser » de pfSense laissent tout passer. Si la Kali manque de mémoire pendant un scan (12 Go pour Greenbone, Zabbix et le bureau), arrêter Zabbix le temps du TP : `sudo docker compose -f /opt/zabbix/compose.yaml stop`.

**Lancement et suivi.** L'erreur la plus fréquente : créer la tâche sans la lancer (état **New**). Il faut cliquer sur ▶ dans la colonne *Actions*. Le scan est terminé quand *Status* indique **Done** ; si la tâche passe en *Interrupted*, vérifier dans *Feed Status* que le flux est « Current » et que la Kali a assez de mémoire, puis relancer.

**Étape 3 — liste de ports et SNMP.** Avec « All IANA assigned TCP » seule, le scan ne voit pas SNMP : c'est le cas des rapports de référence. Avec la liste `IANA-TCP+SNMP`, Greenbone teste UDP 161 et signale la communauté par défaut `public` acceptée par `web`, en général en sévérité High (lecture de la configuration, des interfaces, des processus…). Message : la couverture d'un scan dépend de la liste de ports ; la fixer, c'est décider de ce qu'on ne verra pas. Si la copie n'affiche pas 1 port UDP, la plage a été ajoutée en TCP.

**Étapes 4 et 5 — scan non authentifié.** 13 résultats : **0 Critical, 0 High, 7 Medium, 6 Low**, sévérité maximale 5.0.

| Hôte | Port | Résultat | CVSS | QoD |
| --- | --- | --- | --- | --- |
| web | 80, 443 | Source Control Management (SCM) Files/Folders Accessible : le dépôt `.git` est lisible (2 résultats) | 5.0 | 70 % |
| web | 80 | Cleartext Transmission of Sensitive Information via HTTP : formulaire de connexion de DVWA en HTTP | 4.8 | 80 % |
| web | 21 | FTP Unencrypted Cleartext Login | 4.8 | 70 % |
| web | 443 | SSL/TLS: Deprecated TLSv1.0 and TLSv1.1 Protocol Detection | 4.3 | 98 % |
| srv-int | 389, 636 | SSL/TLS: Renegotiation DoS Vulnerability (2 résultats) | 5.0 | 70 % |
| web, srv-int | 22 | Weak MAC Algorithm(s) Supported (SSH) | 2.6 | 80 % |
| web, srv-int | — | TCP Timestamps et ICMP Timestamp Reply Information Disclosure | 2.6 et 2.1 | 80 % |

Ce que le scan **ne voit pas** : aucune version vulnérable de nginx, PHP ou MariaDB, car la bannière « nginx/1.24.0 (Ubuntu) » ne dit rien des correctifs qu'Ubuntu applique sans changer le numéro de version ; Greenbone ne conclut donc pas. Telnet, pourtant ouvert sur le port 23 de `web` (vu au TP1), n'est pas signalé non plus. `srv-int`, lui, ne remonte que la renégociation TLS de LDAP, et aucun faux positif de version. La synthèse à faire écrire : de l'extérieur, `web` paraît « moyennement » exposé.

**Étapes 6 à 8 — scan authentifié.** La ligne *Host Authentications* du rapport doit afficher **SSH Success**, utilisateur `gvm-scan`. Sinon, le scan s'est déroulé comme un scan non authentifié : vérifier la clé, la restriction `from="10.1.10.10"` et l'identifiant associé à la cible. Aucun `sudo` n'est nécessaire pour un scan de correctifs sur Ubuntu : Greenbone lit simplement la liste des paquets installés. Insister sur le principe du compte : dédié, clé SSH, droits minimaux, restriction par adresse source, journalisé ; jamais un compte root réutilisé.

Résultat sur `web` : 70 résultats, **8 Critical, 21 High, 36 Medium, 5 Low**, sévérité maximale 9.8. Ce sont les 8 résultats réseau du scan non authentifié (`.git`, HTTP, FTP, TLS, SSH, horodatages), plus **62 avis de sécurité Ubuntu (USN)**, tous en QoD 97 % : Greenbone compare la version de chaque paquet installé à la version corrigée.

| Paquet en cause | Avis | Sévérité max. | Version installée | Corrigé à partir de | Au KEV ? |
| --- | --- | --- | --- | --- | --- |
| PHP 8.3 (`php8.3-fpm`, `-cli`, `-mysql`, `-common`) | 8 (4 Critical, 2 High, 2 Medium) | 9.8 | 8.3.6-0maysync1 | 8.3.6-0ubuntu0.24.04.13 | **oui** (USN-8948-1) |
| brotli (`libbrotli1`) | 1 | 9.8 | 1.1.0-2build2 | 1.1.0-2ubuntu0.1 | **oui** (USN-8956-1) |
| socat | 1 | 9.8 | 1.8.0.0-4build3 | 1.8.0.0-4ubuntu0.1 | non |
| libdbi-perl | 3 (1 Critical) | 9.8 | 1.643-4build3 | 1.643-4ubuntu0.4 | non |
| pyjwt (`python3-jwt`) | 2 (1 Critical) | 9.1 | 2.7.0-1ubuntu0.2 | 2.7.0-1ubuntu0.4 | non |
| noyau (`linux-image-virtual`) | 2 | 8.4 | 6.8.0-146 | 6.8.0-149 | **oui** (USN-8917-1) |
| **nginx** (`nginx`, `nginx-common`) | **17** (10 High, 6 Medium, 1 Low) | 8.2 | 1.24.0-2ubuntu7 | 1.24.0-2ubuntu7.19 | non |
| python3-urllib3 | 1 | 8.1 | 2.0.7-1ubuntu0.7 | 2.0.7-1ubuntu0.8 | non |
| **telnetd** (`inetutils-telnetd`) | 2 (1 High, 1 Medium) | 7.8 | 2:2.5-3ubuntu4 | 2:2.5-3ubuntu4.2 | **oui** (USN-7992-1) |
| libxml2 | 1 | 7.8 | 2.9.14+dfsg-1.3ubuntu3.9 | 2.9.14+dfsg-1.3ubuntu3.10 | non |
| pcre2 (`libpcre2-8-0`) | 1 | 7.8 | 10.42-4ubuntu2.1 | 10.42-4ubuntu2.2 | non |
| net-snmp (`snmpd`, `libsnmp40t64`) | 2 | 7.5 | 5.9.4+dfsg-1.1ubuntu3 | 5.9.4+dfsg-1.1ubuntu3.3 | non |
| zlib (`zlib1g`) | 1 | 7.4 | 1:1.3.dfsg-3.1ubuntu2.2 | 1:1.3.dfsg-3.1ubuntu2.3 | non |
| MariaDB (`mariadb-server`) | 3 | 6.8 | 10.11.7-2ubuntu2 | 10.11.13-0ubuntu0.24.04.1 | non |
| 16 autres paquets (glibc, apt, xz-utils, libevent, perl, Twisted…) | 17 au total | 6.3 | | | non |

*KEV : catalogue de la CISA, version du 13 novembre 2026. La colonne indique qu'au moins une CVE de l'avis y figure.*

Deux familles de paquets à distinguer :

- les paquets de service de `web` (nginx, PHP, MariaDB, telnetd, snmpd, vsftpd) ont été installés **volontairement** dans leur version de sortie d'Ubuntu 24.04, sans aucun correctif : d'où leurs nombreux avis ;
- les bibliothèques du système (glibc, libxml2, zlib…) sont déjà à jour d'une partie des correctifs, mais pas de tous : l'image de la VM a quelques semaines, et rien ne l'a mise à jour depuis. C'est la situation de beaucoup de serveurs réels.

**Le constat central du TP** : vu de l'extérieur, `web` n'a aucune vulnérabilité au-dessus de 5.0 ; vu de l'intérieur, il en a 29 Critical ou High, dont 4 avis au catalogue des vulnérabilités exploitées. Un scan non authentifié sous-estime massivement l'exposition d'une machine.

**Défi ★ nikto.** nikto relève ce qui relève du serveur et de l'application web : en-têtes de sécurité absents (`X-Frame-Options`, `X-Content-Type-Options`), cookies sans `HttpOnly`, version du serveur, répertoires et fichiers intéressants (dont, selon la durée, `/.git/`), page de connexion de DVWA. Il ne trouve pas les injections SQL ni les XSS de DVWA : il faudrait un scanner applicatif qui explore et soumet les formulaires (OWASP ZAP, Burp) ou un test manuel, ce qui sort du cadre de la formation. À retenir : scanner de vulnérabilités, scanner web et test d'intrusion sont complémentaires.

**Étape 9 — prioriser.** Un classement attendu, à partir des rapports de référence :

| Priorité | Vulnérabilité | Justification |
| --- | --- | --- |
| **P0** | telnetd, USN-7992-1 (CVE-2026-24061) | Noté **5.0 seulement** dans le rapport, mais : contournement de l'authentification à distance, avec ouverture d'une session administrateur ; CVE au **KEV** ; service ouvert sur le port 23 de `web`, en DMZ. Le meilleur exemple d'un tri par CVSS qui enterre la priorité réelle. |
| **P0** | PHP 8.3, USN-8948-1 (CVE-2026-109618, CVE-2026-109619) | 9.8, au **KEV**, et PHP sert DVWA sur le serveur web exposé. |
| **P1** | nginx, 17 avis | Jusqu'à 8.2, pas au KEV, mais c'est le service exposé : une seule mise à jour supprime 17 résultats. |
| **P1** | brotli, USN-8956-1 | 9.8 et au KEV, mais c'est une bibliothèque : le risque dépend des programmes qui l'utilisent sur `web`. |
| **P1** | noyau, USN-8917-1 | 8.4 et au KEV ; correctif simple, mais qui impose un redémarrage, donc une fenêtre de maintenance. |
| **P2** | socat, libdbi-perl, pyjwt (9.1 à 9.8) | Score critique, mais a priori aucun service exposé de `web` ne les utilise : il faudrait déjà un accès à la machine pour les exploiter. |
| **P2** | net-snmp (7.5), MariaDB (6.8) | snmpd est exposé (et la communauté `public` est un problème plus grave que l'avis lui-même) ; MariaDB n'écoute par défaut que sur la machine elle-même. |
| **P3** | horodatages, MAC SSH faibles, TLS 1.0/1.1 | Faible sévérité ; à traiter avec le durcissement général. |

Les apprenants doivent articuler les quatre signaux : CVSS (sévérité), EPSS (probabilité), KEV (exploitation avérée) et exposition de l'actif. Vérifier qu'ils consultent réellement le KEV et l'EPSS, et ne se fient pas au seul score. Les valeurs EPSS changent chaque jour : consultez-les le jour du TP sur `https://www.first.org/epss/`. Le constat attendu : telnetd, noté 5.0, passe avant socat, noté 9.8.

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

Sur les rapports de référence, ce tri sort cinq des sept avis notés 9.8 (PHP, brotli, socat, libdbi-perl) : telnetd, noté 5.0, n'apparaît pas, alors qu'il est prioritaire. C'est la réponse à la question du défi : trier par CVSS ignore l'exposition de la machine, la probabilité d'exploitation (EPSS) et l'exploitation avérée (KEV).

**Étape 10 — remédier.** Le paquet à corriger se lit dans le résultat USN : son résumé nomme le paquet source (« missing an update for the 'nginx' package(s) »), et la section *Vulnerability Detection Result* donne le paquet installé, sa version et la version qui corrige. Pour lister les paquets les plus cités : `grep -o "update for the '[^']*'" ~/livrables/tp2-scan-auth.csv | sort | uniq -c | sort -rn | head`. `apt-cache policy` doit proposer une version au moins égale à la version corrigée ; sinon, les dépôts ne sont pas joignables, ou le correctif n'est pas disponible sans abonnement Ubuntu Pro : en choisir un autre.

Effet attendu au contre-scan, selon la correction choisie :

| Correction sur web | Effet au contre-scan authentifié |
| --- | --- |
| `sudo apt install --only-upgrade nginx nginx-common` | Les 17 avis nginx disparaissent (10 High). La démonstration la plus parlante. |
| `sudo apt install --only-upgrade $(dpkg-query -W -f='${binary:Package} ' 'php8.3*')` | Les 8 avis PHP disparaissent, dont les 4 Critical. Plusieurs paquets pour un même avis : `dpkg-query` liste tous les paquets PHP 8.3 installés. |
| `sudo apt install --only-upgrade inetutils-telnetd` | Les 2 avis telnetd disparaissent ; le service reste ouvert, en clair. |
| `sudo systemctl disable --now openbsd-inetd` puis `sudo apt purge inetutils-telnetd` | Port 23 fermé **et** avis supprimés : le service n'avait aucun usage. C'est la vraie réponse au P0. |
| `sudo systemctl disable --now vsftpd` (cas 2 de l'énoncé) | « FTP Unencrypted Cleartext Login » disparaît des deux scans. |
| Mise à jour du noyau sans redémarrage | Les avis disparaissent, car Greenbone vérifie la version du **paquet** installé, pas celle du noyau en cours d'exécution. Bon point de discussion : le risque, lui, n'a pas disparu avant le redémarrage. |

Désactiver Telnet sans supprimer le paquet ne change rien aux scans : le scan non authentifié ne le signalait pas, et l'avis USN reste dans le scan authentifié tant que le paquet est installé. Ce qui est corrigé ici ne sera plus visible au TP 8 : c'est aussi un constat d'audit.

**Étape 11 — contre-scanner.** Relancer la **même** tâche (▶), pas une nouvelle : Greenbone garde les deux rapports, et l'onglet *Reports* permet de les comparer (*Delta*). L'essentiel pédagogique est la **boucle** correction → contre-scan → disparition du résultat. Si le résultat reste : un autre paquet du même avis n'a pas été mis à jour (cas de PHP), la version proposée par `apt-cache policy` est inférieure à la version corrigée, ou le contre-scan a été lancé sur une autre tâche. Durée : l'essai de référence a pris environ 37 minutes par scan, deux scans tournant en même temps ; prévoir 20 à 40 minutes.

**Questions.** 1 : il lit l'état réel des paquets installés via un compte, au lieu de déduire d'une bannière : sur `web`, 13 résultats et une sévérité maximale de 5.0 en non authentifié, 70 résultats et 9.8 en authentifié. 2 : vérifier manuellement avant d'agir ou d'écarter : une QoD faible signale une détection moins fiable, pas un faux positif. Exemple des rapports : le dépôt `.git` exposé (QoD 70 %) est bien réel, il suffit de l'ouvrir dans Firefox ; la renégociation TLS de `srv-int` (QoD 70 %) se vérifie avec `openssl s_client -connect 10.1.20.10:636 -tls1_2`, en tapant `R` une fois la connexion établie. 3 : compte dédié, clé SSH, droits de lecture minimaux, restriction à l'adresse du scanner, activation seulement pendant les fenêtres de scan, rotation du secret, journalisation.

---

[← TP1](../../tp1/README.md) · [Sommaire](../../README.md) · [Énoncé](../README.md) · [En cas de blocage](../../en-cas-de-blocage.md) · [TP3 →](../../tp3/README.md)
