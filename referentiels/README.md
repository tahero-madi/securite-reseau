# Référentiels cités dans le cours

Les guides et référentiels de l'ANSSI présentés pendant la formation, classés par module. Ils sont gratuits et publiés sous Licence ouverte (Etalab 2.0). Chaque lien ouvre la page officielle du guide, qui donne accès au PDF à jour : téléchargez toujours la dernière version depuis ces pages, les guides sont révisés régulièrement.

En fin de page : les CIS Benchmarks et les rôles Ansible Lockdown qui les appliquent.

La plupart des guides sont rassemblés sur [MesServicesCyber](https://messervices.cyber.gouv.fr/catalogue#guides), le portail de l'ANSSI qui remplace l'ancienne rubrique « Publications » de cyber.gouv.fr. Plusieurs existent aussi en anglais.

## Par où commencer

Si vous ne deviez en lire que trois :

1. le **Guide d'hygiène informatique** : 42 mesures, le socle minimal ;
2. les **Recommandations pour la définition d'une politique de filtrage réseau d'un pare-feu** : court et directement applicable au TP3 ;
3. les **Recommandations relatives à l'administration sécurisée des SI** : la référence pour isoler l'administration.

## Module 1 — Menaces, vulnérabilités, analyse de risques

| Document | Utilité dans le cours |
|---|---|
| [Guide d'hygiène informatique](https://messervices.cyber.gouv.fr/guides/guide-dhygiene-informatique) | 42 mesures de base ; point de départ d'un premier plan d'action |
| [La méthode EBIOS Risk Manager — Le guide](https://messervices.cyber.gouv.fr/guides/la-methode-ebios-risk-manager-le-guide) | Méthode d'analyse de risques en cinq ateliers (avec le Club EBIOS) |
| [Cartographie du système d'information](https://messervices.cyber.gouv.fr/guides/cartographie-du-systeme-dinformation) | Actifs, flux, interconnexions, administrateurs : le livrable du TP1 |
| [Panoramas de la cybermenace](https://cyber.gouv.fr/nous-connaitre/publications/panoramas-de-la-cybermenace/) | Bilan annuel de la menace en France |

## Module 3 — Sécurisation des réseaux internes et externes

| Document | Utilité dans le cours |
|---|---|
| [Définition d'une politique de filtrage réseau d'un pare-feu](https://messervices.cyber.gouv.fr/guides/definition-dune-politique-de-pare-feu) | Les principes de la politique de filtrage : refus par défaut, règles documentées (TP3) |
| [Nettoyage d'une politique de filtrage réseau d'un pare-feu](https://messervices.cyber.gouv.fr/guides/recommandations-et-methodologie-pour-le-nettoyage-dune-politique-de-filtrage-reseau) | Revoir et assainir une politique existante (complément) |
| [Recommandations relatives à l'interconnexion d'un SI à Internet](https://messervices.cyber.gouv.fr/guides/recommandations-relatives-linterconnexion-dun-si-internet) | Passerelle Internet, DMZ, proxys, filtrage sortant |
| [Recommandations relatives à l'administration sécurisée des SI](https://messervices.cyber.gouv.fr/guides/recommandations-relatives-ladministration-securisee-des-si) | Zone et postes d'administration dédiés |

## Module 4 — Gestion des accès et authentification

| Document | Utilité dans le cours |
|---|---|
| [Recommandations de déploiement du protocole 802.1X](https://messervices.cyber.gouv.fr/guides/recommandations-de-deploiement-du-protocole-8021x) | Contrôle d'accès aux réseaux locaux, choix de la méthode EAP |
| [Recommandations relatives à l'authentification multifacteur et aux mots de passe](https://messervices.cyber.gouv.fr/guides/recommandations-relatives-lauthentification-multifacteur-et-aux-mots-de-passe) | Facteurs d'authentification, politique de mots de passe |
| [Recommandations de sécurité relatives à Active Directory](https://messervices.cyber.gouv.fr/guides/recommandations-de-securite-relatives-active-directory) | Durcissement d'AD |
| [Administration sécurisée des SI reposant sur AD](https://messervices.cyber.gouv.fr/guides/recommandations-pour-ladministration-securisee-des-si-reposant-sur-ad) | Le modèle d'administration en tiers |
| [ORADAD](https://github.com/ANSSI-FR/ORADAD) | Outil de collecte de l'ANSSI pour l'audit d'AD, utilisé avec les points de contrôle AD du CERT-FR |

## Module 5 — Solutions de sécurité avancées (chiffrement)

| Document | Utilité dans le cours |
|---|---|
| [Recommandations de sécurité relatives à IPsec](https://messervices.cyber.gouv.fr/guides/recommandations-de-securite-relatives-ipsec) | Paramètres IPsec conformes : IKEv2, AES-GCM, PFS (TP6) |
| [Recommandations de sécurité relatives à TLS](https://messervices.cyber.gouv.fr/guides/recommandations-de-securite-relatives-tls) | Versions et suites TLS acceptables |
| [Usage sécurisé d'(Open)SSH](https://messervices.cyber.gouv.fr/guides/usage-securise-dopenssh) | Configuration de SSH, contrôlée avec `ssh-audit` |
| [Mécanismes cryptographiques](https://messervices.cyber.gouv.fr/guides/mecanismes-cryptographiques) | Règles et recommandations sur les algorithmes et tailles de clés |
| [Guide de sélection d'algorithmes cryptographiques (PDF)](https://messervices.cyber.gouv.fr/documents-guides/anssi-guide-selection_crypto-1.0.pdf) | Version pratique du précédent |
| Transition post-quantique : [TLS 1.3](https://messervices.cyber.gouv.fr/guides/Transition-post-quantique-protocole-TLS-1-3), [IPsec](https://messervices.cyber.gouv.fr/guides/Transition-post-quantique-protocole-IPsec), [SSHv2](https://messervices.cyber.gouv.fr/guides/Transition-post-quantique-protocole-SSHv2) | Mécanismes hybrides (ML-KEM + échange classique) |
| [Avis de l'ANSSI sur la migration vers la cryptographie post-quantique](https://messervices.cyber.gouv.fr/guides/avis-de-lanssi-sur-la-migration-vers-la-cryptographie-post-quantique) | La position de l'ANSSI et le calendrier |

## Module 6 — Cloud et hybride

| Document | Utilité dans le cours |
|---|---|
| [Recommandations pour l'hébergement dans le cloud des SI sensibles](https://messervices.cyber.gouv.fr/guides/recommandations-pour-lhebergement-des-si-sensibles-dans-le-cloud) | Choix d'hébergement selon la sensibilité des données |
| [Référentiels d'exigences pour la qualification](https://cyber.gouv.fr/offre-de-service/solutions-certifiees-et-qualifiees/comprendre-levaluation-de-securite/qualification-de-produit-et-services/referentiels-qualification/) | Contient le référentiel **SecNumCloud** (offres cloud de confiance) |

## Module 7 — Surveillance et gestion des incidents

| Document | Utilité dans le cours |
|---|---|
| [Recommandations de sécurité pour l'architecture d'un système de journalisation](https://messervices.cyber.gouv.fr/guides/recommandations-de-securite-pour-larchitecture-dun-systeme-de-journalisation) | Quoi journaliser, centralisation, horodatage, conservation (TP7). Remplace l'ancien guide « pour la mise en œuvre d'un système de journalisation » |
| [Crise cyber, les clés d'une gestion opérationnelle et stratégique](https://messervices.cyber.gouv.fr/guides/crise-cyber-les-cles-dune-gestion-operationnelle-et-strategique) | Organiser la gestion de crise |
| [Organiser un exercice de gestion de crise cyber](https://messervices.cyber.gouv.fr/guides/organiser-un-exercice-de-gestion-de-crise-cyber) | Préparer et jouer un exercice |
| [Anticiper et gérer sa communication de crise cyber](https://messervices.cyber.gouv.fr/guides/anticiper-et-gerer-sa-communication-de-crise-cyber) | Le volet communication |
| [CERT-FR](https://www.cert.ssi.gouv.fr/) | Avis et alertes de sécurité, en français |

## Module 8 — Audit et référentiels

| Document | Utilité dans le cours |
|---|---|
| [Référentiels d'exigences pour la qualification](https://cyber.gouv.fr/offre-de-service/solutions-certifiees-et-qualifiees/comprendre-levaluation-de-securite/qualification-de-produit-et-services/referentiels-qualification/) | Contient les référentiels **PASSI** (prestataires d'audit), **PDIS** (détection) et **PRIS** (réponse aux incidents) |
| [La directive NIS 2](https://cyber.gouv.fr/reglementation/cybersecurite-systemes-dinformation/directives-nis-nis2-et-dispositif-saiv/directive-nis-2/) | Entités concernées, obligations, et le référentiel de mesures **ReCyF** |

## Pour les serveurs du laboratoire

| Document | Utilité dans le cours |
|---|---|
| [Recommandations de configuration d'un système GNU/Linux](https://messervices.cyber.gouv.fr/guides/recommandations-de-securite-relatives-un-systeme-gnulinux) | Durcissement des serveurs Linux, en complément de Lynis et des CIS Benchmarks |

## Hors ANSSI — CIS Benchmarks et Ansible Lockdown

Les CIS Benchmarks sont les guides de durcissement du Center for Internet Security, publiés pour chaque système, logiciel et équipement réseau. Ils sont gratuits en PDF, après inscription. Chaque recommandation y a un niveau : le niveau 1 se met en place sans gêner l'exploitation, le niveau 2 vise les environnements plus exposés. Ansible Lockdown applique ces benchmarks automatiquement, avec des rôles Ansible open source.

| Ressource | Utilité dans le cours |
|---|---|
| [Liste des CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks) | Tous les benchmarks : systèmes, navigateurs, bases de données, cloud, équipements réseau |
| [Télécharger les benchmarks (PDF)](https://learn.cisecurity.org/benchmarks) | Formulaire d'accès aux PDF gratuits |
| [CIS Benchmark Ubuntu Linux](https://www.cisecurity.org/benchmark/ubuntu_linux) | `srv-int`, `web` et `cloud-gw` (Ubuntu Server 24.04 LTS) |
| [CIS Benchmark Debian Linux](https://www.cisecurity.org/benchmark/debian_linux) | Base de la Kali |
| [CIS-CAT Lite](https://learn.cisecurity.org/cis-cat-lite) | Outil gratuit du CIS qui mesure la conformité d'une machine à un benchmark et produit un rapport HTML avec un score. Application Java, fournie avec son environnement d'exécution (JRE) ; la version Lite ne couvre que Windows 10 et 11, Google Chrome et Ubuntu 20.04 : pas Ubuntu 24.04 ([liste exacte](https://ciscat-assessor.docs.cisecurity.org/en/latest/Coverage%20Guide/)). Pour les serveurs du laboratoire, utiliser `UBUNTU24-CIS-Audit` (ci-dessous) |
| [CIS-CAT Pro Assessor](https://www.cisecurity.org/cybersecurity-tools/cis-cat-pro) | Version complète, tous les benchmarks, réservée aux membres de CIS SecureSuite ([documentation](https://ciscat-assessor.docs.cisecurity.org/en/latest/About/)) |
| [Ansible Lockdown](https://github.com/ansible-lockdown) | Les rôles Ansible qui appliquent les CIS Benchmarks (et les STIG du DoD américain) |
| [UBUNTU24-CIS](https://github.com/ansible-lockdown/UBUNTU24-CIS) | Rôle de durcissement CIS pour Ubuntu 24.04 : celui des serveurs du laboratoire |
| [UBUNTU24-CIS-Audit](https://github.com/ansible-lockdown/UBUNTU24-CIS-Audit) | Audit de conformité CIS (Goss), sans rien modifier : à lancer avant et après le durcissement |
| [DEBIAN12-CIS](https://github.com/ansible-lockdown/DEBIAN12-CIS) | Rôle de durcissement CIS pour Debian 12 |

> **Prudence.** Un rôle Ansible Lockdown modifie des centaines de paramètres : SSH, pare-feu local, comptes, journalisation. Lancez d'abord l'audit seul, puis appliquez le rôle sur une copie (instantané), en n'activant que les sections voulues : appliqué tel quel sur `srv-int`, il peut couper l'accès SSH ou casser LDAP, RADIUS ou Zabbix.

---

[Sommaire](../README.md)
