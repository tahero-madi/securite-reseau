# Avant de commencer

Ce dépôt réunit les énoncés des travaux pratiques de la formation **3-020 « Sécurisation des architectures réseaux »**. Lisez chaque énoncé ici, sur GitHub, dans le navigateur de votre poste : chaque bloc de commandes a un bouton de copie en haut à droite. Les notions sont développées dans le support de cours.

> **Rappel du cadre.** Toutes les manipulations se déroulent **exclusivement** dans votre laboratoire individuel. Ne ciblez jamais l'environnement d'un autre apprenant, l'infrastructure de la plateforme ou un système extérieur. Les techniques offensives utilisées ici sont, hors de ce cadre, pénalement répréhensibles (art. 323-1 et suivants du Code pénal).

## Votre accès personnel

Chaque apprenant dispose de **sa propre machine virtuelle** sur la plateforme Hexceos, qu'il ouvre dans le navigateur par **son lien personnel**, communiqué par le formateur au début de la formation. Cette VM contient tout le laboratoire : un pare-feu pfSense et six machines Linux réparties en zones, reliés par des commutateurs virtuels. Aucun laboratoire ne communique avec un autre : les adresses sont donc **les mêmes pour tout le monde**.

> Votre lien est personnel et donne un accès direct à votre machine : ne le partagez pas en dehors de la session.

**Le bureau de la VM est votre poste de travail.** Il est branché sur le LAN du laboratoire avec l'adresse `10.1.10.10`, derrière pfSense, comme le poste d'un administrateur. Vous y trouvez un navigateur (pfSense, Greenbone, Zabbix, DVWA…), Wireshark, un terminal et les outils d'analyse (`nmap`, `arpwatch`, `tcpdump`, `testssl.sh`, `ssh-audit`, `ldapsearch`…). Depuis le terminal, vous joignez les autres machines **en SSH**, comme sur un vrai réseau : chaque connexion traverse pfSense et ses règles.

## Topologie

![Topologie du laboratoire, identique pour chaque apprenant](img/topologie.png)

| Machine | Rôle | Adresse(s) | Accès |
| --- | --- | --- | --- |
| **poste** (le bureau) | Poste d'administration : navigateur, Wireshark, outils ; héberge Greenbone et Zabbix | 10.1.10.10 (LAN) | Console web Hexceos |
| `fw` | pfSense : pare-feu, routeur, IDS/IPS, VPN | WAN 203.0.113.11 · LAN 10.1.10.1 · SRV 10.1.20.1 · DMZ 10.1.30.1 | https://10.1.10.1 |
| `client` | Poste utilisateur (trafic de fond) | 10.1.10.20 (LAN) | `ssh stagiaire@10.1.10.20` |
| `intrus` | Poste compromis (démonstration ARP du TP1) | 10.1.10.66 (LAN) | piloté par `lab demo-arp` (TP1) |
| `srv-int` | OpenLDAP, FreeRADIUS, collecteur rsyslog | 10.1.20.10 (SRV) | `ssh stagiaire@10.1.20.10` |
| `web` | nginx, DVWA, Juice Shop et services anciens (cible vulnérable) | 10.1.30.10 (DMZ) | `ssh stagiaire@10.1.30.10` ; http(s)://10.1.30.10 |
| `cloud-gw` | Passerelle du « cloud » (strongSwan, nftables) et service applicatif « cloud » | 203.0.113.21 (Internet simulé) · 10.101.1.1 (VPC) | `ssh stagiaire@203.0.113.21` |
| `ext` | Machine « Internet » : attaquant externe, tests d'exposition | 203.0.113.31 (Internet simulé) | `ssh stagiaire@203.0.113.31` |

Le réseau `203.0.113.0/24` joue **Internet**. Votre VM y figure aussi, en `203.0.113.254` : elle est le « fournisseur d'accès » du laboratoire et fait sortir ce réseau vers le vrai Internet. C'est pourquoi le poste peut se connecter directement à `ext` et à `cloud-gw`, comme on se connecte à un serveur sur Internet.

**Captures.** Chaque machine Linux du laboratoire est reliée à son commutateur par une interface visible sur le poste, nommée `v-<machine>` (`v-client`, `v-srv-int`, `v-web`, `v-cloud-gw`, `v-ext`…). Une capture Wireshark sur `v-web` voit tout le trafic de `web` : c'est l'équivalent d'un **port miroir** (SPAN) sur un commutateur. L'interface `lab-lan` est celle du poste lui-même.

**Identifiants et fichiers.** Les identifiants initiaux sont dans `~/TP/identifiants-lab.txt` ; vous les changerez au fil des TP. Sur toutes les machines Linux, l'utilisateur d'administration est `stagiaire`, avec les droits `sudo`. Les fichiers de TP (captures, mandat d'audit) sont dans `~/TP` ; ils sont aussi dans ce dépôt, dans [`infra/TP/`](infra/TP).

## La commande `lab`

La commande **`lab`** pilote le laboratoire depuis le terminal du poste :

| Commande | Effet |
| --- | --- |
| `lab statut` | État des machines et des outils |
| `lab urls` | Adresses des interfaces web |
| `lab topo` | Rappel du plan d'adressage et des ports miroirs |
| `lab shell <machine>` | Terminal sur une machine **sans passer par le réseau** (secours si vous vous êtes enfermé dehors) |
| `lab console fw` | Console de pfSense (menu de dépannage) |
| `lab instantane <nom>` / `lab restaurer <nom>` | Instantané de tout le laboratoire / retour à cet instantané |
| `lab reset [machine]` | Retour à l'état initial de la formation |

## Habitudes à prendre

- **Un instantané avant chaque TP** qui modifie la configuration : `lab instantane avant-tp3`. En cas de fausse manœuvre, `lab restaurer avant-tp3`, ou pour une seule machine `lab restaurer avant-tp3 fw`. Revenir en arrière prend quelques secondes ; mieux vaut restaurer que perdre vingt minutes.
- **Deux terminaux** : l'un pour agir, l'autre pour observer (`tcpdump`, journaux, `arpwatch`).
- **Copier-coller** entre votre ordinateur et la VM passe par le presse-papiers de la console web Hexceos ; pour une commande longue, le bouton de copie des blocs de code de GitHub, depuis le navigateur du poste, est le plus simple.
- **Garder vos livrables** : chaque TP produit un livrable (cartographie, matrice, rapport…). Rangez-les dans un dossier `~/livrables` et récupérez-les chaque soir : les machines sont détruites après la formation.
- **Avant de chercher longtemps** : consultez [En cas de blocage](en-cas-de-blocage.md), puis appelez le formateur.

---

[Sommaire](README.md) · [TP1 →](tp1/README.md)
