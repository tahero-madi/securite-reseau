# TP8 — Audit de sécurité réseau et rapport

**Jour 4, 13:35 · 1 h 45, pause incluse.** Objectifs : conduire un audit complet de votre propre laboratoire (architecture + configuration + vérification active), coter les constats, les relier aux référentiels, et produire un rapport d'audit exploitable. Ce TP est une synthèse de toute la formation.

**Prérequis** : modules 1 à 8 et tous les TP. **Périmètre** : votre laboratoire uniquement. **Livrable** : un `rapport-audit` structuré (synthèse dirigeants + constats cotés et prouvés + plan d'action priorisé).

## Mise en situation

Vous intervenez comme auditeur sur le système d'information d'une PME, reproduit par votre laboratoire. Le **mandat** `~/TP/mandat-audit-TP8.pdf` (à lire et signer) vous autorise à auditer les réseaux `10.1.0.0/16`, la DMZ, le VPC et l'« Internet simulé » `203.0.113.0/24` de votre laboratoire, en boîte blanche (vous avez accès aux configurations). Actions destructrices interdites. Vous disposez de 1 h 30 pour auditer et rédiger.

## Partie A — Collecte et cartographie (15 min)

1. Rassemblez les éléments : topologie, matrice de flux (TP 3), configuration pfSense (*Diagnostics → Command Prompt* ou export), résultats de scan (TP 2), inventaire (TP 1). Reconstituez la cartographie réelle et notez les écarts avec la documentation.

## Partie B — Audit d'architecture (20 min)

2. Évaluez l'architecture au regard des bonnes pratiques (module 3). Grille :

| Point de contrôle | Conforme ? | Constat / preuve |
|---|---|---|
| Zones de confiance définies et cloisonnées | | |
| DMZ : flux entrants terminés, DMZ→interne restreint | | |
| Filtrage sortant (egress) en place | | |
| Administration isolée (pas depuis le LAN bureautique, protocoles chiffrés) | | |
| Services d'infra protégés (DNS, LDAP chiffré, SNMPv3) | | |
| Interconnexion cloud chiffrée et filtrée | | |
| Journalisation centralisée et horodatée | | |
| IPv6 pris en compte ou neutralisé | | |

## Partie C — Audit de configuration (25 min)

3. Contrôlez les configurations clés contre un guide de durcissement (CIS / ANSSI / éditeur) :
   - **pfSense** : refus par défaut ? règles `any` ? règles inutilisées (compteurs à zéro dans *Firewall → Rules*, colonne states/bytes) ? journalisation des refus ? admin restreint ?
   - **Commutation/L2** (selon ce qui est exposé dans le lab) : SNMPv3 only, pas de v2c ; services d'admin chiffrés.
   - **VPN IPsec** : IKEv2, AES-GCM, SHA-2, DH 19, PFS (TP 6) ?
   - **TLS du serveur web** : testez `web` : `testssl.sh https://10.1.30.10` (ou `nmap --script ssl-enum-ciphers -p 443 10.1.30.10`). Versions et suites conformes ?
   - **SSH** des serveurs : `ssh-audit 10.1.20.10`. Algorithmes faibles ? mot de passe autorisé ?
   - **RADIUS/LDAP** : `Message-Authenticator` exigé ? LDAP chiffré ?

## Partie D — Vérification active (15 min)

4. Rejouez un scan ciblé depuis **l'extérieur** (`ssh stagiaire@203.0.113.31` puis `sudo nmap -sS -sV 203.0.113.11`, ou `testssl.sh https://203.0.113.11`) et depuis **le LAN** (Greenbone ou `nmap --script vuln` depuis le poste). Vérifiez des **chemins d'isolation** censés être fermés : `web → srv-int:22`, `client → srv-int:22`, `client → https://10.1.10.1` (GUI pfSense). Confirmez l'exposition réelle du service publié (seul 443 depuis `ext`). N'oubliez pas les services d'infrastructure : `snmpwalk -v2c -c public 10.1.30.10 system` (communauté par défaut ?) et `ldapsearch -x -H ldap://10.1.20.10 -b dc=lab,dc=local uid` (lecture anonyme de l'annuaire ?).

## Partie E — Cotation et rapport (20 min)

5. Pour chaque constat, renseignez : titre, **criticité** (Critique/Majeure/Mineure/Observation), description, **preuve**, référentiel associé (ISO 27002:2022, PCI DSS v4.0.1, guide ANSSI…), **recommandation actionnable**, effort estimé.
6. Rédigez `rapport-audit` :
   - **Synthèse pour la direction** (½ page, sans jargon) : niveau global, 3 risques majeurs, priorités ;
   - **Contexte et périmètre** (et limites) ;
   - **Constats détaillés** triés par criticité (avec preuves) ;
   - **Plan d'action priorisé** (qui / quoi / quand) ;
   - **Annexe** : outils et versions, méthode.

> **Défi ★.** Reliez chacun de vos constats majeurs à une ligne précise de PCI DSS v4.0.1 et d'ISO/IEC 27002:2022, et indiquez si la segmentation de votre lab permettrait de réduire un périmètre « CDE ». Discutez de ce que NIS 2 ajouterait en termes d'obligations.

**Livrable** : `rapport-audit` complet. Restitution orale de 5 minutes par apprenant (synthèse + top 3 des recommandations) si le temps le permet.

## Questions de validation

1. Quelle est la différence entre un constat, un risque et une recommandation dans un rapport ?
2. Pourquoi faut-il vérifier activement l'isolation plutôt que se fier au schéma ?
3. Citez un constat de votre audit et reliez-le à un référentiel précis.

---

[← TP7](../tp7/README.md) · [Sommaire](../README.md) · [Corrigé](corrige/README.md) · [En cas de blocage](../en-cas-de-blocage.md)
