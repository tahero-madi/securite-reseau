# Corrigé du TP6

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

**Préparation.** Rien à installer : `cloud-gw` porte strongSwan (`swanctl`, service `strongswan`) et une interface virtuelle `vpc0` (10.101.1.1/24) qui joue le VPC ; nginx y publie le service HTTPS sur 10.101.1.1. pfSense (10.10.0.20) et `cloud-gw` (10.10.0.30) sont sur le même segment « Internet », sans traduction d'adresses entre eux : pas de NAT-T, l'ESP circule en protocole IP 50. À vérifier une fois sur la plateforme : l'ESP passe bien sur le WAN (voir `hexceos/README.md`). Si Suricata est resté en mode blocage après le TP5, une alerte sur `cloud-gw` peut le bloquer : vérifier *Services → Suricata → Blocks*.

## Étape 1 — Clé partagée

44 caractères Base64 (264 bits d'aléa). Source d'erreur n° 1 de tout le TP : une clé différente des deux côtés (espace en trop au copier-coller, clé retapée à la main).

## Étapes 2 et 3 — Phases 1 et 2

| | pfSense | strongSwan |
|---|---|---|
| Phase 1 | IKEv2, AES256-GCM 128 bits, SHA256, DH 19, 86400 s | `proposals = aes256gcm16-sha256-ecp256` |
| Identités | *My IP address* / *Peer IP address* | `id = 10.10.0.30` / `id = 10.10.0.20` |
| Phase 2 | ESP, AES256-GCM 128 bits, PFS 19, 3600 s | `esp_proposals = aes256gcm16-ecp256` |
| Sélecteurs | local `10.1.20.0/24`, distant `10.101.1.0/24` | `local_ts = 10.101.1.0/24`, `remote_ts = 10.1.20.0/24` |

Les durées de vie n'ont pas à être identiques : chaque côté renégocie à l'échéance la plus proche. `pfctl -sr | grep 10.10.0.30` montre les règles automatiques (UDP 500, 4500 et ESP) : aucune règle n'est à créer sur le WAN. Elles peuvent être désactivées dans *System → Advanced → Firewall & NAT* (*Disable all auto-added VPN rules*), auquel cas il faut les écrire à la main.

## Étapes 4 et 5 — Filtrage côté site

| N° | Interface | Action | Source | Destination | Port | Rôle |
|---|---|---|---|---|---|---|
| S6 | SRV | Pass | `H_srv_int` | `H_vpc_app` (10.101.1.1) | `P_cloud` (443, 22) | Qui peut **utiliser** le tunnel, au-dessus de S5 |
| I1 | IPsec | Block + log | 10.101.1.0/24 | any | any | Le cloud ne peut pas **ouvrir** de connexion vers le site |

Points à faire verbaliser :

- sans S6, la requête de `srv-int` est refusée par S5 avant même d'être chiffrée : le tunnel est établi mais aucun trafic ne passe ; le refus apparaît dans les journaux sur l'interface SRV ;
- pfSense filtre à l'**entrée** de chaque interface. Les réponses du cloud arrivent par `enc0` (onglet IPsec) mais appartiennent à une connexion acceptée par S6 : la table d'états les laisse passer, l'onglet IPsec n'intervient pas. Une règle `Pass 10.1.20.10 → 10.101.1.1` sur l'onglet IPsec n'aurait aucun effet : ce trafic n'entre jamais dans pfSense par `enc0` ;
- sans I1, le résultat est le même (refus implicite), mais rien n'est journalisé.

## Étapes 6 et 7 — strongSwan

Sortie attendue de `swanctl --list-sas` (extrait) :

```text
site: #1, ESTABLISHED, IKEv2, …
  local  '10.10.0.30' @ 10.10.0.30[500]
  remote '10.10.0.20' @ 10.10.0.20[500]
  AES_GCM_16-256/PRF_HMAC_SHA2_256/ECP_256
  net: #1, reqid 1, INSTALLED, TUNNEL, ESP:AES_GCM_16-256/ECP_256
    local  10.101.1.0/24
    remote 10.1.20.0/24
```

Erreurs classiques et message correspondant dans *Status → System Logs → IPsec* :

| Symptôme | Cause |
|---|---|
| `NO_PROPOSAL_CHOSEN` | Algorithmes différents (souvent : AES256-GCM laissé en *Auto* ou autres algorithmes cochés en phase 2 ; groupe PFS oublié d'un côté) |
| `AUTHENTICATION_FAILED` | Clé différente, ou identités (*My/Peer identifier*) qui ne correspondent pas aux `id` |
| `TS_UNACCEPTABLE` | Sélecteurs non inversés, ou masque différent |
| `connecting to 'unix:///var/run/charon.vici' failed` | Service `strongswan` arrêté |
| Négociation qui n'aboutit jamais | Suricata a bloqué `cloud-gw` (*Services → Suricata → Blocks*) |

## Étape 8 — Tests

| Test | Attendu | Règle |
|---|---|---|
| `srv-int` → `https://10.101.1.1` | Page « Application cloud » | S6, puis tunnel |
| `srv-int` → SSH 10.101.1.1 | `cloud-gw` | S6, puis tunnel |
| Kali → `https://10.101.1.1` | Délai dépassé | L10 (10.101.1.1 est dans `N_PRIVE`) ; et hors sélecteurs |
| `cloud-gw` (source 10.101.1.1) → `srv-int:22` | Délai dépassé, refus journalisé sur `enc0` | I1 |

`-s 10.101.1.1` garantit que la source correspond aux sélecteurs, qui portent sur les adresses **source et destination**. strongSwan installe d'ailleurs une route vers 10.1.20.0/24 avec 10.101.1.1 comme adresse source préférée (`ip route show table 220` sur `cloud-gw`).

## Étape 9 — Preuve du chiffrement

Avec le filtre `esp`, seuls 10.10.0.20 ↔ 10.10.0.30 et le SPI apparaissent ; les adresses internes, les ports et la charge HTTPS sont invisibles. Le filtre `tcp.port == 22` montre au contraire la session SSH de la Kali en clair au niveau IP et TCP (adresses, ports, tailles), avec un contenu chiffré par SSH. Si aucun paquet ESP n'apparaît : le `curl` a été lancé hors de la capture, ou la capture a été prise sur la mauvaise carte.

## Étape 10 — Transposition

| Élément du TP | Équivalent AWS | Équivalent Azure |
|---|---|---|
| Tunnel IPsec pfSense ↔ `cloud-gw` | Site-to-Site VPN : *Customer Gateway* + *Virtual Private Gateway* ou *Transit Gateway* | *VPN Gateway* + *Local Network Gateway* + connexion IPsec |
| VPC 10.101.1.0/24 | VPC et sous-réseau | VNet et sous-réseau |
| Règle S6 (qui utilise le tunnel) | Table de routage du sous-réseau vers la passerelle VPN, et *Security Group* des instances (source = plage du site) | Routes propagées par la *VPN Gateway*, et NSG (source = plage du site) |
| Règle I1 (le cloud n'ouvre pas vers le site) | Règles **sortantes** du *Security Group* (par défaut tout est autorisé en sortie : à restreindre), ou *Network ACL* | Règles sortantes du NSG (par défaut `AllowVnetOutBound` autorise tout vers le VNet et les réseaux reliés) ; filtrage côté site, comme ici |
| Filtrage de l'instance cloud (HTTPS depuis le site, SSH depuis `srv-int`, refus par défaut) | *Security Group* : refus par défaut en entrée, règle 443 depuis la plage du site, 22 depuis une seule adresse (mieux : Session Manager, aucun port ouvert) | NSG : `DenyAllInBound` par défaut, **mais** `AllowVnetInBound` le précède : tout le VNet et les réseaux reliés par VPN sont autorisés si on ne le restreint pas ; 22 via Azure Bastion |
| Journal des refus | VPC Flow Logs | VNet Flow Logs (les NSG Flow Logs sont en fin de vie) |
| Console du portail | EC2 Serial Console | Serial Console des VM |

Vérifier que les apprenants ne confondent pas *Security Group* (à états, attaché à l'instance) et *Network ACL* (sans état, attachée au sous-réseau, il faut alors autoriser explicitement les ports de retour).

## Défi

`auth = pubkey` côté strongSwan, *Mutual Certificate* côté pfSense, certificats émis par une AC commune, identités = nom du certificat. Les certificats : pas de secret partagé à transmettre et à stocker des deux côtés ; un secret par passerelle, révocable individuellement ; pas d'attaque hors ligne sur une PSK faible ; passage à l'échelle (N sites = N certificats, au lieu d'une clé par paire de sites).

## Questions

1. IKEv2 ; AES-256-GCM ; SHA-256 comme PRF ; groupe DH 19 (P-256) en phase 1 et en PFS ; durées de vie limitées (24 h, 1 h) ; authentification forte (PSK longue et aléatoire, certificats en production) ; sélecteurs restreints.
2. ESP chiffre le paquet IP d'origine en entier (adresses internes, ports, données) et l'encapsule dans un nouveau paquet entre les passerelles : sur le segment intermédiaire, on ne voit que l'enveloppe.
3. Le filtrage est à états : les réponses appartiennent à une connexion ouverte par `srv-int` et acceptée par S6. L'onglet IPsec ne juge que les connexions **ouvertes** depuis le cloud.
4. Une référence à un groupe suit automatiquement l'ajout et le retrait d'instances, sans réécrire les règles, et exprime une intention (« les serveurs web peuvent joindre la base ») plutôt qu'une liste d'adresses figée qui se périme.

---

[← TP5](../../tp5/README.md) · [Sommaire](../../README.md) · [Énoncé](../README.md) · [En cas de blocage](../../en-cas-de-blocage.md) · [TP7 →](../../tp7/README.md)
