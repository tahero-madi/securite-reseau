# Corrigé du TP8

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

**Préparation.** Remettre un **mandat écrit** type (périmètre, autorisations, interdictions, contacts, confidentialité) : c'est un objectif pédagogique en soi (pas d'audit sans mandat). Selon l'avancement des TP précédents, l'état de durcissement varie d'un apprenant à l'autre — c'est voulu : chacun audite l'état réel de son lab, ce qui rend l'exercice authentique.

**Constats typiques attendus** (selon ce que l'apprenant a durci ou non) :
- `web` exposant des services anciens (FTP/Telnet, versions obsolètes), mal cloisonné → Critique (ISO 27002 8.8, 8.22 ; PCI DSS 2, 6, 11 ; guide ANSSI).
- TLS de `web` : si configuration par défaut, suites ou versions faibles → Majeure (ISO 27002 8.24 ; PCI DSS 4).
- SNMP v2c avec communauté `public` sur `web`, ou résiduel sur pfSense → Majeure (ISO 27002 8.20/8.21).
- Annuaire LDAP lisible anonymement (ACL par défaut d'OpenLDAP) et bind en clair encore accepté → Majeure (ISO 27002 8.3, 8.24).
- Poste d'administration dans le LAN utilisateurs, sans zone d'administration dédiée → Majeure (guide ANSSI d'administration sécurisée).
- Authentification SSH par mot de passe sur les serveurs (`ssh-audit`, `sshd -T`) → Mineure/Majeure.
- Absence de filtrage egress → Majeure.
- Règles pfSense `any` ou inutilisées → Majeure/Mineure selon exposition.
- Admin non restreinte / sans MFA → Critique/Majeure (ISO 27002 8.2, 8.5 ; PCI DSS 7, 8).
- IPsec conforme (après TP 6) → point positif à valoriser.

**Attendus de rédaction.** Distinguer fait / risque / recommandation ; preuve systématique (extrait de scan, de config, capture) ; recommandations concrètes (« désactiver SNMPv2c sur fw, n'autoriser SNMPv3 authPriv que depuis 10.1.20.10 ») ; synthèse dirigeants sans jargon ; tri par criticité + effort. Pénaliser les rapports « copier-coller de scanner » sans priorisation ni preuve.

**Vérification active.** Le test d'un chemin censé fermé (`web → srv-int`) est le réflexe clé : la segmentation se prouve, elle ne se présume pas (lien PCI DSS 11.4.x sur le test de segmentation).

**Questions.** 1 : le constat est le fait observé (prouvé) ; le risque est la conséquence possible (vraisemblance × impact) ; la recommandation est l'action corrective concrète. 2 : une segmentation documentée mais mal filtrée laisse des chemins ouverts ; seul le test révèle l'écart entre schéma et réalité. 3 : réponse individuelle — vérifier la cohérence constat ↔ preuve ↔ référentiel.

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
