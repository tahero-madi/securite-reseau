# Rapport de vulnérabilités — TP2

**Auteur :** …  **Date :** …
**Périmètre :** web (10.1.30.10), srv-int (10.1.20.10). **Outil :** Greenbone Community Edition, configuration *Full and fast*.

## 1. Synthèse des scans

| Scan | Cible | Date | Critical | High | Medium | Low | Fichier CSV |
|---|---|---|---|---|---|---|---|
| Non authentifié | SRV-DMZ | | | | | | `tp2-scan-non-auth.csv` |
| Authentifié | WEB-auth | | | | | | `tp2-scan-auth.csv` |
| Contre-scan | | | | | | | `tp2-contre-scan.csv` |

Ce que le scan authentifié a apporté par rapport au non authentifié (en 3 lignes) :

…

## 2. Vulnérabilités retenues (10 à 15)

Priorités (module 2) : **P0** — corriger immédiatement · **P1** — sous 7 jours · **P2** — sous 30 jours · **P3** — au prochain cycle de maintenance.

| # | Hôte | Vulnérabilité (nom Greenbone) | CVE | CVSS | QoD | Exposé à Internet ? | KEV ? | EPSS | Priorité | Correction proposée |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | | | | | | | | | | |
| 2 | | | | | | | | | | |
| 3 | | | | | | | | | | |
| 4 | | | | | | | | | | |
| 5 | | | | | | | | | | |
| 6 | | | | | | | | | | |
| 7 | | | | | | | | | | |
| 8 | | | | | | | | | | |
| 9 | | | | | | | | | | |
| 10 | | | | | | | | | | |

KEV et EPSS : à vérifier au moins pour les 3 vulnérabilités les plus prioritaires.

## 3. Justification de l'ordre de traitement

Pour les 3 premières : pourquoi passent-elles avant les autres ? (gravité, probabilité d'exploitation, exploitation avérée, exposition de la machine)

1. …
2. …
3. …

## 4. Remédiation et vérification

| Vulnérabilité corrigée | Hôte | Action réalisée (commande) | Présente avant ? | Présente après le contre-scan ? |
|---|---|---|---|---|
| | | | oui | |

Captures d'écran avant/après : …

## 5. Faux positifs écartés

| Vulnérabilité | Hôte | QoD | Pourquoi c'est un faux positif | Comment vous l'avez vérifié |
|---|---|---|---|---|
| | | | | |
