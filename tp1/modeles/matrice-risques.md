# Matrice des risques — TP1

**Auteur :** …  **Date :** …
**Périmètre :** le laboratoire (LAN, SRV, DMZ, WAN simulé).

## 1. Biens essentiels

Ce que l'entreprise cherche à protéger, avec ses besoins de sécurité (1 = faible, 4 = très fort).

| Bien essentiel | Disponibilité | Intégrité | Confidentialité |
|---|---|---|---|
| Annuaire des comptes (srv-int) | | | |
| Application web de l'intranet (web) | | | |
| Données clients | | | |
| Administration du pare-feu | | | |

## 2. Échelles de cotation

**Vraisemblance :** 1 — Peu vraisemblable · 2 — Vraisemblable · 3 — Très vraisemblable · 4 — Quasi certaine
**Gravité :** 1 — Mineure · 2 — Significative · 3 — Grave · 4 — Critique

Le niveau de risque se lit sur la matrice du module 1 :

| Vraisemblance ↓ / Gravité → | 1 — Mineure | 2 — Significative | 3 — Grave | 4 — Critique |
|---|---|---|---|---|
| 4 — Quasi certaine | Moyen | Élevé | Critique | Critique |
| 3 — Très vraisemblable | Faible | Moyen | Élevé | Critique |
| 2 — Vraisemblable | Faible | Moyen | Moyen | Élevé |
| 1 — Peu vraisemblable | Faible | Faible | Faible | Moyen |

## 3. Scénarios de risque

Au moins cinq scénarios, dont les quatre imposés. Pour chacun : le bien support visé, la source de risque, le chemin d'attaque, l'événement redouté.

| # | Thème | Scénario (bien support, source, chemin, événement redouté) | V | G | Niveau | Mesures (préventives, détectives, correctives) | V résiduelle | G résiduelle | Niveau résiduel |
|---|---|---|---|---|---|---|---|---|---|
| R1 | Couche 2 | | | | | | | | |
| R2 | Protocole en clair | | | | | | | | |
| R3 | Cible héritée (`web`) | | | | | | | | |
| R4 | Exposition de la DMZ | | | | | | | | |
| R5 | Au choix | | | | | | | | |

## 4. Priorités

Les trois mesures à mettre en œuvre en premier, et pourquoi :

1. …
2. …
3. …
