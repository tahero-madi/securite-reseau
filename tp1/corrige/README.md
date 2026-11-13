# Corrigé du TP1

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

**Étape 3 — découverte.** Le balayage trouve **9 hôtes** : pfSense sur chaque réseau (10.1.10.1, 10.1.20.1, 10.1.30.1), la Kali (10.1.10.10), `srv-int` (10.1.20.10), `web` (10.1.30.10)… et un hôte **non documenté en .254 sur chacun des trois réseaux**. La prédiction attendue était 6 : l'écart, ce sont ces trois .254. C'est l'équipement de l'hébergeur (DHCP, DNS et routeur de la plateforme Hexceos). Bon réflexe : le noter comme écart, ne pas le balayer (hors périmètre), et se demander ce qu'il peut faire. On y reviendra au TP8 : il peut router entre les zones sans passer par le pare-feu. C'est le prétexte idéal pour parler d'inventaire des actifs, de responsabilité partagée avec un hébergeur et de contrôle d'accès au réseau (802.1X, NAC).

Les adresses MAC (préfixe `BC:24:11`, Proxmox) ne s'affichent que pour le LAN : ARP ne traverse pas un routeur, nmap ne voit donc les MAC que sur le segment de la Kali. Seuls les hôtes présents dans `/etc/hosts` sont nommés (`fw.lab.local`, `srv-int.lab.local`…).

**Étape 4 — services.** Résultat obtenu (environ 3 minutes) :

| Hôte | Port | nmap annonce | En réalité |
|---|---|---|---|
| srv-int | 22 | OpenSSH 9.6p1 Ubuntu | SSH d'administration |
| srv-int | 389, 636 | OpenLDAP 2.2.X - 2.3.X | OpenLDAP 2.6 : **estimation fausse** de nmap |
| srv-int | 514 | `shell?` | collecteur rsyslog en TCP ; 514/tcp est historiquement le port de `rsh`, d'où le nom |
| web | 21 | vsftpd 3.0.5 | FTP en clair |
| web | 22 | OpenSSH 9.6p1 Ubuntu | SSH |
| web | 23 | `telnet` (empreinte non reconnue) | Telnet : les octets `\xff\xfb…` de l'empreinte sont la négociation Telnet |
| web | 80, 443 | nginx 1.24.0 (Ubuntu) | serveur web |
| web | 3000 | `ppp?` | Juice Shop : l'empreinte contient `<title>OWASP Juice Shop</title>` |

Absents du balayage, et c'est normal :
- l'agent Zabbix de srv-int (10050/tcp) : port hors des 200 plus courants (`--top-ports 200`) ;
- RADIUS (1812-1813/udp) sur srv-int et SNMP (161/udp) sur web : en UDP, donc invisibles pour un balayage TCP (il faudrait `-sU`).

Le balayage ciblé de l'étape 4 les retrouve : 10050/tcp `open` (zabbix-agent) ; 161/udp `open` (SNMPv1/v2c, net-snmp, communauté `public` acceptée) ; 1812-1813/udp `open|filtered` (FreeRADIUS ne répond pas à une requête sans secret partagé valide). Leçon : l'absence d'un port dans un balayage ne prouve pas l'absence du service.

Système : nmap annonce « Linux 4.19 - 5.15 » pour srv-int et ne conclut pas pour web, alors que les deux tournent sous le noyau 6.8 d'Ubuntu 24.04. Les détections de version et de système sont des **estimations** à recouper (bannières, accès authentifié), pas des preuves. « Network Distance: 2 hops » confirme qu'un routeur (pfSense) sépare la Kali des serveurs.

L'écart attendu avec la topologie : `web` expose bien plus de services que nécessaire pour un serveur web (FTP, Telnet, une seconde application sur 3000) — c'est le cœur du risque (hôte « hérité »).

**Défi ★.** `http-headers` révèle la version exacte (`Server: nginx/1.24.0 (Ubuntu)`). `ssl-cert` révèle un certificat **autosigné** (émetteur = sujet), le nom interne `web.lab.local`, l'adresse interne 10.1.30.10… et **10.10.0.20**, l'adresse WAN de pfSense : le certificat trahit l'adresse de publication du service. Tout cela aide à la reconnaissance (ATT&CK T1595, T1592).

**Étapes 5 et 6.** Ce qu'on doit observer (exemple réel, les MAC varient d'un environnement à l'autre : cloud-gw `bc:24:11:59:6a:dc`, ext `bc:24:11:d3:fe:6d`, pfSense WAN `bc:24:11:63:da:79`) :
- avant : `ip neigh show 10.10.0.20` sur cloud-gw donne la MAC de pfSense ;
- pendant : la même commande donne la MAC d'**ext** ; `arpwatch` signale `changed ethernet address 10.10.0.20` ; le `tcpdump -e` d'ext montre chaque requête ICMP deux fois : `bc:24:11:59:6a:dc > bc:24:11:d3:fe:6d` (cloud-gw → ext), puis `bc:24:11:d3:fe:6d > bc:24:11:63:da:79` (ext → pfSense) ; le ping de la victime continue de répondre (réponse à la prédiction : oui, grâce au relais d'ext) ;
- après : `arpspoof` réannonce la vraie MAC (« cleaning up and re-arping ») et la table revient.

Points à faire émerger :
- ARP n'a aucune authentification ; toute réponse, même non sollicitée, est acceptée et met à jour la table (dernière réponse gagnante). `arpwatch` détecte le changement a posteriori ; il ne l'empêche pas.
- Protection : **Dynamic ARP Inspection**, qui valide les réponses ARP contre la table construite par **DHCP Snooping** (associations IP ↔ MAC ↔ port). En complément : entrées ARP statiques pour les passerelles critiques, isolation des ports (private VLAN).
- Le commutateur virtuel de la plateforme, comme un commutateur sans DAI, laisse passer ces réponses.
- Le flux FTP en clair illustre que la confidentialité ne dépend pas de la « zone » mais du chiffrement du protocole. Remplacement par SFTP ou FTPS.

**Pour le formateur.** Avant le TP, vérifiez dans un environnement que la démonstration fonctionne (le commutateur de la plateforme ne filtre pas l'usurpation) et que le WAN de chaque apprenant est isolé : depuis ext, `sudo arping -c3 -I ens18 10.10.0.20` (paquet `iputils-arping`) ne doit obtenir qu'une MAC. Si le WAN était partagé entre apprenants, faites la démonstration vous-même, sur votre environnement, en projetant l'écran. Repli : `~/TP/tp1-arp-demo.pcap` (même scénario : cloud-gw 10.10.0.30, ext 10.10.0.40 avec la MAC `bc:24:11:7a:00:40`, pfSense 10.10.0.20 avec la MAC `bc:24:11:cf:ce:66`) et `~/TP/tp1-ftp-clear.pcap`.

**Étape 7 — matrice type attendue (extrait) :**

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
