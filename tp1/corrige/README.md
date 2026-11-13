# Corrigé du TP1

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

**Partie A.** Le balayage fait apparaître `fw` (.1) sur chaque réseau, la Kali (10.1.10.10), `srv-int` (10.1.20.10), `web` (10.1.30.10)… et un hôte **non documenté en .254 sur chacun des trois réseaux**. C'est l'équipement de l'hébergeur (DHCP, DNS et routeur de la plateforme Hexceos). Bon réflexe : le noter comme écart, ne pas le balayer (hors périmètre), et se demander ce qu'il peut faire. On y reviendra au TP8 : il peut router entre les zones sans passer par le pare-feu. C'est le prétexte idéal pour parler d'inventaire des actifs, de responsabilité partagée avec un hébergeur et de contrôle d'accès au réseau (802.1X, NAC).

Services attendus :
- `srv-int` : 22/ssh, 389/ldap, 636/ldaps, 514/tcp syslog, 10050 agent Zabbix (RADIUS 1812-1813 est en UDP : non vu par un scan TCP) ;
- `web` : 21/ftp, 22/ssh, 23/telnet, 80, 443, 3000 (Juice Shop), et 161/udp SNMP non vu en TCP.

Le `-O` demande `sudo`. Le poste passe par 10.1.10.1 pour joindre SRV et DMZ (`traceroute -n 10.1.20.10`) : il est bien un client du pare-feu. L'écart attendu avec la topologie : `web` expose bien plus de services que nécessaire pour un serveur web — c'est le cœur du risque (hôte « hérité »). NSE `ssl-cert` révèle nom d'hôte, émetteur (certificat autosigné), dates ; `http-headers` révèle les versions (bannière `nginx/1.24.0 (Ubuntu)`) → aide à la reconnaissance (ATT&CK T1595/T1592).

**Partie B.** Ce qu'on doit observer :
- avant : `ip neigh show 10.10.0.20` sur cloud-gw donne la MAC de pfSense ;
- pendant : la même commande donne la MAC d'**ext** ; `arpwatch` signale `changed ethernet address 10.10.0.20` ; le `tcpdump -e` d'ext montre les requêtes ICMP de cloud-gw adressées à la MAC d'ext, puis relayées vers la MAC de pfSense ; le ping de la victime continue de répondre ;
- après : `arpspoof` réannonce la vraie MAC (« cleaning up and re-arping ») et la table revient.

Points à faire émerger :
- ARP n'a aucune authentification ; toute réponse, même non sollicitée, est acceptée et met à jour la table (dernière réponse gagnante). `arpwatch` détecte le changement a posteriori ; il ne l'empêche pas.
- Protection : **Dynamic ARP Inspection**, qui valide les réponses ARP contre la table construite par **DHCP Snooping** (associations IP ↔ MAC ↔ port). En complément : entrées ARP statiques pour les passerelles critiques, isolation des ports (private VLAN).
- Le commutateur virtuel de la plateforme, comme un commutateur sans DAI, laisse passer ces réponses.
- Le flux FTP en clair illustre que la confidentialité ne dépend pas de la « zone » mais du chiffrement du protocole. Remplacement par SFTP ou FTPS.

**Pour le formateur.** Avant le TP, vérifiez dans un environnement que la démonstration fonctionne (le commutateur de la plateforme ne filtre pas l'usurpation) et que le WAN de chaque apprenant est isolé : depuis ext, `sudo arping -c3 10.10.0.20` ne doit obtenir qu'une MAC. Si le WAN était partagé entre apprenants, faites la démonstration vous-même, sur votre environnement, en projetant l'écran. Repli : `~/TP/tp1-arp-demo.pcap` (même scénario : cloud-gw 10.10.0.30, ext 10.10.0.40 avec la MAC `bc:24:11:7a:00:40`, pfSense 10.10.0.20 avec la MAC `bc:24:11:cf:ce:66`) et `~/TP/tp1-ftp-clear.pcap`.

**Partie C — matrice type attendue (extrait) :**

| Bien / scénario | V | G | Niveau | Mesures | Résiduel |
|---|---|---|---|---|---|
| Usurpation ARP sur un segment → interception | 3 | 3 | Élevé | DHCP Snooping + DAI, entrées statiques passerelle, 802.1X | Faible |
| FTP en clair → vol d'identifiants | 3 | 3 | Élevé | Remplacer par SFTP, désactiver FTP | Faible |
| `web` exposant des services anciens → compromission + rebond | 4 | 4 | Critique | Supprimer les services inutiles, isoler en DMZ, filtrage strict, pas d'accès Internet sortant, plan de remplacement | Moyen |
| Serveur web DMZ exposé → compromission | 3 | 3 | Élevé | DMZ, WAF, correctifs, filtrage DMZ → interne limité | Moyen |
| Équipement non maîtrisé (.254) présent dans toutes les zones → contournement du pare-feu | 2 | 4 | Élevé | Inventaire, clarification contractuelle avec l'hébergeur, routes fixes, contrôle de la segmentation | Moyen |
| Administration pfSense par mot de passe faible | 3 | 4 | Critique | Mot de passe fort et MFA, accès restreint au poste d'administration | Faible |

**Questions.** 1 : DAI, s'appuyant sur la table DHCP Snooping. 2 : FTP transmet identifiants et données en clair ; toute personne sur le chemin (ou ayant réussi une redirection de couche 2, comme ext l'a fait) les lit — la « zone interne » n'est pas une protection. 3 : isolement réseau (zone dédiée, filtrage au plus près, pas d'Internet) et accès uniquement par bastion avec surveillance renforcée ; acceptation formelle du risque résiduel.

---

[Sommaire](../../README.md) · [Énoncé](../README.md) · [En cas de blocage](../../en-cas-de-blocage.md) · [TP2 →](../../tp2/README.md)
