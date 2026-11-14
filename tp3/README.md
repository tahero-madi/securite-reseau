# TP3 — Cloisonnement et filtrage avec pfSense

**Jour 2, 10:20 · 1 h 40.** Objectifs : mettre en œuvre un zonage LAN/SRV/DMZ sur pfSense ; traduire une matrice de flux en règles « refus par défaut » ; configurer le NAT de publication ; activer la journalisation ; vérifier le cloisonnement par des tests de flux.

**Prérequis** : module 3, TP 1. **Livrable** : `matrice-flux.md` (matrice et tableau de tests, à partir du modèle fourni) + l'export des règles de pfSense, dans `~/livrables`.

**Déroulé** : étapes 1 et 2 (état des lieux, matrice) 15 min · étapes 3 à 8 (alias et règles) 40 min · étapes 9 et 10 (publication) 15 min · étapes 11 et 12 (tests) 20 min · étape 13 (export) 5 min.

> **Avant de commencer**, prenez un instantané de **pfSense** depuis le portail, nommé `avant-tp3` (bouton appareil photo). Ne touchez pas à l'instantané `initial`.

## Étape 1 — Faire l'état des lieux

**Pourquoi.** Avant de filtrer, on regarde ce que le pare-feu laisse passer aujourd'hui. pfSense évalue les règles **interface par interface**, sur le trafic qui **entre** par cette interface, de haut en bas : la première règle qui correspond décide. Si aucune ne correspond, le paquet est refusé, sans trace dans les journaux.

Sur pfSense (`https://10.1.10.1`) :

1. *Interfaces → Assignments* : repérez les quatre interfaces : WAN (10.10.0.20), LAN (10.1.10.1), SRV (10.1.20.1), DMZ (10.1.30.1).
2. *Firewall → Rules* : ouvrez chaque onglet (WAN, LAN, SRV, DMZ). Sur **chaque** interface, y compris le WAN, deux règles « HRA : tout autoriser » (IPv4 et IPv6), posées par la plateforme, laissent tout passer.

Qu'est-ce que cela signifie pour une machine d'Internet, comme `ext` ? Notez votre réponse dans la matrice.

## Étape 2 — Écrire la matrice de flux

**Pourquoi.** La matrice de flux est la politique de sécurité réseau écrite noir sur blanc : qui parle à qui, sur quel port, et pourquoi. Chaque règle du pare-feu doit correspondre à une ligne de la matrice, et chaque ligne doit être justifiée. C'est elle que l'auditeur relira au TP8.

Récupérez le modèle et ouvrez-le :

```bash
cd ~/livrables
curl -fsSLO https://raw.githubusercontent.com/tahero-madi/securite-reseau/main/tp3/modeles/matrice-flux.md
mousepad matrice-flux.md &
```

**Ligne par ligne.**

- `curl -fsSLO <adresse>` : télécharge le modèle depuis le dépôt et garde son nom (`-O`).
- `mousepad matrice-flux.md &` : l'ouvre dans l'éditeur, en arrière-plan.

Les besoins à couvrir :

- **postes utilisateurs** du LAN → l'intranet (`web`) en 80/443, et Internet en 80/443 ;
- **poste d'administration** (`10.1.10.10`, votre Kali) → administration de pfSense (443, 22), de SRV et de la DMZ (SSH, LDAP(S), HTTPS, agent Zabbix 10050), et des machines du WAN `ext` et `cloud-gw` en SSH ;
- **scanner Greenbone** (sur la Kali) → tous les ports de SRV et de la DMZ, pendant les campagnes de scan seulement ;
- **ping** depuis le poste d'administration, pour le diagnostic ;
- chaque zone → pfSense pour le **DNS** (53, en TCP **et** UDP) et l'**heure** (NTP, UDP 123) : sans eux, plus rien ne fonctionne ;
- SRV → Kali en TCP 10051 (agent Zabbix actif, TP 7) ;
- SRV et DMZ → Internet **interdit**, sauf les dépôts de mises à jour ;
- DMZ → SRV et DMZ → LAN **interdits** ;
- Internet (WAN) → `web` en 443 uniquement (publication) ;
- tout le reste refusé et **journalisé**, IPv6 compris.

Les étapes suivantes donnent les règles qui traduisent cette matrice. Comparez-les à la vôtre avant de les saisir.

## Étape 3 — Créer les alias

**Pourquoi.** Un alias donne un nom à une adresse, un groupe d'adresses ou un groupe de ports. Les règles deviennent lisibles (`H_web` plutôt que `10.1.30.10`), et une modification se fait à un seul endroit.

*Firewall → Aliases*. Pour chaque alias : onglet **IP** ou **Ports**, bouton **Add**, renseignez *Name*, *Type* et les valeurs (un champ par valeur, bouton **Add Host** / **Add Network** / **Add Port** pour en ajouter), puis *Save*. À la fin, **Apply Changes**.

| Onglet | Nom | Type | Valeurs |
|---|---|---|---|
| IP | `H_poste_admin` | Host(s) | 10.1.10.10 |
| IP | `H_srv_int` | Host(s) | 10.1.20.10 |
| IP | `H_web` | Host(s) | 10.1.30.10 |
| IP | `H_wan_lab` | Host(s) | 10.10.0.30, 10.10.0.40 |
| IP | `H_depots` | Host(s) | archive.ubuntu.com, security.ubuntu.com, repo.zabbix.com |
| IP | `N_LAN` | Network(s) | 10.1.10.0/24 |
| IP | `N_SRV` | Network(s) | 10.1.20.0/24 |
| IP | `N_DMZ` | Network(s) | 10.1.30.0/24 |
| IP | `N_ZONES` | Network(s) | 10.1.20.0/24, 10.1.30.0/24 |
| IP | `N_PRIVE` | Network(s) | 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 |
| Ports | `P_web` | Port(s) | 80, 443 |
| Ports | `P_admin` | Port(s) | 22, 443, 389, 636, 10050 |

Deux alias méritent une explication :

- `H_depots` contient des **noms** : pfSense les résout régulièrement en adresses. C'est ce qui permettra à SRV et DMZ de joindre les dépôts de mises à jour, et rien d'autre.
- `N_PRIVE` regroupe toutes les plages d'adresses privées. Dans une règle, `! N_PRIVE` (destination inversée) signifie « tout sauf les réseaux privés », c'est-à-dire **Internet**.

## Étape 4 — Savoir créer une règle

**Pourquoi.** Toutes les règles des étapes suivantes se créent de la même façon. On le détaille une fois.

*Firewall → Rules*, onglet de l'interface, puis le bouton **Add** avec la **flèche vers le bas** (il ajoute la règle **en bas** de la liste). Les champs :

| Champ | Ce qu'on y met |
|---|---|
| *Action* | **Pass** (autoriser) ou **Block** (refuser) |
| *Interface* | l'interface d'entrée (déjà remplie) |
| *Address Family* | **IPv4**, ou **IPv4+IPv6** pour les règles de blocage |
| *Protocol* | **TCP**, **UDP**, **TCP/UDP**, **ICMP** (puis *ICMP subtypes* : *Echo request*) ou **Any** |
| *Source* | *Address or Alias* + le nom de l'alias, ou *LAN subnets*, etc. |
| *Destination* | idem ; *LAN address* désigne l'adresse de pfSense sur cette interface ; la case *Invert match* inverse la destination (`! N_PRIVE`) |
| *Destination Port Range* | un port connu dans la liste, ou *(other)* puis le nom d'un alias de ports dans *Custom* (dans *From* et dans *To*) |
| *Log* | coché pour les règles de blocage |
| *Description* | la référence de la ligne de matrice, par exemple `L4 Admin SRV/DMZ` |

Puis *Save*. Les règles ne s'appliquent qu'après **Apply Changes**, en haut de la page. Pour changer l'ordre, faites glisser les lignes, puis *Save*.

## Étape 5 — Règles de l'interface LAN

**Pourquoi.** Le LAN contient les postes : ce sont eux qu'un attaquant compromet le plus souvent (hameçonnage). On leur ouvre seulement ce dont ils ont besoin ; le poste d'administration, lui, a des droits supplémentaires, nominatifs.

Onglet **LAN**, ajoutez dans cet ordre :

| # | Action | Protocole | Source | Destination | Port | Log | Description |
|---|---|---|---|---|---|---|---|
| L1 | Pass | TCP | H_poste_admin | LAN address | 443 puis 22 (deux règles, ou un alias) | | Admin pfSense |
| L2 | Pass | TCP/UDP | N_LAN | LAN address | 53 (DNS) | | DNS |
| L3 | Pass | UDP | N_LAN | LAN address | 123 (NTP) | | Heure |
| L4 | Pass | TCP | H_poste_admin | N_ZONES | P_admin | | Admin SRV et DMZ, Zabbix |
| L5 | Pass | Any | H_poste_admin | N_ZONES | — | | Scanner Greenbone (désactivée hors scans) |
| L6 | Pass | ICMP, *Echo request* | H_poste_admin | any | — | | Ping de diagnostic |
| L7 | Pass | TCP | N_LAN | H_web | P_web | | Intranet |
| L8 | Pass | TCP | H_poste_admin | H_wan_lab | 22 (SSH) | | Admin ext et cloud-gw |
| L9 | Pass | TCP | N_LAN | `! N_PRIVE` (*Invert match*) | P_web | | Navigation Internet |
| L10 | **Block** | Any, **IPv4+IPv6** | any | any | — | **coché** | Refus par défaut LAN |

Puis :

1. **Supprimez** les deux règles « HRA : tout autoriser » de l'onglet LAN (icône corbeille sur chaque ligne).
2. **Apply Changes**.
3. Vérifiez que la Kali fonctionne toujours : l'interface de pfSense reste ouverte, et dans un terminal :

```bash
getent hosts github.com
curl -sI https://github.com | head -1
```

**Ligne par ligne.**

- `getent hosts github.com` : résout le nom par le DNS de pfSense (règle L2). Une adresse doit s'afficher.
- `curl -sI https://github.com | head -1` : demande l'en-tête de la page d'accueil de GitHub (règle L9) et n'affiche que la première ligne. `HTTP/2 200` attendu.

Enfin, **désactivez la règle L5** (icône ⊘ sur sa ligne, puis *Apply Changes*) : on ne la réactivera que pour les campagnes de scan. Un scanner est un outil d'attaque.

## Étape 6 — Règles de l'interface SRV

**Pourquoi.** La zone serveurs héberge l'annuaire et le RADIUS : un serveur interne n'a presque jamais besoin de joindre Internet, ni d'ouvrir des connexions vers d'autres zones. Les réponses aux connexions autorisées depuis le LAN repartent automatiquement : pfSense garde l'état de chaque connexion et n'a pas besoin de règle « retour ».

Onglet **SRV** (ou OPT1) :

| # | Action | Protocole | Source | Destination | Port | Log | Description |
|---|---|---|---|---|---|---|---|
| S1 | Pass | TCP/UDP | N_SRV | SRV address | 53 (DNS) | | DNS |
| S2 | Pass | UDP | N_SRV | SRV address | 123 (NTP) | | Heure |
| S3 | Pass | TCP | H_srv_int | H_depots | P_web | | Mises à jour |
| S4 | Pass | TCP | H_srv_int | H_poste_admin | 10051 | | Agent Zabbix actif (TP 7) |
| S5 | **Block** | Any, **IPv4+IPv6** | any | any | — | **coché** | Refus par défaut SRV |

Supprimez les deux règles HRA de l'onglet, puis **Apply Changes**.

## Étape 7 — Règles de l'interface DMZ

**Pourquoi.** La DMZ contient le serveur exposé à Internet : c'est le plus susceptible d'être compromis. Il ne doit pouvoir atteindre ni le LAN ni les serveurs internes, pour qu'une compromission ne se propage pas.

Onglet **DMZ** (ou OPT2) :

| # | Action | Protocole | Source | Destination | Port | Log | Description |
|---|---|---|---|---|---|---|---|
| D1 | Pass | TCP/UDP | N_DMZ | DMZ address | 53 (DNS) | | DNS |
| D2 | Pass | UDP | N_DMZ | DMZ address | 123 (NTP) | | Heure |
| D3 | Pass | TCP | H_web | H_depots | P_web | | Mises à jour |
| D4 | **Block** | Any, **IPv4+IPv6** | any | any | — | **coché** | Refus par défaut DMZ (vers SRV et LAN compris) |

Supprimez les deux règles HRA de l'onglet, puis **Apply Changes**.

## Étape 8 — WAN et accès d'administration

**Pourquoi.** Sans règle sur le WAN, pfSense refuse tout ce qui arrive d'Internet : c'est le comportement voulu, la publication de l'étape 9 ajoutera la seule exception. Quant à la règle « anti-verrouillage », elle ouvre l'interface d'administration à **tout** le LAN : on la remplace par la règle L1, réservée au poste d'administration.

1. Onglet **WAN** : supprimez les deux règles HRA, puis **Apply Changes**.
2. *System → Advanced → Admin Access* : cochez **Disable webConfigurator anti-lockout rule**, puis *Save*. Vérifiez que vous accédez toujours à pfSense depuis la Kali : c'est la règle L1 qui vous laisse entrer.

> **Ne vous enfermez pas dehors.** Gardez l'onglet de pfSense ouvert et testez dans un second onglet. En cas de blocage : ouvrez la **console de pfSense** depuis le portail ; l'option 8 donne un shell, où `pfctl -d` désactive le filtrage le temps de corriger, et `pfctl -e` le réactive. Sinon, restaurez l'instantané `avant-tp3` de pfSense.

## Étape 9 — Publier le serveur web

**Pourquoi.** Publier un service, c'est rendre un serveur interne joignable depuis Internet par l'adresse publique du pare-feu. Le NAT traduit l'adresse ; c'est la règle de filtrage associée qui décide de ce qui passe.

*Firewall → NAT → Port Forward* → **Add** :

- *Interface* : WAN ; *Protocol* : TCP ;
- *Destination* : **WAN address** ; *Destination port range* : HTTPS (443) ;
- *Redirect target IP* : *Address or Alias*, `H_web` ; *Redirect target port* : HTTPS (443) ;
- *Description* : `W1 Publication web` ;
- *Filter rule association* : **Add associated filter rule** ;
- *Save*, puis **Apply Changes**.

Allez voir l'onglet **WAN** de *Firewall → Rules* : une règle a été créée automatiquement. Vérifiez qu'elle n'autorise **que** TCP 443 vers `H_web`.

## Étape 10 — Tester la publication depuis Internet

**Pourquoi.** On vérifie du point de vue d'un attaquant : depuis `ext`, une machine d'Internet, seul le service publié doit répondre.

Depuis la Kali, connectez-vous à `ext` (`ssh formation@10.10.0.40`), puis :

```bash
curl -kI https://10.10.0.20
nc -vz -w3 10.10.0.20 22
nc -vz -w3 10.10.0.20 80
nc -vz -w3 10.1.30.10 22
nc -vz -w3 10.1.30.10 443
```

**Ligne par ligne.**

- `curl -kI https://10.10.0.20` : demande l'en-tête HTTPS à l'adresse publique ; `-k` accepte le certificat autosigné, `-I` ne récupère que l'en-tête. La réponse vient de nginx, sur `web` : la publication fonctionne. La publication de 443 masque aussi l'interface web de pfSense côté WAN, ce qui est souhaitable.
- `nc -vz -w3 10.10.0.20 22` : teste l'ouverture du port 22 de l'adresse publique ; `-z` teste sans envoyer de données, `-v` affiche le résultat, `-w3` abandonne après 3 secondes. Doit échouer, comme le port 80.
- `nc -vz -w3 10.1.30.10 22` : tente de joindre `web` **directement par son adresse privée** (ext a une route vers les réseaux internes par pfSense). Doit échouer.
- `nc -vz -w3 10.1.30.10 443` : même chose sur le port 443. Que constatez-vous ?

> **À méditer.** `ext` joint `10.1.30.10:443` directement, sans passer par l'adresse publiée. Pourquoi ? Indice : pfSense filtre **après** la traduction d'adresse, et la règle associée au NAT autorise « vers 10.1.30.10:443 ». Sur le vrai Internet, une adresse privée n'est jamais routée jusqu'à vous ; mais un voisin du même segment WAN (l'hébergeur, le FAI) le peut.
>
> Correction : dans *Firewall → NAT → Port Forward*, modifiez la publication et choisissez *Filter rule association* = **Pass**, puis *Save* et *Apply Changes* ; supprimez ensuite la règle WAN associée, devenue inutile. Avec **Pass**, pfSense laisse passer ce qui a été traduit par la règle NAT, sans règle de filtrage. Refaites les deux tests vers 443 : l'adresse publique répond toujours, l'adresse privée ne répond plus.

## Étape 11 — Simuler un poste utilisateur

**Pourquoi.** Votre LAN ne contient qu'un poste, la Kali, qui a des droits d'administration. Pour tester les droits d'un **poste utilisateur**, on donne à la Kali une seconde adresse, `10.1.10.20`, qui ne bénéficie que des règles `N_LAN`.

```bash
sudo ip addr add 10.1.10.20/24 dev eth0
ip -br a show eth0
```

**Ligne par ligne.**

- `ip addr add 10.1.10.20/24 dev eth0` : ajoute une seconde adresse à la carte `eth0`, sans retirer la première.
- `ip -br a show eth0` : vérifie que la carte porte maintenant 10.1.10.10 et 10.1.10.20.

Pour qu'un test parte de cette adresse, on l'indique explicitement : `nc -s 10.1.10.20` ou `curl --interface 10.1.10.20`.

## Étape 12 — Vérifier le cloisonnement

**Pourquoi.** Une politique de filtrage ne vaut que si elle est vérifiée. On teste chaque ligne importante de la matrice, depuis la bonne source, et on compare l'attendu à l'obtenu.

Exécutez les tests suivants et reportez le résultat dans le tableau de tests de `matrice-flux.md`. Pour un test depuis web ou srv-int, connectez-vous d'abord en SSH depuis la Kali (`ssh formation@10.1.30.10`, depuis 10.1.10.10 : autorisé par L4). Si une règle vous empêche d'y entrer, ouvrez la console de la machine depuis le portail.

| Depuis | Vers | Commande | Attendu |
|---|---|---|---|
| Kali (admin) | web 443 | `nc -vz -w3 10.1.30.10 443` | Autorisé |
| Kali (admin) | srv-int 22 | `nc -vz -w3 10.1.20.10 22` | Autorisé |
| poste utilisateur | srv-int 22 | `nc -vz -w3 -s 10.1.10.20 10.1.20.10 22` | Refusé |
| poste utilisateur | pfSense 443 | `curl -kI -m5 --interface 10.1.10.20 https://10.1.10.1` | Refusé |
| poste utilisateur | web 443 | `nc -vz -w3 -s 10.1.10.20 10.1.30.10 443` | Autorisé |
| poste utilisateur | Internet 443 | `curl -sI -m5 --interface 10.1.10.20 https://github.com` | Autorisé |
| web | srv-int 22 | sur web : `nc -vz -w3 10.1.20.10 22` | Refusé |
| web | Kali 22 | sur web : `nc -vz -w3 10.1.10.10 22` | Refusé |
| web | pfSense 443 | sur web : `curl -kI -m5 https://10.1.30.1` | Refusé |
| srv-int | Internet 443 | sur srv-int : `curl -sI -m5 https://github.com` | Refusé |
| srv-int | dépôts Ubuntu | sur srv-int : `sudo apt update` | Autorisé |
| ext | 10.10.0.20:22 | sur ext : `nc -vz -w3 10.10.0.20 22` | Refusé |
| ext | 10.10.0.20:443 | sur ext : `curl -kI https://10.10.0.20` | Autorisé (web) |
| ext | 10.1.30.10:443 | sur ext : `nc -vz -w3 10.1.30.10 443` | Refusé (avec *Pass*) |

**Ligne par ligne.**

- `-s 10.1.10.20` (nc) et `--interface 10.1.10.20` (curl) : font partir la connexion de l'adresse du poste utilisateur.
- `-m5` (curl) : abandonne après 5 secondes ; un refus de pfSense se traduit par une attente puis un échec, pas par un message d'erreur immédiat.
- `sudo apt update` : interroge les dépôts Ubuntu, autorisés par S3 grâce à l'alias de noms `H_depots`.

Consultez ensuite *Status → System Logs → Firewall* : vos refus apparaissent, horodatés, avec la règle qui les a bloqués. Filtrez par interface.

Retirez enfin l'adresse de test :

```bash
sudo ip addr del 10.1.10.20/24 dev eth0
```

**Ligne par ligne.**

- `ip addr del 10.1.10.20/24 dev eth0` : retire la seconde adresse de la carte ; la Kali retrouve sa seule adresse 10.1.10.10.

> **Défi ★.** Ajoutez un réseau invité isolé (interface virtuelle VLAN 90 sur LAN) : accès Internet seulement, aucun accès aux autres zones. Écrivez ses règles. Discutez de la sécurité de couche 2 nécessaire sur le commutateur pour que ce VLAN tienne réellement.

## Étape 13 — Exporter les règles

**Pourquoi.** La configuration du pare-feu est une preuve d'audit et une sauvegarde : on l'exporte à chaque changement important.

*Diagnostics → Backup & Restore* : *Backup area* = **Firewall Rules**, puis **Download configuration as XML**. Déplacez le fichier dans vos livrables :

```bash
mv "$(ls -t ~/Téléchargements/*.xml | head -1)" ~/livrables/tp3-regles-pfsense.xml
```

**Ligne par ligne.**

- `mv "$(ls -t ~/Téléchargements/*.xml | head -1)" …` : déplace le fichier XML le plus récent des téléchargements vers vos livrables, sous un nom explicite.

**Livrable** (dans `~/livrables`) : `matrice-flux.md` (matrice et tableau de tests complétés) et `tp3-regles-pfsense.xml`.

## Questions de validation

1. Pourquoi la règle de blocage final doit-elle être journalisée ?
2. Le port forward crée l'accès ; qu'est-ce qui assure réellement la sécurité du service publié ?
3. Un collègue propose une règle `N_LAN → any: any` « pour simplifier ». Que répondez-vous ?

---

[← TP2](../tp2/README.md) · [Sommaire](../README.md) · [Corrigé](corrige/README.md) · [En cas de blocage](../en-cas-de-blocage.md) · [TP4 →](../tp4/README.md)
