# TP8 — Audit de sécurité réseau sur dossier

**Jour 4, 13:00 · 1 h.** Objectifs : analyser un dossier de preuves collectées sur l'infrastructure du laboratoire ; en tirer des constats prouvés ; les coter et les relier à un référentiel ; rédiger un rapport court, exploitable par une direction et par une équipe technique. Ce TP fait la synthèse de la formation : chaque constat renvoie à une notion vue entre le module 1 et le module 8.

**Prérequis** : modules 1 à 8. **Livrable** : `rapport-audit.md` complété, dans `~/livrables`.

**Déroulé** : étape 1 (dossier et mandat) 5 min · étape 2 (analyse des preuves) 25 min · étape 3 (cotation) 10 min · étape 4 (rédaction) 15 min · étape 5 (restitution) 5 min.

## Mise en situation

Un cabinet d'audit est intervenu sur le système d'information d'une PME : c'est l'infrastructure de votre laboratoire, dans l'état où le formateur l'a configurée. L'équipe de terrain a fait les vérifications techniques, sous mandat, et vous remet son **dossier de preuves** : configuration du pare-feu, balayages depuis Internet et depuis l'intérieur, tests TLS, SSH, SNMP, LDAP, état du VPN, de la journalisation et du cloisonnement. Les rapports de vulnérabilités Greenbone du TP2 complètent le dossier.

Vous êtes l'auditeur chargé de l'analyse et du rapport. Vous ne refaites pas les tests : vous **lisez les preuves**, vous en tirez les constats, vous les hiérarchisez, et vous dites au client par quoi commencer.

## Étape 1 — Récupérer le dossier et le modèle de rapport

**Pourquoi.** Un auditeur travaille à partir de preuves datées et conservées. Chaque constat de votre rapport devra citer le fichier qui le prouve.

```bash
mkdir -p ~/livrables && cd ~/livrables
curl -fsSLO https://raw.githubusercontent.com/tahero-madi/securite-reseau/main/tp8/dossier/dossier-audit-3020.zip
unzip -q dossier-audit-3020.zip
curl -fsSLO https://raw.githubusercontent.com/tahero-madi/securite-reseau/main/tp8/modeles/rapport-audit.md
cat dossier-audit-3020/00-LISEZMOI.txt
mousepad rapport-audit.md &
```

**Ligne par ligne.**

- `mkdir -p ~/livrables && cd ~/livrables` : se place dans le dossier des livrables, en le créant s'il n'existe pas.
- `curl -fsSLO <adresse>` : télécharge le fichier depuis le dépôt et garde son nom.
- `unzip -q dossier-audit-3020.zip` : extrait le dossier de preuves dans `~/livrables/dossier-audit-3020/`.
- `cat …/00-LISEZMOI.txt` : affiche l'index du dossier : un fichier par domaine contrôlé.
- `mousepad rapport-audit.md &` : ouvre le modèle de rapport dans l'éditeur, en arrière-plan.

Les rapports Greenbone du TP2 sont dans le dépôt, `tp2/corrige/rapports/` (`scan-authentifie.pdf`).

Parcourez le mandat (`~/TP/mandat-audit-TP8.pdf`) : relevez ce qui est dans le périmètre et ce qui ne l'est pas. Le test de contournement par l'équipement en `.254` (fichier 13) a été fait **avec l'accord écrit du commanditaire**, car cet équipement appartient à l'hébergeur. Le dossier est un dossier pédagogique : ses sorties sont représentatives de l'infrastructure de référence du laboratoire, et peuvent différer de votre propre laboratoire.

## Étape 2 — Analyser les preuves

**Pourquoi.** C'est le cœur du métier d'auditeur : lire une sortie technique et dire, en une phrase, ce qu'elle prouve. Un constat est un **fait** (« le port 23 est ouvert sur `web` »), pas une opinion (« la sécurité est faible »).

Ouvrez les fichiers un par un (`less` ou l'éditeur). Pour chaque ligne de la grille, notez dans la section 2 du rapport ce que vous constatez, et le fichier qui le prouve. Toutes les lignes ne donnent pas un constat négatif : un contrôle conforme est aussi un résultat.

| # | Contrôle | Fichier | Ce qu'il faut chercher |
|---|---|---|---|
| 1 | Exposition sur Internet | `03-exposition-internet.txt` | Quels ports sont ouverts sur l'adresse publique 10.10.0.20 ? Que renvoie `/.git/config` ? Une application de test est-elle joignable ? Les zones internes sont-elles joignables directement ? |
| 2 | Chiffrement du service publié | `04-…`, `06-tls-web.txt` | Versions de TLS proposées (`TLS 1`, `TLS 1.1` doivent être `not offered`), certificat (*Chain of trust*) |
| 3 | Services inutiles et vulnérables | `05-balayage-interne.txt`, rapports du TP2 | Services en clair (FTP 21, Telnet 23), applications de test (port 3000), versions ; correctifs manquants et vulnérabilités exploitées (KEV) |
| 4 | Règles du pare-feu | `01-pfsense-configuration.txt`, `02-pfsense-pfctl.txt` | Refus par défaut journalisé sur chaque interface ? Règles `pass` trop larges ? Règle désactivée oubliée ? Redirections encore en place ? |
| 5 | Administration | `01-…`, `07-ssh.txt` | Qui peut joindre l'interface de pfSense (anti-verrouillage) ? Le poste d'administration est-il dans le même réseau que les utilisateurs ? Double authentification ? SSH par mot de passe (`passwordauthentication`, `kbdinteractiveauthentication`) ? Algorithmes en `[fail]` ? |
| 6 | Supervision SNMP | `08-snmp.txt`, `01-…` | Un équipement répond-il à la communauté `public` ? pfSense est-il en SNMPv3 ? |
| 7 | Annuaire et authentification | `09-annuaire-ldap.txt`, `10-radius.txt` | La liste des comptes est-elle lisible sans authentification ? LDAP en clair (`ldap:///`) encore accepté ? RADIUS protégé par `Message-Authenticator` et un secret long ? |
| 8 | VPN | `12-ipsec.txt`, `01-…` | IKEv2, AES-GCM, SHA-2, groupe DH 19, PFS, sélecteurs restreints ? |
| 9 | Journalisation | `11-journalisation.txt`, `01-…` | Les journaux de pfSense et de `web` arrivent-ils sur le collecteur ? Comment sont-ils transportés ? Sont-ils conservés et pour combien de temps ? Les horloges sont-elles synchronisées ? |
| 10 | Cloisonnement | `13-cloisonnement.txt` | La DMZ peut-elle joindre la zone serveurs ou le poste d'administration ? Peut-elle sortir sur Internet ? Que se passe-t-il quand on passe par l'équipement en `.254` ? Un filtrage local sur les serveurs prendrait-il le relais ? |

> **Méthode.** Commencez par les fichiers 03 et 13 : ce sont ceux qui montrent ce qu'un attaquant peut réellement faire. Puis 05, 07, 08 et 09 pour les services. Les fichiers 01 et 02 servent surtout à expliquer **pourquoi** un flux passe ou non.

## Étape 3 — Coter les constats

**Pourquoi.** Un rapport qui aligne vingt constats sans les hiérarchiser ne sert à rien : le client ne sait pas par où commencer. La cotation combine la facilité d'exploitation et l'impact, dans le contexte réel (un service exposé sur Internet ne pèse pas comme un service interne).

Retenez **six constats au maximum**, les plus importants, et cotez-les :

| Criticité | Définition | Délai attendu |
|---|---|---|
| **Critique** | Exploitable facilement, impact majeur (compromission, fuite de données), souvent depuis Internet | Immédiat |
| **Majeure** | Exploitable par un attaquant déjà dans le réseau, ou impact important | Moins d'un mois |
| **Mineure** | Exploitation difficile ou impact limité ; écart aux bonnes pratiques | Prochain cycle de maintenance |

Reliez chacun à **une** référence, choisie dans cette liste :

| Référentiel | Mesure ou exigence |
|---|---|
| ISO/IEC 27002:2022 | 5.15 Contrôle d'accès · 5.17 Informations d'authentification · 8.5 Authentification sécurisée · 8.8 Vulnérabilités techniques · 8.9 Gestion des configurations · 8.12 Prévention de la fuite de données · 8.15 Journalisation · 8.20 Sécurité des réseaux · 8.21 Sécurité des services réseau · 8.22 Cloisonnement des réseaux · 8.24 Cryptographie |
| PCI DSS v4.0.1 | 1.2 Configuration des équipements de filtrage · 2.2.2 Comptes par défaut · 2.2.4 Services inutiles désactivés · 4.2.1 Chiffrement fort en transit · 6.3.3 Correctifs de sécurité · 8.4 Double authentification · 10.2 Journaux d'audit · 11.4.5 Tests de segmentation |

## Étape 4 — Rédiger le rapport

**Pourquoi.** Le rapport a deux lecteurs : la direction, qui décide et finance, et l'équipe technique, qui corrige. La synthèse s'écrit pour la première, sans jargon ; le tableau des constats pour la seconde, avec les preuves.

Complétez `rapport-audit.md` :

1. **Synthèse pour la direction** : cinq lignes. Le niveau global, les deux ou trois risques majeurs exprimés en impact métier (fuite de données clients, arrêt du site, sanction), et la priorité n° 1.
2. **Constats** : le tableau des six constats (fait, preuve, risque, criticité, référence, recommandation).
3. **Plan d'action** : les trois premières actions, avec un délai.
4. **Points positifs** : ce qui est conforme (une direction doit aussi savoir ce qui fonctionne).

Une bonne recommandation est **précise et vérifiable** : « désactiver SNMP v2c sur `web` et n'autoriser SNMPv3 *authPriv* que depuis 10.1.10.10 », et non « durcir SNMP ».

## Étape 5 — Restituer

**Pourquoi.** Un audit se conclut par une restitution orale au commanditaire : c'est là que les priorités se décident.

En une minute : votre constat le plus grave, sa preuve, et votre première recommandation.

> **Défi ★.** Vérifiez en direct, sur votre propre laboratoire, un constat du dossier. Par exemple, depuis `ext` : `curl -sk https://10.10.0.20/.git/config`. Votre laboratoire donne-t-il le même résultat que celui du dossier ? Qu'est-ce qui explique une différence éventuelle (TP réalisés ou non, corrections appliquées) ? C'est la limite de tout audit : il photographie un état à une date.

**Livrable** (dans `~/livrables`) : `rapport-audit.md` complété.

## Questions de validation

1. Quelle est la différence entre un constat, un risque et une recommandation ?
2. Pourquoi le test de contournement par l'équipement en `.254` a-t-il exigé un accord écrit, et à qui revient la correction ?
3. Pourquoi faut-il tester l'isolation entre zones plutôt que se fier au schéma et aux règles du pare-feu ?

---

[← TP7](../tp7/README.md) · [Sommaire](../README.md) · [Corrigé](corrige/README.md) · [En cas de blocage](../en-cas-de-blocage.md)
