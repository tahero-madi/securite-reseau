# Corrigé du TP8

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

**Préparation.** Le dossier `tp8/dossier/dossier-audit-3020.zip` est un dossier pédagogique : ses sorties sont représentatives de l'infrastructure de référence du laboratoire, dans un état de fin de formation, avec quelques dérives volontaires (redirection « temporaire » oubliée, anti-verrouillage resté actif, FTP corrigé mais Telnet oublié). Il ne dépend pas de l'état des laboratoires des stagiaires.

**Gestion du temps (1 h).** Annoncer dès le départ : six constats au maximum, une phrase par case. Passer dans les rangs au bout de 15 minutes : un stagiaire qui n'a encore rien noté est perdu dans les fichiers 01 et 02 ; le renvoyer vers 03 et 13.

## Constats du dossier

Les six premiers sont ceux qu'on attend dans le top 6 ; les suivants sont des réponses valables si elles sont prouvées et cotées de façon cohérente.

| Constat | Preuve | Criticité | Référence | Recommandation |
|---|---|---|---|---|
| Le dépôt `.git` du site est lisible depuis Internet et livre un identifiant en clair (`deploy:Deploy2019!`) | 03 (`curl …/.git/config`) | Critique | ISO 27002 8.12 | Supprimer `/var/www/html/.git`, révoquer et changer le compte `deploy`, refuser les fichiers cachés dans nginx (`location ~ /\. { deny all; }`) |
| Une application volontairement vulnérable (DVWA, identifiants par défaut `admin/password`) est publiée sur Internet | 03 (`/dvwa/login.php` → `200`, page d'accueil) | Critique | PCI DSS 2.2.2 ; ISO 27002 8.9 | Retirer DVWA (et Juice Shop) du serveur publié |
| Une redirection « Test IDS - temporaire » du 12/11 publie toujours le port 80 en clair sur Internet | 01 (Port Forward), 02 (`rdr … port = http`), 03 (`80/tcp open`, code `200`) | Majeure | PCI DSS 1.2 ; ISO 27002 8.20 | Supprimer la redirection ; toute ouverture temporaire a une date de fin et un responsable |
| Telnet (en clair, `inetutils-telnetd`, CVE-2026-24061 au catalogue KEV) reste ouvert sur `web` ; FTP a été fermé, Telnet oublié | 05 (`23/tcp open telnet`), 08 (inventaire SNMP), rapport TP2 | Majeure (Critique si exposé) | PCI DSS 2.2.4, 6.3.3 ; ISO 27002 8.8 | Désinstaller `inetutils-telnetd` et `openbsd-inetd` |
| Contournement du pare-feu : avec deux routes, `web` joint `srv-int:22` par l'équipement de l'hébergeur en `.254` ; aucun filtrage local sur les serveurs | 13 (`succeeded`, traceroute `10.1.30.254` puis `10.1.20.10`, `nft` vide) | Majeure | ISO 27002 8.22, 5.21 ; PCI DSS 11.4.5 | Exiger de l'hébergeur l'isolation réelle des réseaux (clause contractuelle, test de segmentation) ; filtrage local nftables sur chaque serveur ; surveiller les tables de routage |
| TLS 1.0 et 1.1 acceptés, chiffrements 3DES (SWEET32), certificat autosigné, pas de HSTS, sur le service publié | 04, 06 (`offered (deprecated)`, `VULNERABLE`, `NOT ok (self signed)`, note `T`) | Majeure | PCI DSS 4.2.1 ; ISO 27002 8.24 | `ssl_protocols TLSv1.2 TLSv1.3;` et suites ANSSI ; certificat d'une AC reconnue ; HSTS |
| `web` répond à la communauté SNMP `public` et livre son inventaire logiciel avec les versions | 08 | Majeure | ISO 27002 8.21 | Désactiver v1/v2c sur `web` ; SNMPv3 *authPriv* depuis 10.1.10.10 seulement, comme sur pfSense |
| La liste des comptes et des administrateurs de l'annuaire est lisible sans authentification ; LDAP en clair accepté sur 389 | 09 | Majeure | ISO 27002 5.15, 8.24 | ACL `to * by anonymous auth by users read` ; retirer `ldap:///` ou `olcSecurity: tls=1` |
| SSH par mot de passe (et *keyboard-interactive*) sur les serveurs ; 37 échecs d'authentification dans le journal de `srv-int` ; algorithmes faibles (SHA-1, NIST) | 07 | Majeure | ISO 27002 8.5 | Clés uniquement (`PasswordAuthentication no`, `KbdInteractiveAuthentication no`) ; retirer les algorithmes signalés par `ssh-audit` |
| Règle anti-verrouillage active : tout poste du LAN joint l'interface d'administration de pfSense (la règle L1 restrictive ne sert jamais : 0 paquet) | 01, 02 (compteurs) | Majeure | ISO 27002 8.20 ; PCI DSS 1.2 | Désactiver l'anti-verrouillage (*System → Advanced → Admin Access*) après avoir vérifié L1 |
| Poste d'administration dans le réseau des utilisateurs ; aucune double authentification pour l'administration | 01 (`H_poste_admin` dans `N_LAN`, « Double authentification : aucune ») | Majeure | ISO 27002 8.22 ; PCI DSS 8.4 | Zone d'administration dédiée ; MFA (RADIUS + OTP) |
| Client RADIUS `localhost` avec le secret par défaut `testing123` et sans `Message-Authenticator` | 10 | Mineure | ISO 27002 5.17 | Supprimer le client `localhost` ou changer son secret |
| Journaux de `web` transmis en clair (TCP 514) ; aucune rotation ni durée de rétention définie sur le collecteur ; `web` en UTC, `srv-int` en heure de Paris | 11 | Mineure | ISO 27002 8.15, 8.17 | Syslog sur TLS (6514) ; rotation et rétention (`logrotate`, 6 à 12 mois) ; fuseau homogène ou horodatage avec décalage partout |
| Aucun filtrage local sur `cloud-gw` | 12 (`nft` vide) | Mineure | ISO 27002 8.20 | Groupe de sécurité ou nftables en refus par défaut (voir l'étape de transposition du TP6) |

**Points positifs attendus** :

- refus par défaut journalisé sur LAN, SRV, DMZ et sur l'onglet IPsec (02 : compteurs non nuls) ;
- règle du scanner L5 désactivée hors campagne ;
- zones internes non joignables directement depuis Internet (03) ;
- la DMZ ne joint ni la zone serveurs, ni le poste d'administration, ni Internet hors dépôts (13, sans le `.254`) ;
- FTP fermé depuis le TP2 : remédiation effective ;
- tunnel IPsec conforme (IKEv2, AES-256-GCM, groupe 19, PFS, sélecteurs restreints), tentative du cloud vers le site refusée et journalisée (12) ;
- journalisation centralisée, format RFC 5424, alertes Suricata reçues (11) ;
- pfSense supervisé en SNMPv3 *authPriv* uniquement (08) ;
- client RADIUS pfSense protégé (`Message-Authenticator`, secret de 44 caractères).

**Sur le `.254`.** La segmentation repose en réalité sur la table de routage de chaque machine, qu'un attaquant administrateur d'une machine peut modifier, et aucun filtrage local ne prend le relais. La correction appartient à l'hébergeur (responsabilité partagée) : elle se traite par contrat et par exigence de preuve (test de segmentation), et côté client par une défense en profondeur (filtrage local). C'est le constat le plus formateur du dossier.

**Attendus de rédaction.**

- Un constat est un fait prouvé, avec le nom du fichier.
- Le risque dit ce qui peut arriver, et à qui.
- La recommandation est précise et vérifiable.
- La synthèse parle d'impact métier, sans jargon : par exemple, « un identifiant interne et une application de démonstration vulnérable sont accessibles depuis Internet : un attaquant peut prendre la main sur le serveur web et, de là, viser le reste du réseau ».
- Pénaliser les listes sans priorisation, ou les constats sans preuve.

## Questions

1. Le constat est le fait observé et prouvé ; le risque est la conséquence possible (vraisemblance × impact) ; la recommandation est l'action corrective concrète.
2. L'équipement appartient à l'hébergeur, hors du périmètre du client : le tester sans accord serait une intrusion dans un système tiers. La correction lui revient (isolation réelle des réseaux), à exiger contractuellement ; le client peut seulement compenser (filtrage local).
3. Les règles peuvent être correctes et la segmentation contournable par un autre chemin (`.254`), ou une règle temporaire oubliée : seul le test montre l'écart entre le schéma et la réalité.

---

## Barème indicatif d'évaluation des livrables de TP

| Livrable | Critères | Points |
|---|---|---|
| TP1 cartographie + risques | Exhaustivité, écarts identifiés, cotation justifiée | /10 |
| TP2 rapport de vulnérabilités | Priorisation CVSS/EPSS/KEV, remédiation vérifiée | /10 |
| TP3 matrice + règles | Refus par défaut, tests de flux concluants | /10 |
| TP4 RADIUS/LDAP | Chaîne fonctionnelle, durcissement, LDAPS | /10 |
| TP5 Suricata | Règles maison, blocage IPS | /10 |
| TP6 IPsec (démonstration) | — | — |
| TP7 supervision et journalisation (démonstration) | — | — |
| TP8 rapport d'audit sur dossier | Constats prouvés et cotés, plan d'action, synthèse | /20 |
| QCM final | 30 questions | /30 |

---

[← TP7](../../tp7/README.md) · [Sommaire](../../README.md) · [Énoncé](../README.md) · [En cas de blocage](../../en-cas-de-blocage.md)
