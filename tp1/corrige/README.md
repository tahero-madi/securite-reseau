# Corrigé du TP1

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

**Partie A.** Le balayage du LAN fait apparaître `fw` (.1), le poste (.10), `client` (.20) et `intrus` (.66) : un poste que rien n'empêche de se brancher sur le LAN — bon prétexte pour parler d'inventaire des actifs et de contrôle d'accès au réseau (802.1X, NAC). Services attendus : `srv-int` (22/ssh, 389/ldap, 636/ldaps, 1812-1813/udp radius, 514 syslog, 10050 agent Zabbix), `web` (21/ftp, 22/ssh, 23/telnet, 80, 443, 3000 Juice Shop, 161/udp SNMP non vu en TCP). Le `-O` demande `sudo`. Le traceroute implicite montre que le poste passe par 10.1.10.1 pour joindre SRV et DMZ : le poste est bien un client du pare-feu. L'écart attendu avec la topologie : `web` expose bien plus de services que nécessaire pour un serveur web — c'est le cœur du risque (rôle de cible vulnérable / hôte « hérité »). NSE `ssl-cert` révèle nom d'hôte, autorité, dates ; `http-headers` révèle versions de serveur (bannières) → aide à la reconnaissance (ATT&CK T1595/T1592).

**Partie B.** Points à faire émerger :
- ARP n'a aucune authentification ; toute réponse est acceptée et met à jour la table (dernière réponse gagnante). `arpwatch` détecte le changement a posteriori ; il ne l'empêche pas.
- Protection : **Dynamic ARP Inspection**, qui valide les réponses ARP contre la table construite par **DHCP Snooping** (associations IP↔MAC↔port). Entrées ARP statiques pour les passerelles critiques en complément.
- Le flux FTP en clair illustre que la confidentialité ne dépend pas de la « zone » mais du chiffrement du protocole. Remplacement par SFTP/FTPS.

Déroulé conseillé : faire lancer arpwatch et Wireshark sur `v-client` par tout le monde, puis donner le signal de `lab demo-arp` (une seule fois, 15 s). Dans Wireshark, faire repérer les trames ICMP en double : le client envoie à la MAC de l'intrus (00:16:3e:30:20:66), qui relaie vers la vraie passerelle (52:54:00:30:20:02) — c'est la position d'homme du milieu. Point d'architecture : sur un pont Linux comme sur un commutateur sans DAI, rien ne filtre ces réponses ; sur un équipement d'entreprise, DHCP Snooping + DAI les auraient rejetées au port de l'intrus. Repli : `~/TP/tp1-arp-demo.pcap` (mêmes adresses) et `~/TP/tp1-ftp-clear.pcap`.

**Partie C — matrice type attendue (extrait) :**

| Bien / scénario | V | G | Niveau | Mesures | Résiduel |
|---|---|---|---|---|---|
| Usurpation ARP sur le LAN → interception | 3 | 3 | Élevé | DHCP Snooping + DAI, entrées statiques passerelle, 802.1X | Faible |
| FTP en clair → vol d'identifiants | 3 | 3 | Élevé | Remplacer par SFTP, désactiver FTP | Faible |
| `web` exposant des services anciens → compromission + rebond | 4 | 4 | Critique | Supprimer les services inutiles, isoler en DMZ, filtrage strict, pas d'accès Internet sortant, plan de remplacement | Moyen |
| Serveur web DMZ exposé → compromission | 3 | 3 | Élevé | DMZ, WAF, correctifs, filtrage DMZ→interne limité | Moyen |
| Administration pfSense par mot de passe faible | 3 | 4 | Critique | MFA/mot de passe fort, accès restreint à la zone admin | Faible |

**Questions.** 1 : DAI, s'appuyant sur la table DHCP Snooping. 2 : FTP transmet identifiants et données en clair ; toute personne sur le chemin (ou ayant réussi une redirection L2) les lit — la « zone interne » n'est pas une protection. 3 : isolement réseau (VLAN/zone dédiée, filtrage au plus près, pas d'Internet) et accès uniquement via bastion + surveillance renforcée ; acceptation formelle du risque résiduel.

---

[Sommaire](../../README.md) · [Énoncé](../README.md) · [En cas de blocage](../../en-cas-de-blocage.md) · [TP2 →](../../tp2/README.md)
