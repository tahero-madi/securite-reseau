# Rapport d'audit de sécurité réseau — TP8

**Auditeur :** …  **Dates de l'audit :** …  **Version du rapport :** 1.0
**Commanditaire :** … (formateur)  **Mandat :** `mandat-audit-TP8.pdf`, signé le …
**Diffusion :** confidentielle, commanditaire et auditeur uniquement.

## 1. Synthèse pour la direction

Une demi-page, sans jargon technique. Écrivez pour quelqu'un qui décide et finance, pas pour un administrateur.

**Niveau global de sécurité :** … (par exemple : insuffisant / à améliorer / satisfaisant), en deux ou trois phrases.

**Les trois risques majeurs :**

1. …
2. …
3. …

**Les priorités :**

- Dans la semaine : …
- Dans le mois : …
- Dans le trimestre : …

**Points positifs :** …

## 2. Contexte, périmètre et limites

| Élément | Détail |
|---|---|
| Objectif de l'audit | |
| Périmètre audité | |
| Hors périmètre | |
| Type d'audit | Boîte blanche : architecture, configuration, vérification active |
| Dates et durée | |
| Limites (ce qui n'a pas pu être testé, et pourquoi) | |

## 3. Audit d'architecture

| Point de contrôle | Conforme / Partiel / Non conforme | Constat et preuve |
|---|---|---|
| Zones de confiance définies et cloisonnées | | |
| DMZ : flux entrants terminés en DMZ, DMZ → interne restreint | | |
| Filtrage sortant en place | | |
| Administration isolée, protocoles chiffrés | | |
| Services d'infrastructure protégés (LDAP chiffré, SNMPv3, RADIUS) | | |
| Interconnexion cloud chiffrée et filtrée | | |
| Journalisation centralisée et horodatée | | |
| IPv6 pris en compte ou neutralisé | | |
| Aucun chemin ne contourne le pare-feu | | |

## 4. Constats détaillés

Triés par criticité : Critique, puis Majeure, puis Mineure, puis Observation. Copiez le bloc autant de fois que nécessaire.

### C-01 — Titre court du constat

| Champ | Contenu |
|---|---|
| Criticité | Critique / Majeure / Mineure / Observation |
| Machine(s) concernée(s) | |
| Fait constaté | Ce que vous avez observé, sans interprétation |
| Preuve | Fichier de `preuves/`, extrait de sortie, capture |
| Risque | Ce qui peut arriver, et à qui, si rien n'est fait |
| Référentiel | ISO/IEC 27002:2022 … ; PCI DSS v4.0.1 … ; guide ANSSI … |
| Recommandation | Action précise et vérifiable |
| Effort estimé | Faible / Moyen / Élevé |

### C-02 — …

| Champ | Contenu |
|---|---|
| Criticité | |
| Machine(s) concernée(s) | |
| Fait constaté | |
| Preuve | |
| Risque | |
| Référentiel | |
| Recommandation | |
| Effort estimé | |

## 5. Plan d'action priorisé

| Priorité | Constat(s) | Action | Responsable | Échéance | Vérification de la correction |
|---|---|---|---|---|---|
| 1 | | | | | |
| 2 | | | | | |
| 3 | | | | | |
| 4 | | | | | |
| 5 | | | | | |

## 6. Annexes

### 6.1 Outils et versions

| Outil | Version | Usage |
|---|---|---|
| nmap | | |
| testssl.sh | | |
| ssh-audit | | |
| Greenbone | | |
| Wireshark | | |

### 6.2 Méthode

…

### 6.3 Liste des preuves

| Fichier | Contenu | Constat(s) |
|---|---|---|
| `preuves/…` | | |
