# Préparer un environnement Hexceos

Chaque apprenant dispose de 6 VM sur la plateforme Hexceos : Kali (poste), pfSense, srv-int, web, cloud-gw et ext. Cette page décrit comment les préparer pour les TP, dans l'ordre. Comptez environ une heure par environnement, dont la plus grande partie en attente (téléchargement de Greenbone).

## Pourquoi ces réglages

Le routeur de la plateforme (10.10.0.1 sur le WAN, et une adresse en .254 sur chaque réseau interne) **route entre tous les réseaux du lab**. Livrées telles quelles, les VM l'utilisent comme passerelle et contournent pfSense. On impose donc à chaque VM une route par défaut et un DNS qui passent par pfSense.

| VM | Adresse | Passerelle | Route en plus | DNS |
| --- | --- | --- | --- | --- |
| Kali | 10.1.10.10/24 (eth1) ; eth0 coupée | 10.1.10.1 | — | 10.1.10.1 |
| srv-int | 10.1.20.10/24 | 10.1.20.1 | — | 10.1.20.1 |
| web | 10.1.30.10/24 | 10.1.30.1 | — | 10.1.30.1 |
| cloud-gw | 10.10.0.30/24 (+ VPC 10.101.1.1 sur vpc0) | 10.10.0.1 | 10.1.0.0/16 via 10.10.0.20 | 10.10.0.1 |
| ext | 10.10.0.40/24 | 10.10.0.1 | 10.1.0.0/16 via 10.10.0.20 | 10.10.0.1 |

## Étape 1 — pfSense, à la main

Dans l'interface web de pfSense (depuis la Kali, avant l'étape 2 : `https://10.10.0.20` ; ensuite : `https://10.1.10.1`) :

| Où | Réglage |
| --- | --- |
| *Interfaces → LAN / OPT1 / OPT2* | *IPv4 Configuration Type* : **Static IPv4** ; 10.1.10.1/24, 10.1.20.1/24, 10.1.30.1/24 ; *IPv4 Upstream gateway* : **None** ; description **SRV** pour OPT1 et **DMZ** pour OPT2 |
| *System → Routing → Gateways* | Supprimer LAN_DHCP, OPT1_DHCP et OPT2_DHCP s'il en reste ; passerelle par défaut : WAN_DHCP |
| *Firewall → NAT → Outbound* | Mode **Automatic** ; vérifier que 10.1.10.0/24, 10.1.20.0/24 et 10.1.30.0/24 figurent dans les règles automatiques |
| *System → General Setup* | DNS **10.10.0.1** ; décocher « Allow DNS server list to be overridden by DHCP/PPP on WAN » |
| *Services → DNS Resolver* | Cocher **Enable Forwarding Mode** |
| *Interfaces → WAN* | « Block private networks » et « Block bogon networks » **décochés** (le WAN est en adresses privées) |

On garde les règles « HRA : tout autoriser » de chaque interface : c'est l'état de départ des TP, et le TP3 les remplace.

## Étape 2 — Réseau de chaque VM

Sur chaque VM, dans la console du portail :

```bash
curl -fsSL https://raw.githubusercontent.com/tahero-madi/securite-reseau/main/hexceos/reseau.sh | sudo bash
```

Sur **srv-int** et **web**, qui ne sortent pas encore sur Internet, ajouter d'abord une route temporaire : `sudo ip route replace default via 10.1.20.1` (`10.1.30.1` sur web).

La dernière ligne doit être verte : « configuration réseau OK ».

## Étape 3 — Logiciels de chaque VM

Sur chaque VM, après l'étape 2 :

```bash
curl -fsSL https://raw.githubusercontent.com/tahero-madi/securite-reseau/main/hexceos/prep.sh | sudo bash
```

| VM | Ce qui est installé | Durée |
| --- | --- | --- |
| Kali | Outils (Wireshark, nmap, arpwatch, arpspoof, radtest, testssl.sh, ssh-audit…), Docker, **Greenbone**, **Zabbix 7.0**, fichiers `~/TP` | 30 à 60 min |
| srv-int | AC du lab, OpenLDAP (alice, bob, carol), FreeRADIUS, collecteur rsyslog, agent Zabbix | 5 à 10 min |
| web | nginx (TLS perfectible), DVWA, Juice Shop, FTP, Telnet, SNMP v2c — volontairement vulnérable | 10 à 15 min |
| cloud-gw | strongSwan, nftables, ulogd2, « VPC » 10.101.1.1, service web « cloud », arpwatch | 2 à 5 min |
| ext | nmap, testssl.sh, ssh-audit, arpspoof, hping3, snmpwalk | 2 min |

Commencez par la **Kali** : le flux de Greenbone se charge en arrière-plan pendant que vous préparez les autres VM. Après l'installation, fermez puis rouvrez la session de la Kali (groupes docker et wireshark).

Le journal complet est dans `/var/log/lab-prep.log`. Le script peut être relancé : il reprend ce qui manque.

## Étape 4 — Vérification, depuis la Kali

```bash
curl -fsSL https://raw.githubusercontent.com/tahero-madi/securite-reseau/main/hexceos/verif.sh | bash
```

Puis, dans Greenbone (adresse dans `~/TP/identifiants-lab.txt`), *Administration → Feed Status* : tous les flux doivent être « Current ».

## Étape 5 — Instantané

Redémarrez les 6 VM, relancez `verif.sh`, puis prenez un instantané de chaque VM (par exemple « depart-formation »). C'est l'état de départ de chaque apprenant ; on y revient en cas de laboratoire cassé.

## Points de vigilance

- **Ne pas rallumer eth0 sur la Kali** ni modifier les routes des VM pendant les TP : le trafic contournerait pfSense.
- **Usurpation ARP du TP1** : elle se joue sur le WAN, entre ext et cloud-gw. Avant de la faire faire aux apprenants, vérifiez que le WAN de chaque environnement est bien isolé : depuis ext, `sudo arping -c3 10.10.0.20` ne doit obtenir qu'une seule adresse MAC.
- **IPsec du TP6** : vérifiez une fois que l'ESP (protocole 50) passe entre pfSense et cloud-gw sur le WAN de la plateforme.
