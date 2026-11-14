# Matrice de flux — TP3

**Auteur :** …  **Date :** …

## 1. État des lieux (étape 1)

Règles présentes sur chaque interface avant le TP, et ce qu'elles signifient pour une machine d'Internet comme `ext` :

…

## 2. Matrice de flux

Une ligne par flux autorisé, plus une ligne de refus par défaut pour chaque interface. La colonne « Règle » reprend la description saisie dans pfSense.

| Règle | Interface | Source | Destination | Protocole / port | Action | Justification |
|---|---|---|---|---|---|---|
| L1 | LAN | | | | Pass | |
| L2 | LAN | | | | Pass | |
| | LAN | | | | | |
| | LAN | | | | | |
| | LAN | | | | | |
| | LAN | | | | | |
| | LAN | | | | | |
| | LAN | | | | | |
| | LAN | | | | | |
| L10 | LAN | any | any | any | Block + log | Refus par défaut |
| S1 | SRV | | | | Pass | |
| | SRV | | | | | |
| | SRV | | | | | |
| | SRV | | | | | |
| S5 | SRV | any | any | any | Block + log | Refus par défaut |
| D1 | DMZ | | | | Pass | |
| | DMZ | | | | | |
| | DMZ | | | | | |
| D4 | DMZ | any | any | any | Block + log | Refus par défaut |
| W1 | WAN | | | | NAT + Pass | Publication de web |

## 3. Tableau de tests (étape 12)

| # | Depuis | Vers | Commande | Attendu | Obtenu | Règle en cause |
|---|---|---|---|---|---|---|
| T1 | Kali (admin) | web 443 | `nc -vz -w3 10.1.30.10 443` | Autorisé | | |
| T2 | Kali (admin) | srv-int 22 | `nc -vz -w3 10.1.20.10 22` | Autorisé | | |
| T3 | poste utilisateur | srv-int 22 | `nc -vz -w3 -s 10.1.10.20 10.1.20.10 22` | Refusé | | |
| T4 | poste utilisateur | pfSense 443 | `curl -kI -m5 --interface 10.1.10.20 https://10.1.10.1` | Refusé | | |
| T5 | poste utilisateur | web 443 | `nc -vz -w3 -s 10.1.10.20 10.1.30.10 443` | Autorisé | | |
| T6 | poste utilisateur | Internet 443 | `curl -sI -m5 --interface 10.1.10.20 https://github.com` | Autorisé | | |
| T7 | web | srv-int 22 | `nc -vz -w3 10.1.20.10 22` | Refusé | | |
| T8 | web | Kali 22 | `nc -vz -w3 10.1.10.10 22` | Refusé | | |
| T9 | web | pfSense 443 | `curl -kI -m5 https://10.1.30.1` | Refusé | | |
| T10 | srv-int | Internet 443 | `curl -sI -m5 https://github.com` | Refusé | | |
| T11 | srv-int | dépôts Ubuntu | `sudo apt update` | Autorisé | | |
| T12 | ext | 10.10.0.20:22 | `nc -vz -w3 10.10.0.20 22` | Refusé | | |
| T13 | ext | 10.10.0.20:443 | `curl -kI https://10.10.0.20` | Autorisé (web) | | |
| T14 | ext | 10.1.30.10:443 | `nc -vz -w3 10.1.30.10 443` | Refusé (avec *Pass*) | | |

## 4. Écarts et corrections

Pour chaque test dont le résultat obtenu diffère de l'attendu : la cause, et la correction apportée.

- …
