# TP6 — Interconnexion hybride : VPN IPsec

**Jour 4, 09:00 · démonstration du formateur (30 min).** L'énoncé complet reste disponible pour refaire le TP après la formation (1 h 45). Objectifs : monter un tunnel IPsec IKEv2 conforme aux recommandations de l'ANSSI entre pfSense (le site) et `cloud-gw` (la passerelle du « cloud ») ; filtrer ce qui entre dans le tunnel et ce qui en sort ; prouver le chiffrement ; transposer la configuration vers AWS et Azure.

**Prérequis** : modules 5 et 6, TP3 terminé (règles L4 et L8 : la Kali joint `srv-int` et `cloud-gw` en SSH). **Livrable** : état du tunnel, capture prouvant le chiffrement, tableau de transposition, dans `~/livrables`.

**Déroulé** : étapes 1 à 5 (pfSense) 35 min · étapes 6 à 8 (strongSwan et tests) 30 min · étape 9 (preuve du chiffrement) 15 min · étape 10 (transposition) 15 min.

> **Instantané conseillé.** Avant de commencer, prenez un instantané de pfSense et de `cloud-gw` depuis le portail (par exemple `avant-tp6`).

## Contexte

On relie le réseau des serveurs du site à un « cloud » privé, à travers « Internet » :

| Rôle | Machine | Adresse |
|---|---|---|
| Passerelle VPN du site | pfSense, carte WAN | `10.10.0.20` |
| Réseau du site à relier | SRV | `10.1.20.0/24` (`srv-int` : `10.1.20.10`) |
| Passerelle VPN du cloud | `cloud-gw`, carte « Internet » | `10.10.0.30` |
| Réseau du cloud (« VPC ») | `cloud-gw`, interface virtuelle `vpc0` | `10.101.1.0/24` |
| Service applicatif du cloud | `cloud-gw` | `10.101.1.1`, ports 443 (HTTPS) et 22 (SSH) |

Objectif : `srv-int` et le service cloud communiquent **uniquement** à travers un tunnel chiffré ; le cloud ne peut pas ouvrir de connexion vers le site.

## Étape 1 — Générer la clé partagée

**Pourquoi.** Les deux passerelles doivent se reconnaître avant d'échanger des clés de chiffrement. Dans ce TP, elles le font avec une clé partagée (PSK, *Pre-Shared Key*). Une PSK courte ou devinable se casse hors ligne à partir d'une simple capture de la négociation : elle doit être longue et aléatoire. En production, on préfère des certificats (voir le défi).

Depuis la Kali, connectez-vous à `cloud-gw` et générez la clé :

```bash
ssh formation@10.10.0.30
openssl rand -base64 33 > ~/psk.txt
chmod 600 ~/psk.txt
cat ~/psk.txt
```

**Ligne par ligne.**

- `ssh formation@10.10.0.30` : ouvre une session sur `cloud-gw` (règle L8). Les commandes suivantes s'exécutent sur `cloud-gw`.
- `openssl rand -base64 33` : tire 33 octets au hasard (264 bits) et les écrit en Base64, soit 44 caractères imprimables.
- `> ~/psk.txt` : range la clé dans un fichier, pour la réutiliser à l'étape 6.
- `chmod 600 ~/psk.txt` : seul votre compte peut lire ce fichier.
- `cat ~/psk.txt` : l'affiche, pour la copier dans pfSense.

Gardez cette session ouverte.

## Étape 2 — Phase 1 sur pfSense (IKE)

**Pourquoi.** La phase 1 (IKE SA) authentifie les deux passerelles et établit un canal chiffré qui servira à négocier le tunnel lui-même. Ses paramètres traduisent les recommandations de l'ANSSI : IKEv2, chiffrement authentifié AES-GCM, SHA-2, échange Diffie-Hellman sur courbe elliptique.

*VPN → IPsec → Tunnels → Add P1* :

| Section | Champ | Valeur |
|---|---|---|
| *General Information* | *Description* | `cloud` |
| | *Key Exchange version* | `IKEv2` |
| | *Internet Protocol* | `IPv4` |
| | *Interface* | `WAN` |
| | *Remote Gateway* | `10.10.0.30` |
| *Phase 1 Proposal (Authentication)* | *Authentication Method* | `Mutual PSK` |
| | *My identifier* | `My IP address` |
| | *Peer identifier* | `Peer IP address` |
| | *Pre-Shared Key* | la clé affichée à l'étape 1 |
| *Phase 1 Proposal (Encryption Algorithm)* | *Algorithm* | `AES256-GCM`, `128 bits` |
| | *Hash* | `SHA256` |
| | *DH Group* | `19 (nist ecp256)` |
| *Expiration and Replacement* | *Life Time* | `86400` |

Supprimez les autres lignes de proposition s'il y en a. *Save*, puis *Apply Changes*.

**Ligne par ligne.**

- *IKEv2* : la version actuelle du protocole d'échange de clés ; IKEv1 est obsolète.
- *Remote Gateway* `10.10.0.30` : l'adresse « Internet » de `cloud-gw`.
- *Mutual PSK* : les deux côtés prouvent qu'ils connaissent la même clé.
- *My identifier* / *Peer identifier* : chaque passerelle se présente par son adresse IP (10.10.0.20 et 10.10.0.30) ; `cloud-gw` attendra exactement ces identités.
- *AES256-GCM*, *128 bits* : chiffrement AES avec une clé de 256 bits, en mode GCM, qui chiffre et protège l'intégrité en une seule opération ; `128 bits` est la taille du code d'intégrité (ICV), et non celle de la clé.
- *SHA256* : avec GCM, sert de fonction pseudo-aléatoire (PRF) pour dériver les clés.
- *DH Group 19* : échange Diffie-Hellman sur la courbe elliptique P-256.
- *Life Time* `86400` : la phase 1 est renégociée au plus tard toutes les 24 heures.

En créant cette phase 1, pfSense ajoute de lui-même des règles **cachées** qui autorisent IKE (UDP 500 et 4500) et ESP entre 10.10.0.20 et 10.10.0.30 : inutile d'en créer sur le WAN. Vérifiez-le dans *Diagnostics → Command Prompt*, champ *Execute Shell Command* :

```bash
pfctl -sr | grep 10.10.0.30
```

**Ligne par ligne.**

- `pfctl -sr` : affiche toutes les règles chargées dans le filtre de pfSense, y compris celles qui ne figurent pas dans *Firewall → Rules*.
- `| grep 10.10.0.30` : ne garde que les lignes qui mentionnent `cloud-gw`. Vous devez voir des règles `pass` pour `proto udp` (ports 500 et 4500, parfois affichés `isakmp` et `ipsec-nat-t`) et pour `proto esp`.

## Étape 3 — Phase 2 sur pfSense (le tunnel)

**Pourquoi.** La phase 2 (*Child SA*) définit **quel trafic** entre dans le tunnel (les sélecteurs) et comment il est chiffré (ESP). Les sélecteurs doivent être aussi étroits que possible : seulement le réseau SRV du site et le VPC, jamais `0.0.0.0/0`.

Sur la ligne `cloud`, cliquez sur *Show Phase 2 Entries*, puis *Add P2* :

| Champ | Valeur |
|---|---|
| *Description* | `srv-vers-vpc` |
| *Mode* | `Tunnel IPv4` |
| *Local Network* | `Network`, `10.1.20.0` / `24` |
| *NAT/BINAT translation* | `None` |
| *Remote Network* | `Network`, `10.101.1.0` / `24` |
| *Protocol* | `ESP` |
| *Encryption Algorithms* | seulement `AES256-GCM`, `128 bits` |
| *Hash Algorithms* | tout décocher |
| *PFS key group* | `19 (nist ecp256)` |
| *Life Time* | `3600` |

*Save*, puis *Apply Changes*.

**Ligne par ligne.**

- *Mode* `Tunnel IPv4` : le paquet d'origine est entièrement chiffré et encapsulé dans un nouveau paquet entre les deux passerelles.
- *Local Network* `10.1.20.0/24` : côté site, seul le réseau SRV est concerné. Le LAN, donc la Kali, reste hors du tunnel.
- *Remote Network* `10.101.1.0/24` : côté cloud, le VPC.
- *ESP* : le protocole qui chiffre les données (protocole IP 50).
- *AES256-GCM* seul : la même suite qu'en phase 1 ; les autres algorithmes proposés par défaut sont retirés.
- *Hash Algorithms* décochés : GCM assure déjà l'intégrité.
- *PFS key group 19* : chaque renouvellement des clés du tunnel refait un échange Diffie-Hellman. Si une clé est un jour compromise, elle ne permet pas de déchiffrer le trafic des autres périodes (*Perfect Forward Secrecy*).
- *Life Time* `3600` : les clés du tunnel changent toutes les heures.

## Étape 4 — Autoriser `srv-int` vers le cloud (interface SRV)

**Pourquoi.** pfSense filtre chaque paquet à son **entrée** sur une interface. Une requête de `srv-int` vers `10.101.1.1` entre par l'interface SRV **avant** d'être chiffrée : sans règle sur SRV, elle est refusée par S5 et n'atteint jamais le tunnel. IPsec chiffre, mais ne filtre pas : c'est au pare-feu de dire qui a le droit d'utiliser le tunnel, et pour quoi.

*Firewall → Aliases → IP → Add* : `H_vpc_app`, type `Host(s)`, contenu `10.101.1.1`, description « Service applicatif du cloud ». *Save*.

*Firewall → Aliases → Ports → Add* : `P_cloud`, contenu `443` et `22`, description « Accès au service cloud ». *Save*, puis *Apply Changes*.

*Firewall → Rules → SRV* (affiché parfois `OPT1`), *Add* (flèche vers le haut, pour l'insérer en tête) :

| Champ | Valeur |
|---|---|
| *Action* | `Pass` |
| *Interface* | `SRV` |
| *Protocol* | `TCP` |
| *Source* | `Address or Alias` : `H_srv_int` |
| *Destination* | `Address or Alias` : `H_vpc_app` |
| *Destination Port Range* | `P_cloud` |
| *Description* | `S6 srv-int vers le service cloud (tunnel IPsec)` |

*Save*. Vérifiez que S6 est **au-dessus** de S5, puis *Apply Changes*.

**Ligne par ligne.**

- `H_vpc_app` et `P_cloud` : les alias rendent la règle lisible et réutilisable, comme au TP3.
- *Source* `H_srv_int` : seul `srv-int`, pas tout le réseau SRV.
- *Destination* `H_vpc_app`, ports `P_cloud` : seulement le service cloud, en HTTPS et SSH.
- Position au-dessus de S5 : première règle qui correspond, première appliquée ; sous S5, elle ne serait jamais atteinte.

Ajoutez la ligne S6 à votre matrice de flux du TP3.

## Étape 5 — Interdire au cloud d'ouvrir des connexions vers le site (onglet IPsec)

**Pourquoi.** Le trafic qui **sort** du tunnel chez pfSense est filtré par l'onglet *Firewall → Rules → IPsec*. Les réponses du service cloud à `srv-int` y sont autorisées automatiquement : elles appartiennent à des connexions ouvertes par `srv-int` et acceptées à l'étape 4 (filtrage à états). Cet onglet ne concerne donc que les connexions **ouvertes depuis le cloud**. Il est vide par défaut, et tout ce qui n'est pas autorisé est refusé ; mais un refus implicite n'est pas journalisé. On écrit le refus explicitement, avec journalisation : si une machine du cloud est un jour compromise et tente de rebondir vers le site, on le verra.

*Firewall → Rules → IPsec → Add* :

| Champ | Valeur |
|---|---|
| *Action* | `Block` |
| *Interface* | `IPsec` |
| *Address Family* | `IPv4` |
| *Protocol* | `Any` |
| *Source* | `Network` : `10.101.1.0` / `24` |
| *Destination* | `Any` |
| *Log* | coché |
| *Description* | `I1 Refus des connexions ouvertes depuis le cloud` |

*Save*, puis *Apply Changes*.

**Ligne par ligne.**

- *Block* : refuse silencieusement (pas de réponse à l'émetteur).
- *Source* `10.101.1.0/24` : tout ce qui vient du VPC par le tunnel.
- *Log* : chaque refus apparaît dans *Status → System Logs → Firewall*.

Si un besoin réel apparaît un jour (le cloud doit interroger un service du site), on ajoutera une règle `Pass` précise **au-dessus** de I1.

## Étape 6 — Configurer strongSwan sur `cloud-gw`

**Pourquoi.** L'autre extrémité doit être le miroir exact de pfSense : mêmes identités, même clé, mêmes algorithmes, sélecteurs inversés (ce qui est « local » pour l'un est « distant » pour l'autre). La moindre différence fait échouer la négociation.

Dans la session SSH sur `cloud-gw` :

```bash
sudo tee /etc/swanctl/swanctl.conf > /dev/null <<EOF
connections {
  site {
    version = 2
    local_addrs = 10.10.0.30
    remote_addrs = 10.10.0.20
    proposals = aes256gcm16-sha256-ecp256
    local {
      auth = psk
      id = 10.10.0.30
    }
    remote {
      auth = psk
      id = 10.10.0.20
    }
    children {
      net {
        local_ts = 10.101.1.0/24
        remote_ts = 10.1.20.0/24
        esp_proposals = aes256gcm16-ecp256
        start_action = trap
      }
    }
  }
}
secrets {
  ike-site {
    id = 10.10.0.20
    secret = "$(cat ~/psk.txt)"
  }
}
EOF
sudo chmod 600 /etc/swanctl/swanctl.conf
sudo grep secret /etc/swanctl/swanctl.conf
sudo swanctl --load-all
```

**Ligne par ligne.**

- `sudo tee /etc/swanctl/swanctl.conf > /dev/null <<EOF` … `EOF` : écrit tout le texte qui suit dans le fichier de configuration de strongSwan. `EOF` n'est pas entre apostrophes : le terminal remplace `$(cat ~/psk.txt)` par le contenu du fichier, donc par la clé.
- `connections { site { … } }` : une connexion nommée `site`.
- `version = 2` : IKEv2.
- `local_addrs` / `remote_addrs` : l'adresse de `cloud-gw` et celle de pfSense sur « Internet ».
- `proposals = aes256gcm16-sha256-ecp256` : la phase 1 : AES-256-GCM avec code d'intégrité de 16 octets (128 bits), SHA-256 comme fonction pseudo-aléatoire, groupe DH 19 (`ecp256`). C'est la traduction exacte des choix de l'étape 2.
- bloc `local` (`auth = psk`, `id = 10.10.0.30`) : `cloud-gw` s'authentifie par la clé partagée et se présente sous son adresse.
- bloc `remote` (`auth = psk`, `id = 10.10.0.20`) : il attend pfSense, sous son adresse.
- `children { net { … } }` : le tunnel (phase 2), nommé `net`.
- `local_ts = 10.101.1.0/24`, `remote_ts = 10.1.20.0/24` : les sélecteurs, inversés par rapport à pfSense.
- `esp_proposals = aes256gcm16-ecp256` : chiffrement du tunnel et groupe DH pour la PFS, comme à l'étape 3.
- `start_action = trap` : le tunnel s'établit automatiquement dès qu'un paquet correspond aux sélecteurs.
- bloc `secrets`, entrée `ike-site` (`id = 10.10.0.20`, `secret = "…"`) : la clé partagée à utiliser avec pfSense.
- `sudo chmod 600 /etc/swanctl/swanctl.conf` : le fichier contient la clé ; seul `root` doit pouvoir le lire.
- `sudo grep secret /etc/swanctl/swanctl.conf` : vérifie que la clé a bien été recopiée. La ligne doit contenir les 44 caractères affichés à l'étape 1. Si elle affiche `secret = ""`, le fichier `~/psk.txt` n'existait pas au moment du `tee` : voir l'encadré « AUTHENTICATION_FAILED » de l'étape 7.
- `sudo swanctl --load-all` : demande au service strongSwan de charger la connexion et la clé. La sortie doit contenir `loaded ike secret 'ike-site'` et `successfully loaded 1 connections`.

> **Si `--load-all` échoue** avec `connecting to 'unix:///var/run/charon.vici' failed` : le service n'est pas démarré, `sudo systemctl restart strongswan`, puis recommencez.

## Étape 7 — Monter le tunnel et le vérifier

**Pourquoi.** On déclenche la négociation et on lit l'état obtenu : c'est la preuve que les deux extrémités se sont mises d'accord, et sur quels algorithmes.

Toujours sur `cloud-gw` :

```bash
sudo swanctl --initiate --child net
sudo swanctl --list-sas
sudo swanctl --list-sas > ~/tp6-sas.txt
rm ~/psk.txt
```

**Ligne par ligne.**

- `sudo swanctl --initiate --child net` : lance la négociation de la phase 1 puis du tunnel `net`. La dernière ligne doit être `initiate completed successfully`. Les lignes `plugin '…': failed to load` du début sont normales : la configuration par défaut cite des modules que le paquet d'Ubuntu ne fournit pas ; elles n'ont aucun effet.
- `sudo swanctl --list-sas` : affiche les associations de sécurité. Vérifiez :
  - `site: #1, ESTABLISHED, IKEv2` : la phase 1 est établie ;
  - `AES_GCM_16-256/PRF_HMAC_SHA2_256/ECP_256` : les algorithmes de phase 1 retenus ;
  - `net: #1, reqid 1, INSTALLED, TUNNEL, ESP:AES_GCM_16-256/ECP_256` : le tunnel est en place, avec PFS ;
  - `local 10.101.1.0/24` et `remote 10.1.20.0/24` : les sélecteurs.
- `> ~/tp6-sas.txt` : la même sortie, enregistrée pour le livrable.
- `rm ~/psk.txt` : la clé est désormais dans `swanctl.conf` et dans pfSense ; on ne la laisse pas traîner ailleurs.

Dans pfSense, *Status → IPsec* : la ligne `cloud` est **Established** ; *Show child SA entries* montre le tunnel `10.1.20.0/24 ↔ 10.101.1.0/24`. Capturez l'écran.

> **Si la négociation échoue** : comparez les deux côtés, dans cet ordre. Clé identique ? Algorithmes identiques (AES256-GCM 128 bits, SHA256, groupe 19, des deux côtés et dans les deux phases) ? Identités (`My/Peer IP address` côté pfSense) ? Sélecteurs inversés ? Le journal de pfSense (*Status → System Logs → IPsec*) indique en général la cause : `NO_PROPOSAL_CHOSEN` (algorithmes), `AUTHENTICATION_FAILED` (clé ou identité), `TS_UNACCEPTABLE` (sélecteurs).

> **`received AUTHENTICATION_FAILED notify error`.** Si la sortie contient d'abord `selected proposal: IKE:AES_GCM_16_256/PRF_HMAC_SHA2_256/ECP_256`, les algorithmes sont bons : c'est pfSense qui refuse la **clé** de `cloud-gw` (son journal IPsec indique `MAC mismatched`), ou ne trouve pas de clé pour son identité (`no shared key found`). Cause la plus fréquente : la clé est vide dans `swanctl.conf` (étape 6 relancée après `rm ~/psk.txt`), ou la clé collée dans pfSense contient un espace en trop. Le plus simple : recopier la clé de pfSense (*VPN → IPsec → Tunnels*, crayon de la phase 1, champ *Pre-Shared Key*) dans `swanctl.conf`.
>
> ```bash
> read -rs PSK
> sudo sed -i "s|^\( *secret = \).*|\1\"$PSK\"|" /etc/swanctl/swanctl.conf
> sudo grep secret /etc/swanctl/swanctl.conf
> sudo swanctl --load-creds
> sudo swanctl --initiate --child net
> ```
>
> - `read -rs PSK` : attend que vous colliez la clé (puis `Entrée`) et la range dans la variable `PSK`, sans l'afficher (`-s`) ni interpréter les caractères spéciaux (`-r`).
> - `sudo sed -i "s|^\( *secret = \).*|…|"` : remplace, dans le fichier, la valeur de la ligne `secret = …` par la clé, entre guillemets. Le séparateur `|` évite les conflits avec les `/` que contient une clé Base64.
> - `sudo grep secret …` : vérifie le résultat.
> - `sudo swanctl --load-creds` : recharge seulement les clés.
> - `sudo swanctl --initiate --child net` : relance la négociation.

## Étape 8 — Tester les flux autorisés et interdits

**Pourquoi.** Un tunnel « établi » ne prouve pas que les bons flux passent, ni que les mauvais sont refusés. On teste les deux sens.

Depuis un **second terminal de la Kali**, connectez-vous à `srv-int` :

```bash
ssh formation@10.1.20.10
curl -k https://10.101.1.1
ssh formation@10.101.1.1 hostname
exit
curl -k -m 5 https://10.101.1.1
```

**Ligne par ligne.**

- `ssh formation@10.1.20.10` : session sur `srv-int` (règle L4).
- `curl -k https://10.101.1.1` : depuis `srv-int`, demande la page du service cloud. `-k` accepte son certificat autosigné. La page « Application cloud » doit s'afficher.
- `ssh formation@10.101.1.1 hostname` : se connecte en SSH au service cloud et y exécute `hostname` : la réponse est `cloud-gw`. À la première connexion, acceptez l'empreinte de la clé (`yes`), puis saisissez le mot de passe de `formation`.
- `exit` : ferme la session sur `srv-int` ; on revient sur la Kali.
- `curl -k -m 5 https://10.101.1.1` : la même requête, **depuis la Kali**. Elle doit échouer au bout de 5 secondes : la Kali est hors des sélecteurs du tunnel (le LAN n'en fait pas partie), et la règle L10 la refuse de toute façon.

Puis, dans la session sur **`cloud-gw`**, vérifiez que le cloud ne peut pas ouvrir de connexion vers le site :

```bash
nc -vz -w 3 -s 10.101.1.1 10.1.20.10 22
```

**Ligne par ligne.**

- `nc -vz` : `nc` (netcat) tente une connexion TCP, sans envoyer de données (`-z`), en affichant le résultat (`-v`).
- `-w 3` : abandonne au bout de 3 secondes.
- `-s 10.101.1.1` : utilise l'adresse du VPC comme source, pour que le paquet corresponde aux sélecteurs et passe dans le tunnel.
- `10.1.20.10 22` : le SSH de `srv-int`.

Résultat attendu : `timed out`. Dans pfSense, *Status → System Logs → Firewall* : un refus sur l'interface `IPsec` (`enc0`), de `10.101.1.1` vers `10.1.20.10:22`, par la règle I1.

## Étape 9 — Prouver le chiffrement

**Pourquoi.** Un tunnel « monté » ne suffit pas à un auditeur : il veut voir que ce qui circule sur Internet est illisible. On capture le trafic entre les deux passerelles pendant un échange applicatif.

Sur `cloud-gw`, repérez d'abord le nom de la carte qui porte `10.10.0.30`, puis lancez la capture :

```bash
ip -br a
sudo tcpdump -ni ens18 -w /tmp/tunnel.pcap host 10.10.0.20
```

**Ligne par ligne.**

- `ip -br a` : liste les cartes réseau et leurs adresses, une ligne par carte. Notez le nom de celle qui porte `10.10.0.30` (en général `ens18`) ; remplacez `ens18` dans la commande suivante s'il diffère.
- `sudo tcpdump` : capture les paquets.
- `-n` : n'essaie pas de traduire les adresses en noms.
- `-i ens18` : sur la carte « Internet ».
- `-w /tmp/tunnel.pcap` : enregistre les paquets dans un fichier, sans les afficher.
- `host 10.10.0.20` : seulement le trafic échangé avec pfSense.

Pendant la capture, dans la session sur `srv-int` (reconnectez-vous si besoin) :

```bash
curl -k https://10.101.1.1
```

Revenez sur `cloud-gw` et arrêtez la capture avec `Ctrl+C`. Puis, dans un terminal de la Kali :

```bash
scp formation@10.10.0.30:/tmp/tunnel.pcap ~/livrables/tp6-tunnel.pcap
scp formation@10.10.0.30:tp6-sas.txt ~/livrables/
wireshark ~/livrables/tp6-tunnel.pcap &
```

**Ligne par ligne.**

- `scp formation@10.10.0.30:/tmp/tunnel.pcap ~/livrables/tp6-tunnel.pcap` : rapatrie la capture sur la Kali.
- `scp formation@10.10.0.30:tp6-sas.txt ~/livrables/` : rapatrie aussi l'état du tunnel enregistré à l'étape 7.
- `wireshark … &` : l'ouvre dans Wireshark, en arrière-plan.

Dans Wireshark, appliquez successivement ces filtres d'affichage :

- `esp` : les paquets du tunnel. Seules les adresses des **passerelles** (10.10.0.20 ↔ 10.10.0.30) apparaissent ; les adresses internes (10.1.20.10, 10.101.1.1), les ports et le contenu HTTPS sont chiffrés.
- `isakmp` : la négociation IKE, s'il y en a eu pendant la capture (UDP 500).
- `tcp.port == 22` : votre propre session SSH de la Kali vers `cloud-gw`, qui ne passe **pas** par le tunnel (traduite par pfSense en 10.10.0.20). Ici, on lit les ports, le protocole et la taille des échanges : la comparaison montre ce que le tunnel cache.

> **Sélecteurs et filtrage.** Le tunnel ne protège que `10.1.20.0/24 ↔ 10.101.1.0/24`. Ne déclarez jamais `0.0.0.0/0` « pour que ça marche ». Et IPsec chiffre mais ne filtre pas : les règles S6 et I1 côté site restent indispensables, et, dans un vrai cloud, les groupes de sécurité côté cloud (module 6).

## Étape 10 — Transposer vers AWS et Azure

**Pourquoi.** Les mécanismes de ce TP sont ceux des clouds publics, sous d'autres noms. Savoir faire la correspondance permet de relire une architecture cloud, ou de l'auditer, avec les réflexes acquis sur un pare-feu classique.

Créez `~/livrables/tp6-transposition.md` et complétez ce tableau :

| Élément du TP | Équivalent AWS | Équivalent Azure |
|---|---|---|
| Tunnel IPsec pfSense ↔ `cloud-gw` | | |
| VPC 10.101.1.0/24 | | |
| Règle S6 : seul `srv-int` utilise le tunnel, en 443 et 22 | | |
| Règle I1 : le cloud n'ouvre pas de connexion vers le site | | |
| Filtrage de l'instance cloud elle-même (non réalisé ici) : HTTPS depuis le site, SSH depuis `srv-int` seulement, refus par défaut | | |
| Journal des refus (règle I1 journalisée) | | |
| Console de `cloud-gw` dans le portail | | |

> **Défi ★.** Remplacez l'authentification par clé partagée par des **certificats** : une AC du laboratoire signe un certificat pour chaque passerelle (*System → Cert. Manager* côté pfSense, `/etc/swanctl/x509*` côté `cloud-gw`, `auth = pubkey`). Pourquoi les certificats sont-ils préférés à une PSK dans un déploiement réel, en particulier quand le nombre de sites augmente ?

**Livrable** (dans `~/livrables`) :

- `tp6-sas.txt` et la capture d'écran de *Status → IPsec* ;
- `tp6-tunnel.pcap` : la capture prouvant le chiffrement ;
- `tp6-transposition.md`.

## Questions de validation

1. Quels paramètres des phases 1 et 2 traduisent les recommandations de l'ANSSI dans ce TP ?
2. Pourquoi ne voit-on que de l'ESP, entre les deux passerelles, dans la capture du segment « Internet » ?
3. Pourquoi la règle de l'onglet IPsec ne concerne-t-elle pas les réponses du service cloud à `srv-int` ?
4. En quoi une règle de groupe de sécurité qui référence un autre groupe est-elle supérieure à une règle par adresse IP ?

---

[← TP5](../tp5/README.md) · [Sommaire](../README.md) · [Corrigé](corrige/README.md) · [En cas de blocage](../en-cas-de-blocage.md) · [TP7 →](../tp7/README.md)
