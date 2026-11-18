# Corrigé du TP8

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

**Préparation.** Le dossier `tp8/dossier/dossier-audit-3020.zip` a été collecté sur le laboratoire de référence du formateur, par un script lancé depuis la Kali (configuration de pfSense sans secrets, balayages depuis `ext` et depuis le LAN avec la règle L5 activée le temps de la collecte, `testssl.sh`, `ssh-audit`, `sshd -T`, SNMP, LDAP, RADIUS, IPsec, journalisation, cloisonnement et test de contournement par le `.254`). Les constats ci-dessous sont ceux attendus sur une infrastructure dans l'état de fin de formation ; vérifier chacun dans le dossier réellement distribué avant la correction, certains peuvent différer selon ce qui a été corrigé pendant les TP.

**Gestion du temps (1 h).** Annoncer dès le départ : six constats au maximum, une phrase par case. Passer dans les rangs au bout de 15 minutes : un stagiaire qui n'a encore rien noté est perdu dans les fichiers 01 et 02 ; le renvoyer vers 03 et 13.

## Constats attendus

| Constat | Preuve | Criticité | Référence | Recommandation |
|---|---|---|---|---|
| Le dépôt `.git` du site est lisible depuis Internet et contient un identifiant en clair (`deploy:Deploy2019!`) | 03 (`curl …/.git/config`) | Critique | ISO 27002 8.12 ; 8.4 | Supprimer `/var/www/html/.git`, révoquer le compte `deploy`, interdire les fichiers cachés dans nginx (`location ~ /\. { deny all; }`) |
| Une application de test vulnérable (DVWA), aux identifiants par défaut, est publiée sur Internet | 03 (`/dvwa/login.php` → `200`) | Critique | PCI DSS 2.2.2 ; ISO 27002 8.9 | Retirer l'application du serveur publié |
| Services en clair et vulnérables sur `web` : FTP, Telnet (CVE-2026-24061, au catalogue KEV), versions sans correctifs | 05 ; rapports TP2 | Critique ou Majeure | PCI DSS 2.2.4, 6.3.3 ; ISO 27002 8.8 | Désinstaller FTP et Telnet ; appliquer les correctifs priorisés au TP2 |
| TLS 1.0 et 1.1 acceptés sur le service publié ; certificat autosigné | 04, 06 | Majeure | PCI DSS 4.2.1 ; ISO 27002 8.24 | `ssl_protocols TLSv1.2 TLSv1.3;` ; certificat d'une AC reconnue |
| `web` répond à la communauté SNMP `public` | 08 | Majeure | ISO 27002 8.21 | Désactiver v1/v2c ; SNMPv3 *authPriv* depuis 10.1.10.10 seulement |
| La liste des comptes de l'annuaire est lisible sans authentification ; LDAP en clair encore accepté | 09 | Majeure | ISO 27002 5.15, 8.24 | ACL `by anonymous auth` ; retirer `ldap:///` ou exiger TLS |
| Authentification SSH par mot de passe sur les serveurs | 07 (`passwordauthentication yes` ou `kbdinteractiveauthentication yes`) | Majeure | ISO 27002 8.5 | Clés uniquement ; double authentification pour l'administration |
| Poste d'administration dans le réseau des utilisateurs ; pas de double authentification sur pfSense | 01 (`H_poste_admin` dans `N_LAN`) | Majeure | ISO 27002 8.22 ; PCI DSS 8.4 | Zone d'administration dédiée ; MFA |
| Avec deux routes ajoutées, `web` joint `srv-int:22` par l'équipement de l'hébergeur en `.254`, sans passer par pfSense | 13 (`nc` réussi, `traceroute` : un saut `10.1.30.254`) | Majeure | ISO 27002 8.22, 5.21 ; PCI DSS 11.4.5 | Exiger de l'hébergeur des réseaux isolés en couche 3 (clause contractuelle) ; filtrage local sur chaque serveur ; surveillance des tables de routage |
| Selon l'état de la plateforme : anti-verrouillage actif (tout le LAN joint l'interface de pfSense), redirection temporaire du port 80 oubliée, règle L5 restée active | 01, 02, 03 | Majeure | PCI DSS 1.2 | Désactiver l'anti-verrouillage au profit de L1 ; supprimer les règles temporaires |

**Points positifs attendus** : refus par défaut journalisé sur LAN, SRV et DMZ ; la DMZ ne joint ni la zone serveurs ni le poste d'administration, et ne sort pas librement sur Internet (sans le `.254`) ; zones internes non joignables directement depuis Internet ; tunnel IPsec conforme (IKEv2, AES-256-GCM, groupe 19, PFS, sélecteurs restreints) ; journalisation centralisée et horodatée ; pfSense supervisé en SNMPv3 ; RADIUS avec `Message-Authenticator` et secret long.

**Sur le `.254`.** La segmentation repose en réalité sur la table de routage de chaque machine, qu'un attaquant administrateur d'une machine peut modifier. La correction appartient à l'hébergeur (responsabilité partagée) : elle se traite par contrat et par exigence de preuve (test de segmentation), pas seulement par configuration côté client. C'est le constat le plus formateur du dossier.

**Attendus de rédaction.**

- Un constat est un fait prouvé, avec le nom du fichier.
- Le risque dit ce qui peut arriver, et à qui.
- La recommandation est précise et vérifiable.
- La synthèse parle d'impact métier, sans jargon.
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
