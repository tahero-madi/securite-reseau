# TP6 — Interconnexion hybride : VPN IPsec et groupes de sécurité

**Jour 3, 13:40 · 2 h 10, pause incluse.** Objectifs : monter un tunnel IPsec IKEv2 conforme ANSSI entre `fw` (site) et `cloud-gw` (passerelle « cloud ») ; vérifier le chiffrement ; mettre en place des « groupes de sécurité » façon cloud avec nftables sur `cloud-gw` ; activer des journaux de flux ; transposer la configuration en logique AWS/Azure.

**Prérequis** : modules 5 et 6, TP 3. **Livrable** : tunnel monté (capture d'état), preuve que le trafic inter-site est chiffré (capture ESP), jeu de règles nftables commenté, tableau de transposition vers AWS Security Groups / Azure NSG.

## Contexte

On simule un site d'entreprise (votre LAN/SRV, derrière `fw`) relié à un « cloud » privé (`VPC` 10.101.1.0/24, derrière `cloud-gw`). Le lien passe par le réseau `203.0.113.0/24` qui joue Internet. Le service applicatif « cloud » est hébergé directement sur `cloud-gw`, sur son interface VPC `10.101.1.1` (SSH + web 443). Objectif : que `srv-int` (10.1.20.10) et le service « cloud » (`10.101.1.1`) communiquent **uniquement** à travers un tunnel chiffré, avec un filtrage de type groupe de sécurité côté cloud.

## Partie A — Tunnel IPsec IKEv2 côté pfSense (40 min)

1. Sur `fw` : *VPN → IPsec → Tunnels → Add P1* (phase 1, IKEv2) :
   - *Key Exchange* : **IKEv2** ; *Remote Gateway* : `203.0.113.21` (cloud-gw) ;
   - *Authentication* : Mutual PSK (pour ce TP ; en production, certificats) ; **PSK longue et aléatoire** ;
   - *Encryption* : **AES-256-GCM** ; *Hash/PRF* : **SHA-256** ; *DH Group* : **19 (ECP 256)** ;
   - *Lifetime* : 86400 s.
2. *Add P2* (phase 2, CHILD SA) :
   - *Mode* : Tunnel IPv4 ; *Local Network* : `10.1.20.0/24` ; *Remote Network* : `10.101.1.0/24` ;
   - *Protocol* : ESP ; *Encryption* : AES-256-GCM ; *PFS Group* : **19** ; *Lifetime* : 3600 s.
3. *Firewall → Rules → IPsec* : autorisez le flux attendu (`10.1.20.10 → 10.101.1.1` sur le port applicatif, par exemple 22 ou 443) et refusez le reste. Autorisez sur WAN les ports IKE : UDP 500 et 4500.

## Partie B — Côté passerelle cloud (strongSwan) (30 min)

4. Sur `cloud-gw` (`ssh stagiaire@203.0.113.21` depuis le poste, qui joint ce réseau « Internet » directement), configurez strongSwan en miroir. Fichier `/etc/swanctl/swanctl.conf` (extrait) :

```text
connections {
  site-to-cloud {
    version = 2
    local_addrs  = 203.0.113.21
    remote_addrs = 203.0.113.11
    proposals = aes256gcm16-sha256-ecp256
    local  { auth = psk ; id = 203.0.113.21 }
    remote { auth = psk ; id = 203.0.113.11 }
    children {
      net {
        local_ts  = 10.101.1.0/24
        remote_ts = 10.1.20.0/24
        esp_proposals = aes256gcm16-ecp256
        start_action = trap
      }
    }
  }
}
secrets {
  ike-site { secret = "<la meme PSK que pfSense>" }
}
```

5. Chargez et vérifiez :

```bash
sudo swanctl --load-all
sudo swanctl --initiate --child net
sudo swanctl --list-sas
```

6. Vérifiez l'état côté pfSense (*Status → IPsec*) : la SA doit être **ESTABLISHED**. Testez la connectivité applicative depuis `srv-int` : `curl -k https://10.101.1.1` et `ssh stagiaire@10.101.1.1`. Depuis le poste (10.1.10.10, hors sélecteurs du tunnel), le même accès doit échouer.

## Partie C — Prouver le chiffrement (15 min)

7. Sur le poste, ouvrez Wireshark sur `v-cloud-gw` (port miroir de la patte « Internet » de cloud-gw), filtre `host 203.0.113.11`. Générez du trafic applicatif site→cloud depuis `srv-int` (`curl -k https://10.101.1.1`), puis arrêtez la capture : vous ne devez voir que des paquets **ESP** (protocole 50) et la négociation ISAKMP, **aucun contenu applicatif en clair**. Comparez avec un flux non tunnelé.

> **Sélecteurs et filtrage.** Le tunnel ne protège que `10.1.20.0/24 ↔ 10.101.1.0/24`. Ne déclarez pas `0.0.0.0/0`. Et rappelez-vous : IPsec chiffre mais ne filtre pas — les règles (IPsec sur pfSense, nftables côté cloud) restent nécessaires.

## Partie D — Groupes de sécurité façon cloud (nftables) (20 min)

8. Sur `cloud-gw`, écrivez un jeu nftables qui imite des **Security Groups** : refus par défaut, et autorisations par « groupe » (ici, par sous-réseau/rôle). Le service « cloud » étant hébergé sur `cloud-gw` même, on filtre son trafic entrant dans la chaîne `input` (dans un vrai cloud, le même jeu de règles s'appliquerait au trafic atteignant les instances, via la chaîne `forward`). Exemple :

```text
table inet cloudsg {
  chain input {
    type filter hook input priority 0; policy drop;
    ct state established,related accept
    iif "lo" accept
    # trafic IPsec entrant depuis le pare-feu du site : IKE et ESP
    ip saddr 203.0.113.11 udp dport { 500, 4500 } accept
    ip saddr 203.0.113.11 ip protocol esp accept
    # SG "app" : accepte 443 depuis le site (via le tunnel)
    ip saddr 10.1.20.0/24 ip daddr 10.101.1.1 tcp dport 443 accept
    # SG "app" : accepte SSH uniquement depuis l'hôte d'admin du site
    ip saddr 10.1.20.10 ip daddr 10.101.1.1 tcp dport 22 accept
    # administration de la passerelle depuis la console du « fournisseur »
    ip saddr 203.0.113.254 tcp dport 22 accept
    # journalisation des refus (journal de flux, groupe NFLOG 0 -> ulogd)
    limit rate 10/minute log group 0 prefix "cloudsg-drop: "
  }
}
```

Chargez le jeu avec `sudo nft -f cloudsg.nft` puis vérifiez avec `sudo nft list ruleset`. Si vous vous êtes enfermé dehors, `lab shell cloud-gw` (sur le poste) joue le rôle de la console série du fournisseur cloud : `sudo nft flush ruleset`.

> **La règle ESP est indispensable.** Le filtrage voit d'abord le paquet chiffré (protocole 50), puis le paquet déchiffré. Sans `ip protocol esp accept`, les paquets sont refusés **avant** déchiffrement : la SA s'établit (IKE passe en UDP) mais aucun trafic applicatif ne traverse le tunnel.

9. Activez des **journaux de flux** simples : les refus journalisés ci-dessus, plus (option) la journalisation des connexions acceptées vers le service « cloud ». Générez du trafic autorisé et interdit, montrez les deux dans le journal de flux : `sudo tail -f /var/log/ulog/syslogemu.log` (pour journaliser aussi les acceptations, ajoutez `log group 0 prefix "cloudsg-ok: "` avant les `accept` du service).

## Partie E — Transposition AWS/Azure (15 min)

10. Remplissez le tableau de transposition de votre configuration vers les deux fournisseurs :

| Élément du TP | Équivalent AWS | Équivalent Azure |
|---|---|---|
| Tunnel IPsec site↔cloud-gw | Site-to-Site VPN + Virtual Private Gateway / Transit GW | VPN Gateway (connexion IPsec) |
| VPC 10.101.1.0/24 | VPC + subnet | VNet + subnet |
| Règle nftables « app accepte 443 depuis le site » | Security Group entrant 443 depuis la plage du site | NSG entrant 443, source = plage du site |
| Règle SSH depuis l'hôte d'admin | SG entrant 22 depuis l'IP d'admin (mieux : SSM) | NSG entrant 22 depuis l'IP d'admin (mieux : Bastion) |
| Journaux de refus/acceptation | VPC Flow Logs | VNet Flow Logs |
| Refus par défaut (policy drop) | Comportement par défaut du SG (tout refusé en entrée) | NSG + attention à AllowVnetInBound |

> **Défi ★.** Remplacez l'authentification PSK par des **certificats** (PKI de labo) côté pfSense et strongSwan. Discutez : pourquoi les certificats sont-ils préférés à une PSK pour un déploiement réel ?

**Livrable** : capture d'état des SA, capture ESP prouvant le chiffrement, `nftables.conf` commenté, tableau de transposition complété.

## Questions de validation

1. Quels paramètres de phase 1 traduisent les recommandations ANSSI dans ce TP ?
2. Pourquoi voit-on uniquement de l'ESP dans la capture du segment « Internet » ?
3. En quoi une règle de Security Group référençant un autre groupe est-elle supérieure à une règle par adresse IP ?

---

[← TP5](../tp5/README.md) · [Sommaire](../README.md) · [Corrigé](corrige/README.md) · [En cas de blocage](../en-cas-de-blocage.md) · [TP7 →](../tp7/README.md)
