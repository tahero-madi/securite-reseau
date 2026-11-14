# Corrigé du TP3

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

**Points de vigilance.** pfSense évalue les règles **par interface**, sur le trafic **entrant** dans cette interface, première correspondance gagnante, avec un refus implicite final (non journalisé par défaut → d'où la règle de blocage explicite journalisée). Une règle pour le flux LAN → DMZ s'écrit donc sur l'interface **LAN**.

**Partie A.** Les règles « HRA : tout autoriser » sur le **WAN** signifient que toute machine d'Internet (ici `ext`) joint tout ce que pfSense route : pfSense lui-même, et les réseaux internes. C'est le constat de départ : un pare-feu livré grand ouvert ne filtre rien.

Matrice type (extrait) :

| # | Source | Destination | Port | Action | Justification |
|---|---|---|---|---|---|
| L1 | H_poste_admin | LAN address | TCP 443, 22 | Pass | Administration de pfSense (remplace l'anti-verrouillage, étape 8) |
| L2 | N_LAN | LAN address | TCP/UDP 53 | Pass | DNS (UDP surtout, TCP pour les grosses réponses) |
| L3 | N_LAN | LAN address | UDP 123 | Pass | Heure (NTP) |
| L4 | H_poste_admin | N_SRV, N_DMZ | TCP P_admin, 10050 | Pass | Administration (SSH, LDAP(S), HTTPS), supervision Zabbix |
| L5 | H_poste_admin | N_SRV, N_DMZ | any | Pass (désactivée hors scans) | Scanner Greenbone : il teste tous les ports, TCP et UDP |
| L6 | H_poste_admin | any | ICMP echo request | Pass | Diagnostic (ping, traceroute) et test de présence du scanner |
| L7 | N_LAN | H_web | TCP P_web | Pass | Intranet |
| L8 | H_poste_admin | 10.10.0.30, 10.10.0.40 | TCP 22 | Pass | Administration de ext et cloud-gw (TP 5, 6, 8) |
| L9 | N_LAN | ! N_PRIVE (Internet) | TCP P_web | Pass | Navigation ; `N_PRIVE` = 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 |
| L10 | N_LAN | any | any | Block + log | Refus par défaut, IPv4 et IPv6 |
| S1 | N_SRV | SRV address | 53, 123/udp | Pass | DNS et heure |
| S2 | H_srv_int | H_poste_admin | 10051 | Pass | Agent Zabbix actif (TP 7) |
| S3 | N_SRV | dépôts (alias de noms) | 80, 443 | Pass | Mises à jour |
| S4 | N_SRV | any | any | Block + log | Refus par défaut |
| D1 | N_DMZ | DMZ address | 53, 123/udp | Pass | DNS et heure |
| D2 | N_DMZ | any | any | Block + log | Refus par défaut (DMZ → SRV et DMZ → LAN compris) |
| W1 | any | WAN address | 443 → H_web | NAT | Publication |

Ordre : les services de pfSense (L1 à L3), puis l'administration (L4 à L6), puis les flux utilisateurs (L7 à L9), et le blocage journalisé en dernier. Entre règles « Pass », l'ordre ne change pas le résultat ; il compte dès qu'une règle « Block » s'intercale. Destination « LAN address » plutôt que « This Firewall (self) » : *self* désigne **toutes** les adresses de pfSense, WAN comprise. La règle L5 du scanner est volontairement large : on la désactive (icône ⊘) en dehors des campagnes de scan (TP 2, TP 8) — un scanner est un outil d'attaque. Le flux syslog web → srv-int du TP 7 viendra s'insérer avant D2 : c'est le « flux justifié » de la DMZ.

**Partie B.** Erreurs classiques :
- garder les règles HRA en plus des nouvelles : en tête de liste, elles masquent tout ;
- oublier DNS et NTP vers pfSense : les machines ne résolvent plus rien, `apt` échoue, l'horloge dérive ;
- oublier les règles IPv6 HRA : un réseau « fermé » en IPv4 reste ouvert en IPv6 ;
- placer la règle de blocage avant les règles passantes.

L'alias de noms pour les dépôts (`archive.ubuntu.com`…) est résolu périodiquement par pfSense ; si `apt update` échoue sur une adresse, c'est qu'elle a changé depuis la dernière résolution. En production, on passe plutôt par un miroir ou un proxy interne.

Admin access : montrer depuis `web` que `https://10.1.30.1` ne répond pas, et depuis l'adresse 10.1.10.20 que `https://10.1.10.1` ne répond plus. Point d'architecture : le poste d'administration est ici dans le LAN utilisateurs, faute de zone d'administration dédiée ; on compense par des règles nominatives (`H_poste_admin`) — un auditeur le relèvera au TP 8.

**Pour le formateur.** La suppression des règles HRA du WAN ne gêne pas la console du portail Hexceos (accès à l'écran de la VM, pas par le réseau). Si la plateforme utilisait un accès réseau à pfSense pour sa supervision, il faudrait le savoir avant le TP : à tester sur un environnement.

**Partie C.** Le port forward (NAT) et la règle de filtrage sont deux choses distinctes : insister. La sécurité vient de la règle (443 uniquement, destination = alias du serveur), pas du NAT. En IPv6, pas de NAT : seule la règle compte.

**« À méditer ».** Avec la règle associée par défaut, `ext` joint `10.1.30.10:443` directement : pfSense filtre après traduction, donc la règle autorise « vers 10.1.30.10:443 », quelle que soit l'adresse visée au départ. `ext` peut le faire parce qu'il a une route vers 10.1.0.0/16 par pfSense (comme le ferait un voisin de segment). Avec *Filter rule association* = **Pass**, pfSense laisse passer ce qui a été traduit par la règle NAT, sans règle de filtrage : le trafic direct vers l'adresse privée tombe sur le refus par défaut. Contrepartie : plus de règle de filtrage, donc plus de compteurs ni de journalisation propre à ce flux.

**Partie D.** Les tests doivent tous passer comme « attendu ». Si DMZ → SRV est autorisé par erreur, c'est le constat pédagogique majeur : une segmentation annoncée mais non filtrée ne vaut rien. Les journaux du pare-feu montrent les refus → lien avec la journalisation (module 7). L'adresse 10.1.10.20 ajoutée à la Kali simule un poste utilisateur : pfSense ne connaît que l'adresse source, il applique donc les règles « utilisateur ».

**Questions.** 1 : pour détecter les tentatives et disposer de preuves ; un refus silencieux ne laisse aucune trace. 2 : la règle de filtrage associée (port et destination restreints) et le durcissement du service lui-même ; le NAT ne filtre pas. 3 : refuser : `any:any` supprime tout le cloisonnement sortant (canal de C2 et d'exfiltration ouvert), empêche la détection et contrevient au moindre privilège ; proposer des règles précises par besoin.

---

[← TP2](../../tp2/README.md) · [Sommaire](../../README.md) · [Énoncé](../README.md) · [En cas de blocage](../../en-cas-de-blocage.md) · [TP4 →](../../tp4/README.md)
