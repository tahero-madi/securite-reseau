# Cartographie du laboratoire — TP1

**Auteur :** …  **Date :** …
**Périmètre autorisé :** 10.1.10.0/24 (LAN), 10.1.20.0/24 (SRV), 10.1.30.0/24 (DMZ) ; sur le WAN : 10.10.0.20, 10.10.0.30, 10.10.0.40.
**Méthode :** `nmap -sn` (découverte), `nmap -sV -O --top-ports 200` (services), scripts NSE, observations Wireshark et tcpdump.

## 1. Inventaire des hôtes

Une ligne par hôte trouvé. « Documenté » : l'hôte figure-t-il dans la topologie fournie ?

| Adresse | Nom | Réseau | Rôle supposé | Documenté (oui/non) | Remarques |
|---|---|---|---|---|---|
| 10.1.10.1 | | LAN | | | |
| 10.1.10.10 | | LAN | | | |
| | | | | | |
| | | | | | |
| | | | | | |
| | | | | | |
| | | | | | |
| | | | | | |
| | | | | | |

## 2. Services exposés

Une ligne par port ouvert sur les serveurs balayés (srv-int, web).

| Hôte | Port/protocole | Service annoncé par nmap | Version annoncée | Nécessaire au rôle ? (oui/non) | Chiffré ? (oui/non) | Remarques |
|---|---|---|---|---|---|---|
| | | | | | | |
| | | | | | | |
| | | | | | | |
| | | | | | | |
| | | | | | | |
| | | | | | | |
| | | | | | | |
| | | | | | | |
| | | | | | | |
| | | | | | | |

Système d'exploitation annoncé par nmap pour chaque serveur, et votre avis sur sa fiabilité :

- srv-int : …
- web : …

## 3. Flux observés

Les échanges constatés pendant le TP (étapes 5 et 6), avec leur chemin réel.

| Source | Destination | Protocole/port | Passe par | En clair ? | Remarques |
|---|---|---|---|---|---|
| Kali 10.1.10.10 | web 10.1.30.10 | FTP 21/tcp | pfSense | | |
| cloud-gw 10.10.0.30 | pfSense 10.10.0.20 | ICMP | | | avant l'usurpation |
| cloud-gw 10.10.0.30 | pfSense 10.10.0.20 | ICMP | | | pendant l'usurpation |
| | | | | | |

## 4. Schéma

Dessinez le réseau tel que vous l'avez observé (zones, hôtes, pare-feu, hôtes non documentés). Un schéma en texte suffit.

```text
            WAN 10.10.0.0/24
   ext .40 ──┬── cloud-gw .30
             │
         pfSense .20
     ┌───────┼───────┐
    LAN     SRV     DMZ
    …        …       …
```

## 5. Observations de couche 2 (usurpation ARP)

| Moment | Adresse MAC associée à 10.10.0.20 sur cloud-gw | Machine réelle derrière cette MAC |
|---|---|---|
| Avant | | |
| Pendant | | |
| Après | | |

Message d'arpwatch relevé : …

## 6. Écarts avec la topologie fournie

- …
- …
- …
