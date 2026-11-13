# Sécurisation des architectures réseaux · Travaux pratiques

Formation 3-020, quatre jours. Huit travaux pratiques sur votre propre laboratoire, un réseau d'entreprise complet en miniature : un pare-feu pfSense à quatre zones, un annuaire et un serveur RADIUS, un serveur web exposé, une passerelle vers un « cloud » et un attaquant sur « Internet ». On cartographie et on cote les risques, on scanne les vulnérabilités, on cloisonne et on filtre, on authentifie, on détecte avec Suricata, on chiffre vers le cloud avec IPsec, on supervise et on enquête sur un incident, puis on audite le tout.

## Comment travailler

- **Ouvrez votre Kali** depuis le portail Hexceos : c'est votre poste de travail.
- **Lisez l'énoncé ici**, sur GitHub, dans Firefox sur la Kali. Chaque bloc de commandes a un bouton de copie en haut à droite.
- **Collez les commandes dans le terminal de la Kali**. Depuis ce terminal, vous joignez les autres machines en SSH (compte `formation`), à travers pfSense.
- Commencez par [Avant de commencer](avant-de-commencer.md) : la topologie, les adresses, les instantanés et les deux règles à respecter.

> **Cadre.** Toutes les manipulations se font **uniquement** dans votre laboratoire. Les techniques offensives vues ici sont, hors de ce cadre, pénalement répréhensibles (art. 323-1 et suivants du Code pénal).

## Récupérer les fichiers sur la Kali

Les fichiers utiles aux TP (identifiants, captures, mandat d'audit) sont déjà dans `~/TP`. Pour avoir aussi les énoncés et les corrigés sur la Kali :

```bash
git clone https://github.com/tahero-madi/securite-reseau.git ~/securite-reseau
ls ~/securite-reseau
```

Si le formateur modifie un fichier pendant la formation, `cd ~/securite-reseau && git pull` récupère la nouvelle version.

## Corrigés

Chaque TP a son corrigé dans un sous-dossier `corrige/` : `tp3/corrige/` pour le TP3, par exemple. Il reprend les résultats attendus, les configurations de référence et les réponses aux questions de validation.

Cherchez d'abord par vous-même : le corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP. Pour le TP7, ne l'ouvrez qu'après avoir mené l'enquête.

## Programme des TP

| Quand | TP | Durée |
| --- | --- | --- |
| **Jour 1 · Menaces et vulnérabilités** | | |
| Jour 1, 10:25 | [TP1 — Cartographie, couche 2 et analyse de risques](tp1/README.md) | 1 h 35 |
| Jour 1, 13:40 | [TP2 — Gestion des vulnérabilités avec Greenbone](tp2/README.md) | 2 h 10, pause incluse |
| **Jour 2 · Cloisonner et contrôler l'accès** | | |
| Jour 2, 10:20 | [TP3 — Cloisonnement et filtrage avec pfSense](tp3/README.md) | 1 h 40 |
| Jour 2, 13:40 | [TP4 — Authentification réseau : LDAP, RADIUS, 802.1X](tp4/README.md) | 2 h 10, pause incluse |
| **Jour 3 · Détecter, chiffrer, hybrider** | | |
| Jour 3, 09:50 | [TP5 — IDS/IPS avec Suricata sur pfSense](tp5/README.md) | 2 h 10, pause incluse |
| Jour 3, 13:40 | [TP6 — Interconnexion hybride : VPN IPsec et groupes de sécurité](tp6/README.md) | 2 h 10, pause incluse |
| **Jour 4 · Surveiller, réagir, auditer** | | |
| Jour 4, 09:40 | [TP7 — Supervision, journalisation et analyse d'incident](tp7/README.md) | 2 h 20, pause incluse |
| Jour 4, 13:35 | [TP8 — Audit de sécurité réseau et rapport](tp8/README.md) | 1 h 45, pause incluse |

En cas de problème : [En cas de blocage](en-cas-de-blocage.md).

## Contenu du dépôt

| Dossier ou fichier | Contenu |
| --- | --- |
| `tp1/` … `tp8/` | L'énoncé du TP (`README.md`) |
| `tpN/corrige/` | Le corrigé du TP |
| `tp1/modeles/`, `tp2/modeles/` | Les modèles des livrables (cartographie, matrice des risques, rapport de vulnérabilités) |
| `img/topologie.png` | La topologie du laboratoire |
| `fichiers/` | Les fichiers remis dans `~/TP` : captures `tp1-arp-demo.pcap`, `tp1-ftp-clear.pcap` et `tp7-incident.pcap`, mandat `mandat-audit-TP8.pdf`, et le script qui génère les captures |
| `hexceos/` | La préparation des environnements (formateur) : réseau, installation des logiciels de chaque VM, vérification |

## Le laboratoire

Chaque apprenant a **6 machines virtuelles** sur la plateforme Hexceos, reliées par 4 réseaux. Les adresses sont identiques dans chaque environnement, et aucun environnement ne communique avec un autre.

| Réseau | Plage | Machines |
| --- | --- | --- |
| WAN, « Internet » simulé | 10.10.0.0/24 | pfSense .20, cloud-gw .30, ext .40 (passerelle de la plateforme .1) |
| LAN | 10.1.10.0/24 | pfSense .1, Kali .10 |
| Serveurs (SRV) | 10.1.20.0/24 | pfSense .1, srv-int .10 |
| DMZ | 10.1.30.0/24 | pfSense .1, web .10 |
| « VPC » du cloud | 10.101.1.0/24 | cloud-gw .1 (interface virtuelle) |

Pour préparer un environnement (formateur) : voir [`hexceos/README.md`](hexceos/README.md). En résumé, après quelques réglages de pfSense à la main, deux commandes sur chaque VM :

```bash
curl -fsSL https://raw.githubusercontent.com/tahero-madi/securite-reseau/main/hexceos/reseau.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/tahero-madi/securite-reseau/main/hexceos/prep.sh | sudo bash
```

> **Attention :** les mots de passe de `hexceos/lab.conf` sont des valeurs de laboratoire, publiques puisque ce dépôt l'est. Les comptes des VM et de pfSense sont ceux fournis par la plateforme.

## Versions utilisées

Kali Linux (rolling), pfSense CE 2.9, Ubuntu Server 24.04 LTS, Suricata (paquet pfSense, règles ET Open), Greenbone Community Edition (Docker), Zabbix 7.0, OpenLDAP et FreeRADIUS 3 des dépôts Ubuntu, strongSwan (`swanctl`), nftables.
