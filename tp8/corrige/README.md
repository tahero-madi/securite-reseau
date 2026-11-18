# Corrigé du TP8

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

**Préparation.** Le mandat type `~/TP/mandat-audit-TP8.pdf` (périmètre, autorisations, interdictions, contacts, confidentialité) est un objectif pédagogique en soi : pas d'audit sans mandat. Selon l'avancement des TP précédents, l'état de durcissement varie d'un apprenant à l'autre ; c'est voulu : chacun audite l'état réel de son laboratoire. Le formateur joue le commanditaire, en particulier pour donner (ou non) l'accord de l'étape 12.

## Étapes 1 à 3 — Mandat, préparation, collecte

Attendus : périmètre et exclusions relevés dans le rapport (section 2) ; dossier `preuves/` créé dès le début ; sauvegarde XML de pfSense traitée comme confidentielle. Un auditeur qui teste 10.10.0.1 ou une adresse en `.254` sans accord est hors mandat : à relever à l'oral.

## Étapes 4 à 9 — Architecture et configurations

Résultats typiques, selon ce que l'apprenant a durci ou non :

| Contrôle | Commande ou lieu | Résultat attendu sur un laboratoire non durci |
|---|---|---|
| Règles | `pfctl -vsr` | Refus par défaut journalisé sur LAN, SRV, DMZ ; L5 désactivée (compteurs à 0) ; redirection du port 80 du TP5 éventuellement oubliée |
| TLS de `web` | `testssl.sh` | `TLS 1` et `TLS 1.1` **offered**, certificat autosigné (*Chain of trust: NOT ok*) |
| SSH | `ssh-audit`, `sshd -T` | Quelques algorithmes en `[warn]` ; `passwordauthentication yes` sur tous les serveurs |
| IPsec | `swanctl --list-sas` | Conforme (point positif) |
| SNMP | `snmpwalk -v2c -c public` | `web` répond : communauté par défaut, en clair |
| LDAP | `ldapsearch -x` sans `-D` | Les trois personnes s'affichent : lecture anonyme (ACL par défaut d'OpenLDAP sous Ubuntu) |
| LDAP | `/etc/default/slapd` | `ldap:///` présent : bind en clair possible sur 389 |
| RADIUS | `clients.conf` | `require_message_authenticator = yes`, secret de 44 caractères (si le TP4 a été suivi) |

## Étapes 10 à 13 — Vérification active

| Test | Attendu |
|---|---|
| `nmap` depuis `ext` vers 10.10.0.20 | Seul `443/tcp open` (nginx) ; si 80 répond, la publication temporaire du TP5 n'a pas été retirée |
| `ext` → 10.1.30.10:443 et 10.1.20.10:22 | `timed out` : refus par défaut du WAN |
| `web` → `srv-int:22`, `web` → Kali:22 | `timed out` (D4) |
| Poste utilisateur → `srv-int:22`, → `https://10.1.10.1` | Échec (L10 ; anti-verrouillage désactivé ou restreint au TP3) |
| `nmap` des zones depuis la Kali | `srv-int` : 22, 389, 636, 10050 (RADIUS, en UDP, n'apparaît pas dans ce balayage TCP) ; `web` : 21, 22, 23, 80, 443, 3000, selon les remédiations du TP2 |
| Contournement par `.254` | `nc` réussit ; `traceroute` : un seul saut, `10.1.30.254` |

La publication en 443 expose aussi tout ce que sert `web` en HTTPS : depuis `ext`, `curl -sk https://10.10.0.20/.git/config` renvoie l'identifiant `deploy:Deploy2019!` (déjà relevé au TP5), et DVWA est joignable avec ses identifiants par défaut. Un bon auditeur fait le lien entre le port « autorisé » et ce qu'il publie réellement.

Remise en ordre attendue : L5 désactivée, routes `.254` retirées, adresse 10.1.10.20 retirée.

## Étapes 14 et 15 — Constats typiques attendus

| Constat | Criticité | Référentiels | Recommandation |
|---|---|---|---|
| Dépôt `.git` exposé sur Internet, avec un identifiant en clair | Critique | ISO 27002 8.4, 8.12 ; PCI DSS 6.4 | Supprimer `/var/www/html/.git`, révoquer le compte `deploy`, interdire les fichiers cachés dans nginx (`location ~ /\. { deny all; }`) |
| Application de test (DVWA) avec identifiants par défaut, publiée sur Internet | Critique | ISO 27002 8.5, 8.9 ; PCI DSS 2.2.2 | Retirer l'application du serveur publié ; changer tout identifiant par défaut |
| Services anciens sur `web` (FTP, Telnet), versions vulnérables | Critique ou Majeure selon le TP2 | ISO 27002 8.8, 8.22 ; PCI DSS 2.2.4, 6.3.3 | Désinstaller ; appliquer les correctifs du TP2 |
| TLS 1.0 et 1.1 acceptés sur le service publié, certificat autosigné | Majeure | ISO 27002 8.24 ; PCI DSS 4.2.1 ; guide ANSSI TLS | `ssl_protocols TLSv1.2 TLSv1.3;`, certificat d'une AC reconnue |
| SNMP v2c `public` sur `web` | Majeure | ISO 27002 8.20, 8.21 | Désactiver v2c ; SNMPv3 *authPriv* depuis 10.1.10.10 seulement |
| Annuaire lisible anonymement, bind en clair accepté | Majeure | ISO 27002 5.15, 8.3, 8.24 | ACL `olcAccess` : `by anonymous auth` seulement ; retirer `ldap:///` ou exiger TLS (`olcSecurity: tls=1`) |
| Authentification SSH par mot de passe | Majeure | ISO 27002 8.5 ; PCI DSS 8.3 | Clés uniquement (`PasswordAuthentication no`), MFA pour l'administration |
| Poste d'administration dans le LAN des utilisateurs | Majeure | Guide ANSSI d'administration sécurisée ; ISO 27002 8.22 | Zone d'administration dédiée, poste dédié |
| Aucune double authentification sur l'administration de pfSense | Majeure | ISO 27002 8.5 ; PCI DSS 8.4 | MFA (RADIUS + OTP, par exemple) |
| Mot de passe par défaut de Zabbix, si non changé au TP7 | Majeure | ISO 27002 5.17 | Changer, comptes nominatifs |
| Équipement de l'hébergeur présent dans toutes les zones et capable de router entre elles | Majeure | ISO 27002 8.22, 5.21, 5.22 ; PCI DSS 1.2, 11.4.5 | Voir ci-dessous |
| Tunnel IPsec conforme, journalisation centralisée en place | Observation (positive) | — | Maintenir ; passer aux certificats |

**Le contournement par `.254`.** Avec deux routes temporaires, `web` joint `srv-int:22` sans passer par pfSense : la segmentation repose sur la seule configuration des routes de chaque machine, qu'un attaquant administrateur d'une machine peut modifier. Recommandations : exiger de l'hébergeur des réseaux réellement isolés en couche 3 (ou un filtrage sur son routeur), et l'inscrire dans la convention de service (responsabilité partagée) ; à défaut, un filtrage local sur chaque serveur (nftables, refus par défaut en entrée) et une surveillance des tables de routage. Lien avec PCI DSS 11.4.5 : la segmentation doit être **testée**, pas présumée.

**Attendus de rédaction.**

- Distinguer fait, risque et recommandation.
- Une preuve pour chaque constat (fichier de `preuves/`).
- Des recommandations concrètes et vérifiables (« désactiver SNMP v2c sur `web`, n'autoriser SNMPv3 *authPriv* que depuis 10.1.10.10 », pas « durcir SNMP »).
- Une synthèse pour la direction sans jargon, qui parle d'impact métier (fuite de données clients, arrêt de service, sanction).
- Un tri par criticité et un plan d'action réaliste (effort, responsable, échéance).
- Pénaliser les rapports « copier-coller de scanner », sans priorisation ni preuve.

## Questions

1. Le constat est le fait observé et prouvé ; le risque est la conséquence possible (vraisemblance × impact) ; la recommandation est l'action corrective concrète.
2. Une segmentation documentée mais mal filtrée, ou contournable (`.254`), laisse des chemins ouverts : seul le test révèle l'écart entre le schéma et la réalité.
3. Réponse individuelle : vérifier la cohérence constat ↔ preuve ↔ référentiel.

---

## Barème indicatif d'évaluation des livrables de TP

| Livrable | Critères | Points |
|---|---|---|
| TP1 cartographie + risques | Exhaustivité, écarts identifiés, cotation justifiée | /10 |
| TP2 rapport de vulnérabilités | Priorisation CVSS/EPSS/KEV, remédiation vérifiée | /10 |
| TP3 matrice + règles | Refus par défaut, tests de flux concluants | /10 |
| TP4 RADIUS/LDAP | Chaîne fonctionnelle, durcissement, LDAPS | /10 |
| TP5 Suricata | Règles maison, blocage IPS, réglage justifié | /10 |
| TP6 IPsec + SG | Tunnel conforme, chiffrement prouvé, transposition | /10 |
| TP7 supervision + incident | Centralisation, trigger, fiche d'incident | /10 |
| TP8 rapport d'audit | Constats prouvés et cotés, plan d'action, synthèse | /20 |
| QCM final | 30 questions | /30 |

---

[← TP7](../../tp7/README.md) · [Sommaire](../../README.md) · [Énoncé](../README.md) · [En cas de blocage](../../en-cas-de-blocage.md)
