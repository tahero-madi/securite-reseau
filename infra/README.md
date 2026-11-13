# Kit d'installation du lab — formation 3-020 « Sécurisation des architectures réseaux »

Ce kit transforme **une VM Ubuntu 24.04 Hexceos** en laboratoire complet pour un apprenant : un pare-feu pfSense à 4 interfaces, six machines Linux réparties en zones, Greenbone et Zabbix. Tout tourne **à l'intérieur de la VM** : l’apprenant n’a besoin que de sa console web Hexceos.

On installe le kit **une seule fois sur une VM modèle** ; Hexceos clone ensuite ce modèle pour chaque apprenant (6 + 1 formateur). Chaque clone est identique et isolé : mêmes adresses partout, aucun lien entre les labs.

## Architecture

```
                         Internet (via ens18 de la VM, NAT)
                                       │
                 lab-wan 203.0.113.0/24 « Internet simulé »
     ┌───────────────┬─────────────┬───┴────────────┬──────────────────┐
  VM hôte .254     ext .31     cloud-gw .21 ── lab-vpc 10.101.1.0/24 (service « cloud » .1)
 (routeur FAI)                      │
                              fw .11 (pfSense CE, VM KVM)
                 ┌──────────────────┼──────────────────┐
     lab-lan 10.1.10.0/24   lab-srv 10.1.20.0/24   lab-dmz 10.1.30.0/24
     fw .1                  fw .1                  fw .1
     POSTE = VM hôte .10    srv-int .10            web .10
     client .20             (LDAP, RADIUS,         (nginx, DVWA, Juice Shop,
     intrus .66              rsyslog, agent)        FTP, Telnet, SNMP v2c)

  Greenbone et Zabbix : conteneurs Docker sur la VM hôte, vus du lab comme le poste 10.1.10.10.
```

| Machine | Technologie | Adresse(s) | Rôle dans les TP |
|---|---|---|---|
| **poste** | la VM hôte (bureau, par la console web Hexceos) | 10.1.10.10 (LAN), 203.0.113.254 (FAI) | poste d'admin : navigateur, Wireshark, nmap, SSH ; héberge Greenbone et Zabbix |
| **fw** | pfSense CE, VM KVM | WAN .11 · LAN .1 · SRV .1 · DMZ .1 | zonage, NAT, Suricata, IPsec, SNMP, syslog (TP 1 à 8) |
| **srv-int** | conteneur LXD | 10.1.20.10 | OpenLDAP, FreeRADIUS, collecteur rsyslog, agent Zabbix (TP 4, 6, 7) |
| **web** | conteneur LXD | 10.1.30.10 | serveur exposé et cible vulnérable (TP 1, 2, 3, 5, 8) |
| **cloud-gw** | conteneur LXD privilégié | 203.0.113.21 · 10.101.1.1 | passerelle « cloud », strongSwan, nftables, service cloud (TP 6) |
| **client** | conteneur LXD | 10.1.10.20 | poste utilisateur, trafic de fond, victime de la démo ARP (TP 1) |
| **intrus** | conteneur LXD | 10.1.10.66 | poste compromis pour la démonstration ARP (formateur) |
| **ext** | conteneur LXD | 203.0.113.31 | « attaquant Internet » : tests de publication, Suricata, audit externe (TP 3, 5, 8) |

**Cloisonnement garanti par la VM hôte** : elle ne route rien entre les zones (tout passe par pfSense) ; le WAN simulé sort vers Internet en NAT mais ne peut joindre aucun réseau privé de la plateforme ; rien n'entre dans la VM depuis le lab.

**Captures Wireshark** : chaque conteneur a une interface côté hôte nommée `v-<machine>` (ex. `v-client`, `v-web`) qui joue le rôle de **port miroir**.

## Prérequis (VM modèle Hexceos)

- Ubuntu 24.04 Desktop, **8 vCPU, 24 Go RAM** (16 Go minimum), **150 Go** de disque.
- **Virtualisation imbriquée** activée (`/dev/kvm` présent).
- Accès Internet pendant l'installation (≈ 15 Go téléchargés, dont le flux Greenbone).
- Un compte avec `sudo`.
- L'image **Netgate Installer** de pfSense CE (voir `pfsense/INSTALLATION-pfsense.md`).

## Installation (≈ 1 h 30 de travail, plus le chargement du flux Greenbone)

Copiez le dossier du kit sur la VM, puis dans un terminal :

```
cd kit-lab-3020
nano lab.conf                         # 1. choisir les mots de passe
sudo ./install.sh                     # 2. étapes 1 à 4 (≈ 45 min, sans surveillance)
sudo ./05-pfsense.sh ~/Téléchargements/netgate-installer-amd64.iso.gz
                                      # 3. puis suivre pfsense/INSTALLATION-pfsense.md (≈ 20 min)
sudo ./99-verif.sh                    # 4. tout doit être [OK]
sudo lab instantane initial           # 5. instantané de référence de toutes les machines
```

Puis, **une fois le flux Greenbone à jour** (GSA → *Administration → Feed Status* : tout « Current ») : éteindre proprement la VM et demander à Hexceos d'en faire le modèle des 7 environnements.

| Étape | Script | Contenu |
|---|---|---|
| 1 | `01-hote.sh` | paquets (KVM/libvirt, LXD, Docker, Wireshark, nmap, testssl.sh, ssh-audit…), groupes, AC du lab, outil `lab`, fichiers de TP |
| 2 | `02-reseau.sh` | ponts `lab-*`, filtrage et NAT de la VM (service `lab-net`), test de pont |
| 3 | `03-conteneurs.sh` | 6 conteneurs installés puis basculés sur leurs zones (journaux dans `/opt/lab/logs/`) |
| 4 | `04-outils.sh` | Zabbix 7.0 et Greenbone Community Edition (Docker) |
| 5 | `05-pfsense.sh` | VM pfSense à 4 cartes ; installation guidée manuelle |
| — | `99-verif.sh` | 40 contrôles : machines, services, sorties, cloisonnement, outils |

Un conteneur raté se refait seul : `sudo ./03-conteneurs.sh web`.

## Outil `lab` (pour l'apprenant et le formateur)

```
lab statut                 état des machines et des outils
lab urls                   pfSense, Greenbone, Zabbix, DVWA, Juice Shop
lab topo                   plan d'adressage et ports miroirs
lab shell srv-int          terminal sur une machine sans passer par le réseau (secours)
lab console fw             console graphique de pfSense
lab instantane avant-tp3   instantané de toutes les machines
lab restaurer avant-tp3    retour à cet instantané (ou : lab restaurer avant-tp3 fw)
lab reset                  retour à l'état initial de la formation (ou : lab reset web)
lab demo-arp               (formateur) démonstration encadrée d'usurpation ARP du TP 1
```

L'accès normal aux machines se fait **en SSH depuis le poste**, comme sur un vrai réseau : `ssh stagiaire@10.1.20.10`. Le flux traverse alors pfSense et ses règles. `lab shell` est l'équivalent de la console série d'un fournisseur cloud : il sert quand l'apprenant s'est enfermé dehors.

## Fichiers remis à l'apprenant (`~/TP`)

| Fichier | Usage |
|---|---|
| `identifiants-lab.txt` | comptes initiaux du lab |
| `tp1-arp-demo.pcap` | usurpation ARP sur le LAN (repli de la démonstration) |
| `tp1-ftp-clear.pcap` | authentification FTP en clair (repli) |
| `tp7-incident.pcap` | scénario d'intrusion à analyser au TP 7 |
| `mandat-audit-TP8.pdf` | mandat d'audit du TP 8 |
| `~/pki/` | AC du lab et certificat client d'alice (défi EAP-TLS) |

Les captures se régénèrent avec `python3 TP/generer_captures.py` (scapy).

## Dépannage

| Symptôme | Vérification |
|---|---|
| Plus rien ne passe entre machines | `systemctl status lab-net` ; `sudo /opt/lab/lab-net.sh start` (relance sans risque) |
| Une machine ne répond plus en SSH | `lab shell <machine>`, puis `ip a` et `sudo systemctl status ssh` ; ou règles pfSense |
| pfSense inaccessible en web | `lab console fw` (menu console : option 2 pour l'adresse, 3 pour le mot de passe, 4 pour réinitialiser) |
| Apprenant bloqué au milieu d'un TP | `lab restaurer <instantané>` ou `lab reset <machine>` |
| Greenbone vide ou très lent | flux encore en chargement : GSA → Feed Status |
| Lab entièrement cassé | instantané Hexceos de la VM (si activé) ou `lab reset` |
