# Sécurisation des architectures réseaux · Travaux pratiques

Formation 3-020, quatre jours. Huit travaux pratiques sur votre propre laboratoire, un réseau d'entreprise complet en miniature : un pare-feu pfSense à quatre zones, un annuaire et un serveur RADIUS, un serveur web exposé, une passerelle vers un « cloud » et un attaquant sur « Internet ». On cartographie et on cote les risques, on scanne les vulnérabilités, on cloisonne et on filtre, on authentifie, on détecte avec Suricata, on chiffre vers le cloud avec IPsec, on supervise et on enquête sur un incident, puis on audite le tout.

## Comment travailler

- **Lisez l'énoncé ici**, sur GitHub, dans le navigateur de votre poste. Chaque bloc de commandes a un bouton de copie en haut à droite.
- **Tapez ou collez les commandes dans le terminal du poste**, ouvert dans la console web Hexceos. Depuis ce terminal, vous joignez les autres machines en SSH, à travers pfSense.
- Commencez par [Avant de commencer](avant-de-commencer.md) : la topologie, les adresses, la commande `lab` et les habitudes de travail.

> **Cadre.** Toutes les manipulations se font **uniquement** dans votre laboratoire. Les techniques offensives vues ici sont, hors de ce cadre, pénalement répréhensibles (art. 323-1 et suivants du Code pénal).

## Récupérer les fichiers sur le poste

Les fichiers utiles aux TP (identifiants, captures, mandat d'audit) sont déjà dans `~/TP`. Pour avoir aussi les énoncés et les corrigés sur le poste :

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
| `img/topologie.png` | La topologie du laboratoire |
| `infra/TP/` | Les fichiers remis dans `~/TP` : captures `tp1-arp-demo.pcap`, `tp1-ftp-clear.pcap` et `tp7-incident.pcap`, mandat `mandat-audit-TP8.pdf`, et le script qui régénère les captures |
| `infra/` | Le kit qui construit le laboratoire dans une VM Ubuntu 24.04 (voir ci-dessous) |

## Le laboratoire

Tout le laboratoire tient dans **une VM par apprenant**, sur la plateforme Hexceos. Le bureau de la VM est le poste d'administration ; les autres machines tournent à l'intérieur : pfSense dans une VM KVM imbriquée, les six machines Linux en conteneurs LXD, Greenbone et Zabbix en conteneurs Docker. Les adresses sont identiques dans chaque laboratoire, et aucun laboratoire ne communique avec un autre.

| Réseau | Plage | Machines |
| --- | --- | --- |
| « Internet » simulé | 203.0.113.0/24 | fw (WAN) .11, cloud-gw .21, ext .31, la VM hôte .254 |
| LAN | 10.1.10.0/24 | fw .1, poste .10, client .20, intrus .66 |
| Serveurs (SRV) | 10.1.20.0/24 | fw .1, srv-int .10 |
| DMZ | 10.1.30.0/24 | fw .1, web .10 |
| « VPC » du cloud | 10.101.1.0/24 | cloud-gw .1 |

Pour reconstruire le laboratoire (formateur, ou chez vous), dans une VM **Ubuntu 24.04 Desktop** avec la virtualisation imbriquée activée, 8 vCPU, 24 Go de RAM et 150 Go de disque :

```bash
git clone https://github.com/tahero-madi/securite-reseau.git ~/securite-reseau
cd ~/securite-reseau/infra
nano lab.conf                 # choisir les mots de passe avant toute installation
sudo ./install.sh             # étapes 1 à 4, environ 45 minutes
sudo ./05-pfsense.sh ~/Téléchargements/netgate-installer-amd64.iso.gz
sudo ./99-verif.sh            # tout doit être [OK]
sudo lab instantane initial
```

Le détail, l'installation guidée de pfSense et le dépannage sont dans [`infra/README.md`](infra/README.md) et [`infra/pfsense/INSTALLATION-pfsense.md`](infra/pfsense/INSTALLATION-pfsense.md).

> **Attention :** les mots de passe de `infra/lab.conf` sont des valeurs d'exemple, publiques puisque ce dépôt l'est. Changez-les avant d'installer un laboratoire.

## Versions testées

Ubuntu 24.04 LTS, pfSense CE (dernière version stable, installée par le Netgate Installer), Suricata (paquet pfSense, règles ET Open), Greenbone Community Edition (Docker), Zabbix 7.0, OpenLDAP et FreeRADIUS 3 des dépôts Ubuntu, strongSwan (`swanctl`), nftables.
