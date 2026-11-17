# Corrigé du TP3

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

## Configuration de référence à restaurer

Si vous êtes bloqué, ou pour comparer avec votre configuration, le dossier [`pfsense/`](pfsense/) contient la configuration attendue du TP, au format de sauvegarde de pfSense :

| Ordre | *Restore area* | Fichier | Contenu |
|---|---|---|---|
| 1 | **Aliases** | [`1-alias-tp3.xml`](pfsense/1-alias-tp3.xml) | Les alias de l'étape 3, plus `P_admin_fw` (ports 443 et 22 de l'administration de pfSense, utilisé par L1) |
| 2 | **Firewall Rules** | [`2-regles-tp3.xml`](pfsense/2-regles-tp3.xml) | Les règles LAN (L1 à L10), SRV (S1 à S5) et DMZ (D1 à D4) ; plus aucune règle sur le WAN, hormis celle associée à la publication |
| 3 | **NAT** | [`3-nat-tp3.xml`](pfsense/3-nat-tp3.xml) | NAT sortant en *Automatic* et publication W1 de `web` en 443, avec *Filter rule association* = **Pass** |

### Ce que contiennent les fichiers

**Alias** (*Firewall → Aliases*)

| Alias | Type | Contenu | Rôle |
|---|---|---|---|
| `H_poste_admin` | Host | 10.1.10.10 | Poste d'administration (Kali) |
| `H_srv_int` | Host | 10.1.20.10 | srv-int |
| `H_web` | Host | 10.1.30.10 | web |
| `H_wan_lab` | Host | 10.10.0.30, 10.10.0.40 | cloud-gw et ext |
| `H_depots` | Host (noms DNS) | archive.ubuntu.com, security.ubuntu.com, repo.zabbix.com | Dépôts de mises à jour |
| `N_LAN` | Network | 10.1.10.0/24 | LAN |
| `N_SRV` | Network | 10.1.20.0/24 | SRV |
| `N_DMZ` | Network | 10.1.30.0/24 | DMZ |
| `N_ZONES` | Network | 10.1.20.0/24, 10.1.30.0/24 | SRV et DMZ |
| `N_PRIVE` | Network | 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 | Plages privées (RFC 1918) |
| `P_web` | Port | 80, 443 | HTTP, HTTPS |
| `P_admin` | Port | 22, 443, 389, 636, 10050 | SSH, HTTPS, LDAP, LDAPS, agent Zabbix |
| `P_admin_fw` | Port | 443, 22 | Administration de pfSense |

**Règles de l'interface LAN** (lues de haut en bas, première correspondance gagnante)

| N° | Action | IP | Protocole | Source | Destination | Port | Description |
|---|---|---|---|---|---|---|---|
| L1 | Pass | IPv4 | TCP | `H_poste_admin` | LAN address | `P_admin_fw` | Administration de pfSense |
| L2 | Pass | IPv4 | TCP/UDP | `N_LAN` | LAN address | 53 | DNS |
| L3 | Pass | IPv4 | UDP | `N_LAN` | LAN address | 123 | Heure (NTP) |
| L4 | Pass | IPv4 | TCP | `H_poste_admin` | `N_ZONES` | `P_admin` | Administration de SRV et DMZ, agent Zabbix |
| L5 | Pass (**désactivée**) | IPv4 | any | `H_poste_admin` | `N_ZONES` | any | Scanner Greenbone, activée seulement pendant les scans |
| L6 | Pass | IPv4 | ICMP (echo request) | `H_poste_admin` | any | — | Ping de diagnostic |
| L7 | Pass | IPv4 | TCP | `N_LAN` | `H_web` | `P_web` | Intranet |
| L8 | Pass | IPv4 | TCP | `H_poste_admin` | `H_wan_lab` | 22 | Administration d'ext et de cloud-gw |
| L9 | Pass | IPv4 | TCP | `N_LAN` | **`! N_PRIVE`** (tout sauf les plages privées) | `P_web` | Navigation Internet |
| L10 | Block, **journalisée** | IPv4+IPv6 | any | any | any | any | Refus par défaut du LAN |

**Règles de l'interface SRV**

| N° | Action | IP | Protocole | Source | Destination | Port | Description |
|---|---|---|---|---|---|---|---|
| S1 | Pass | IPv4 | TCP/UDP | `N_SRV` | SRV address | 53 | DNS |
| S2 | Pass | IPv4 | UDP | `N_SRV` | SRV address | 123 | Heure (NTP) |
| S3 | Pass | IPv4 | TCP | `H_srv_int` | `H_depots` | `P_web` | Mises à jour |
| S4 | Pass | IPv4 | TCP | `H_srv_int` | `H_poste_admin` | 10051 | Agent Zabbix actif vers le serveur |
| S5 | Block, **journalisée** | IPv4+IPv6 | any | any | any | any | Refus par défaut de SRV |

**Règles de l'interface DMZ**

| N° | Action | IP | Protocole | Source | Destination | Port | Description |
|---|---|---|---|---|---|---|---|
| D1 | Pass | IPv4 | TCP/UDP | `N_DMZ` | DMZ address | 53 | DNS |
| D2 | Pass | IPv4 | UDP | `N_DMZ` | DMZ address | 123 | Heure (NTP) |
| D3 | Pass | IPv4 | TCP | `H_web` | `H_depots` | `P_web` | Mises à jour |
| D4 | Block, **journalisée** | IPv4+IPv6 | any | any | any | any | Refus par défaut de la DMZ (dont DMZ → SRV et DMZ → LAN) |

**Interface WAN et NAT**

| N° | Type | Interface | Source | Destination | Port | Redirigé vers | Règle de filtrage |
|---|---|---|---|---|---|---|---|
| W1 | Port forward (*Firewall → NAT*) | WAN | any | WAN address | 443/TCP | `H_web`, port 443 | *Filter rule association* = **Pass** : aucune règle séparée sur le WAN |
| — | NAT sortant | — | — | — | — | — | Mode **Automatic** |

C'est l'**état final**, après la correction de l'étape 10. À l'étape 9, la publication est d'abord créée avec *Add associated filter rule* : une règle visible apparaît alors sur l'onglet WAN (TCP 443 vers `H_web`). L'encadré « À méditer » de l'étape 10 montre qu'elle laisse aussi passer l'accès direct à 10.1.30.10:443, et la remplace par *Filter rule association* = **Pass** : la règle WAN associée est alors supprimée, et c'est la règle NAT elle-même qui laisse passer le trafic publié (`pfctl -sn | grep rdr` dans *Diagnostics → Command Prompt* la montre : `rdr pass …`).

Sur le WAN, aucune autre règle : les règles « HRA : tout autoriser » ont disparu, tout le reste tombe sur le refus implicite de pfSense.

> **Attention :** la restauration **remplace** toutes vos règles de filtrage (WAN compris) et toute la section NAT. Prenez d'abord un instantané de pfSense depuis le portail, et exportez votre propre configuration si vous voulez la comparer ensuite.

Téléchargez les trois fichiers sur la Kali :

```bash
cd ~/livrables
for f in 1-alias-tp3.xml 2-regles-tp3.xml 3-nat-tp3.xml; do curl -fsSLO https://raw.githubusercontent.com/tahero-madi/securite-reseau/main/tp3/corrige/pfsense/$f; done
ls -l *-tp3.xml
```

Puis, dans pfSense, *Diagnostics → Backup & Restore*, section **Restore Backup**, **dans l'ordre du tableau** (les règles utilisent les alias) : choisir la *Restore area*, *Parcourir* le fichier, **Restore Configuration**. Ensuite :

- *Status → Filter Reload* → **Reload Filter** ;
- *System → Advanced → Admin Access* : cocher **Disable webConfigurator anti-lockout rule**, puis *Save* (ce réglage n'est pas dans les fichiers ; la règle L1 garde l'accès depuis la Kali) ;
- la règle **L5** (scanner Greenbone) est importée **désactivée**, comme dans l'énoncé : réactivez-la seulement pendant les scans.

**Ligne par ligne.**

- `curl -fsSLO <url>` : télécharge le fichier et l'enregistre sous son nom d'origine (`-O`), en échouant proprement si le fichier n'existe pas (`-f`), sans barre de progression (`-sS`) et en suivant les redirections (`-L`).
- `ls -l *-tp3.xml` : vérifie que les trois fichiers sont bien là.

En cas de perte d'accès à l'interface après la restauration : console de pfSense (bouton écran du portail), option **8**, puis `pfctl -d` pour couper temporairement le filtrage, ou restauration de l'instantané.

Si `apt update` échoue ensuite sur `srv-int` ou `web` (test T11) : l'alias `H_depots` contient des **noms** (`archive.ubuntu.com`, `security.ubuntu.com`, `repo.zabbix.com`), que pfSense résout périodiquement. Vérifiez dans *Diagnostics → Tables* que `H_depots` contient des adresses, et que les sources `apt` de la machine (`grep -rh ^URIs /etc/apt/sources.list.d/`) utilisent bien ces noms : si elles pointent vers un autre miroir, ajoutez ce nom à l'alias.

**Points de vigilance.** pfSense évalue les règles **par interface**, sur le trafic **entrant** dans cette interface, première correspondance gagnante, avec un refus implicite final (non journalisé par défaut → d'où la règle de blocage explicite journalisée). Une règle pour le flux LAN → DMZ s'écrit donc sur l'interface **LAN**.

**Étape 1.** Les règles « HRA : tout autoriser » sur le **WAN** signifient que toute machine d'Internet (ici `ext`) joint tout ce que pfSense route : pfSense lui-même, et les réseaux internes. C'est le constat de départ : un pare-feu livré grand ouvert ne filtre rien.

La matrice complète est celle des étapes 5 à 9 de l'énoncé (L1 à L10, S1 à S5, D1 à D4, W1). Points à faire justifier par les apprenants :

- **Ordre** : les services de pfSense (L1 à L3), puis l'administration (L4 à L6), puis les flux utilisateurs (L7 à L9), et le blocage journalisé en dernier. Entre règles « Pass », l'ordre ne change pas le résultat ; il compte dès qu'une règle « Block » s'intercale.
- **« LAN address » plutôt que « This Firewall (self) »** : *self* désigne **toutes** les adresses de pfSense, WAN comprise.
- **DNS en TCP/UDP** : en TCP seul, la plupart des requêtes (UDP) sont refusées dès que le blocage final est en place.
- **L5, le scanner** : volontairement large, et désactivée hors des campagnes de scan (TP 2, TP 8) — un scanner est un outil d'attaque.
- **L9, `! N_PRIVE`** : la navigation Internet est ouverte à tout le LAN, mais pas les réseaux internes ; les droits internes du poste d'administration passent par des règles nominatives.
- **S3 et D3** : seules sorties de SRV et DMZ, vers les dépôts. Le flux syslog web → srv-int du TP 7 viendra s'insérer avant D4 : c'est le « flux justifié » de la DMZ.

**Étapes 3 à 8.** Erreurs classiques :
- garder les règles HRA en plus des nouvelles : en tête de liste, elles masquent tout ;
- oublier DNS et NTP vers pfSense : les machines ne résolvent plus rien, `apt` échoue, l'horloge dérive ;
- oublier les règles IPv6 HRA : un réseau « fermé » en IPv4 reste ouvert en IPv6 ;
- placer la règle de blocage avant les règles passantes ;
- mettre le DNS en TCP seul ;
- oublier d'appliquer : les règles ne prennent effet qu'après **Apply Changes** ;
- oublier la DMZ dans les droits d'administration de la Kali (plus de SSH vers web).

L'alias de noms pour les dépôts (`archive.ubuntu.com`…) est résolu périodiquement par pfSense ; si `apt update` échoue sur une adresse, c'est qu'elle a changé depuis la dernière résolution. En production, on passe plutôt par un miroir ou un proxy interne.

Admin access : montrer depuis `web` que `https://10.1.30.1` ne répond pas, et depuis l'adresse 10.1.10.20 que `https://10.1.10.1` ne répond plus. Point d'architecture : le poste d'administration est ici dans le LAN utilisateurs, faute de zone d'administration dédiée ; on compense par des règles nominatives (`H_poste_admin`) — un auditeur le relèvera au TP 8.

**Pour le formateur.** La suppression des règles HRA du WAN ne gêne pas la console du portail Hexceos (accès à l'écran de la VM, pas par le réseau). Si la plateforme utilisait un accès réseau à pfSense pour sa supervision, il faudrait le savoir avant le TP : à tester sur un environnement.

**Étape 9.** Le port forward (NAT) et la règle de filtrage sont deux choses distinctes : insister. La sécurité vient de la règle (443 uniquement, destination = alias du serveur), pas du NAT. En IPv6, pas de NAT : seule la règle compte.

**« À méditer ».** Avec la règle associée par défaut, `ext` joint `10.1.30.10:443` directement : pfSense filtre après traduction, donc la règle autorise « vers 10.1.30.10:443 », quelle que soit l'adresse visée au départ. `ext` peut le faire parce qu'il a une route vers 10.1.0.0/16 par pfSense (comme le ferait un voisin de segment). Avec *Filter rule association* = **Pass**, pfSense laisse passer ce qui a été traduit par la règle NAT, sans règle de filtrage : le trafic direct vers l'adresse privée tombe sur le refus par défaut. Contrepartie : plus de règle de filtrage, donc plus de compteurs ni de journalisation propre à ce flux.

**Étapes 11 et 12.** Les tests doivent tous passer comme « attendu ». Si DMZ → SRV est autorisé par erreur, c'est le constat pédagogique majeur : une segmentation annoncée mais non filtrée ne vaut rien. Les journaux du pare-feu montrent les refus → lien avec la journalisation (module 7). L'adresse 10.1.10.20 ajoutée à la Kali simule un poste utilisateur : pfSense ne connaît que l'adresse source, il applique donc les règles « utilisateur ».

**Questions.** 1 : pour détecter les tentatives et disposer de preuves ; un refus silencieux ne laisse aucune trace. 2 : la règle de filtrage associée (port et destination restreints) et le durcissement du service lui-même ; le NAT ne filtre pas. 3 : refuser : `any:any` supprime tout le cloisonnement sortant (canal de C2 et d'exfiltration ouvert), empêche la détection et contrevient au moindre privilège ; proposer des règles précises par besoin.

---

[← TP2](../../tp2/README.md) · [Sommaire](../../README.md) · [Énoncé](../README.md) · [En cas de blocage](../../en-cas-de-blocage.md) · [TP4 →](../../tp4/README.md)
