# TP3 — Cloisonnement et filtrage avec pfSense

**Jour 2, 10:20 · 1 h 40.** Objectifs : mettre en œuvre un zonage LAN/SRV/DMZ sur pfSense ; traduire une matrice de flux en règles « refus par défaut » ; configurer le NAT de publication ; activer la journalisation ; vérifier le cloisonnement par des tests de flux.

**Prérequis** : module 3, TP 1. **Livrable** : une `matrice-flux` documentée + l'export de configuration des règles (capture ou XML) + un tableau de tests de flux (attendu/obtenu).

> **Avant de commencer**, prenez un instantané de **pfSense** depuis le portail, nommé `avant-tp3`.

## Partie A — État des lieux et matrice (15 min)

1. Sur pfSense (`https://10.1.10.1`), repérez les interfaces : WAN (10.10.0.20), LAN (10.1.10.1), SRV (10.1.20.1), DMZ (10.1.30.1). Dans *Firewall → Rules*, observez les règles existantes : sur **chaque** interface, y compris le WAN, deux règles « HRA : tout autoriser » (IPv4 et IPv6), posées par la plateforme. Qu'est-ce que cela signifie pour une machine d'Internet, comme `ext` ?
2. Rédigez votre `matrice-flux` cible. Exigences minimales :
   - **postes utilisateurs** du LAN → DMZ web (`web`) en 80/443 ; LAN → Internet via le pare-feu ;
   - **poste d'administration** (`10.1.10.10`, votre Kali) → SRV et DMZ en SSH, LDAP(S) ; et, parce qu'il héberge les outils, → SRV/DMZ pour le scanner (TP 2) et la supervision (agent Zabbix 10050) ;
   - poste d'administration → machines du WAN (`ext` 10.10.0.40, `cloud-gw` 10.10.0.30) en SSH : elles jouent des serveurs sur Internet que vous administrez ;
   - SRV → poste `10.1.10.10` en TCP 10051 (agents Zabbix actifs, TP 7) ;
   - chaque zone → pfSense pour le **DNS** (53, en TCP **et** UDP) et l'**heure** (NTP, UDP 123) : sans eux, plus rien ne fonctionne ;
   - le scanner Greenbone (sur la Kali) teste **tous** les ports de SRV et DMZ : prévoyez-lui une règle dédiée, que l'on désactivera hors des campagnes de scan ; et autorisez le ping (ICMP) depuis le poste d'administration, utile au diagnostic ;
   - DMZ → SRV **interdit** sauf un flux précis justifié (ou aucun) ;
   - SRV → Internet **interdit** sauf mises à jour ;
   - Internet (WAN) → DMZ web en 443 uniquement (publication) ;
   - tout le reste refusé et **journalisé**, IPv6 compris.

Votre LAN ne contient qu'un poste, la Kali. Pour tester les droits d'un **poste utilisateur**, on lui ajoutera une seconde adresse, `10.1.10.20`, au moment des tests (partie D).

## Partie B — Alias et règles (35 min)

3. Créez des **alias** (*Firewall → Aliases*) pour les hôtes et groupes de ports : `H_poste_admin` (10.1.10.10), `H_web`, `H_srv_int`, `N_LAN`, `N_SRV`, `N_DMZ`, `P_web` (80,443), `P_admin` (22,443,389,636), `N_PRIVE` (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, pour désigner « Internet » par `! N_PRIVE`). Les alias rendent les règles lisibles et maintenables.
4. Sur l'interface **LAN**, créez des règles précises conformes à la matrice (une règle par ligne de matrice), puis **supprimez** les deux règles « HRA : tout autoriser ». Terminez par une règle de **blocage journalisé** `N_LAN → any` (case *Log* cochée). Ordre : les règles passantes d'abord, le blocage final ensuite.
5. Sur l'interface **DMZ**, créez les règles : DNS et NTP vers pfSense ; `N_DMZ → N_SRV` refusé et journalisé ; `N_DMZ → any` vers Internet refusé sauf si justifié. La DMZ ne doit pas joindre le LAN. Supprimez les règles HRA.
6. Sur l'interface **SRV**, autorisez DNS et NTP vers pfSense, SRV → mises à jour (alias de noms `archive.ubuntu.com`, `security.ubuntu.com`, `repo.zabbix.com` en 80/443), SRV → poste 10051 ; refusez le reste et journalisez. Supprimez les règles HRA.
7. Sur l'interface **WAN**, supprimez les règles HRA : sans règle, pfSense refuse tout ce qui arrive d'Internet. La publication (partie C) ajoutera la seule exception.
8. **Protection de l'administration** : créez sur LAN une règle explicite `H_poste_admin → LAN address` en 443 et 22. Puis, dans *System → Advanced → Admin Access*, cochez *Disable webConfigurator anti-lockout rule*. Vérifiez que l'interface web n'est plus joignable depuis la DMZ ni depuis un poste utilisateur (partie D).

> **Ne vous enfermez pas dehors.** Avant de durcir l'accès d'administration, gardez une session ouverte et testez depuis un autre onglet. En cas de blocage : ouvrez la **console de pfSense** depuis le portail ; l'option 8 donne un shell, où `pfctl -d` désactive le filtrage le temps de corriger (`pfctl -e` le réactive). Sinon, restaurez l'instantané `avant-tp3` de pfSense.

## Partie C — NAT de publication (15 min)

9. Publiez `web` : *Firewall → NAT → Port Forward*, interface WAN, destination *WAN address*, port 443 → cible `10.1.30.10:443`. pfSense propose de créer la règle de filtrage associée : vérifiez qu'elle n'autorise **que** 443 depuis le WAN vers `H_web`.
10. Testez depuis **Internet**, c'est-à-dire depuis la machine `ext` (10.10.0.40) :

```bash
ssh formation@10.10.0.40
curl -kI https://10.10.0.20            # doit répondre : nginx de web
nc -vz -w3 10.10.0.20 22               # doit échouer
nc -vz -w3 10.10.0.20 80               # doit échouer
nc -vz -w3 10.1.30.10 443              # adresse privée de web : que constatez-vous ?
nc -vz -w3 10.1.30.10 22               # doit échouer
```

Remarque : la publication de 443 masque désormais l'interface web de pfSense côté WAN (le NAT passe avant), ce qui est souhaitable.

> **À méditer.** `ext` peut joindre `10.1.30.10:443` directement, sans passer par l'adresse publiée. Pourquoi ? Indice : pfSense filtre **après** la traduction d'adresse, et la règle associée au NAT désigne l'adresse interne de `web`. Sur le vrai Internet, une adresse privée n'est jamais routée jusqu'à vous ; mais un voisin du même segment WAN (l'hébergeur, le FAI) le peut. Dans *Firewall → NAT → Port Forward*, modifiez la publication : *Filter rule association* = **Pass**, puis supprimez la règle WAN associée. Refaites les deux tests vers 443.

## Partie D — Vérifier le cloisonnement (20 min)

11. Ajoutez à la Kali l'adresse d'un **poste utilisateur**, le temps des tests :

```bash
sudo ip addr add 10.1.10.20/24 dev eth0
```

Un test depuis cette adresse se fait avec `nc -s 10.1.10.20` ou `curl --interface 10.1.10.20`.

12. Construisez un tableau de tests (attendu/obtenu) et exécutez-les depuis les bonnes sources :

| Depuis | Vers | Port | Commande | Attendu |
|---|---|---|---|---|
| Kali (poste admin) | web (DMZ) | 443 | `nc -vz -w3 10.1.30.10 443` | Autorisé |
| Kali (poste admin) | srv-int (SRV) | 22 | `nc -vz -w3 10.1.20.10 22` | Autorisé |
| poste utilisateur (10.1.10.20) | srv-int (SRV) | 22 | `nc -vz -w3 -s 10.1.10.20 10.1.20.10 22` | Refusé |
| poste utilisateur (10.1.10.20) | pfSense | 443 | `curl -kI -m5 --interface 10.1.10.20 https://10.1.10.1` | Refusé |
| poste utilisateur (10.1.10.20) | web | 443 | `nc -vz -w3 -s 10.1.10.20 10.1.30.10 443` | Autorisé |
| web (DMZ) | srv-int (SRV) | 22 | sur web : `nc -vz -w3 10.1.20.10 22` | Refusé |
| web (DMZ) | Kali (LAN) | 22 | sur web : `nc -vz -w3 10.1.10.10 22` | Refusé |
| web (DMZ) | pfSense | 443 | sur web : `curl -kI -m5 https://10.1.30.1` | Refusé |
| srv-int (SRV) | Internet | 443 | sur srv-int : `curl -sI -m5 https://github.com` | Refusé |
| srv-int (SRV) | dépôt Ubuntu | 80 | sur srv-int : `sudo apt update` | Autorisé |
| ext (WAN) | 10.10.0.20 | 22 | sur ext : `nc -vz -w3 10.10.0.20 22` | Refusé |
| ext (WAN) | 10.10.0.20 | 443 | sur ext : `curl -kI https://10.10.0.20` | Autorisé (web) |
| ext (WAN) | 10.1.30.10 (adresse privée) | 443 | sur ext : `nc -vz -w3 10.1.30.10 443` | Refusé (avec *Filter rule association* = Pass) |

Pour un test depuis web ou srv-int, connectez-vous d'abord en SSH depuis la Kali (`ssh formation@10.1.30.10`). Si une règle vous empêche d'y entrer, ouvrez la console de la machine depuis le portail. Consultez *Status → System Logs → Firewall* : vos refus apparaissent, horodatés. Filtrez par interface.

13. Retirez l'adresse de test : `sudo ip addr del 10.1.10.20/24 dev eth0`.

> **Défi ★.** Ajoutez un réseau invité isolé (interface virtuelle VLAN 90 sur LAN) : accès Internet seulement, aucun accès aux autres zones. Écrivez ses règles. Discutez de la sécurité de couche 2 nécessaire sur le commutateur pour que ce VLAN tienne réellement.

**Livrable** : `matrice-flux`, export des règles (*Diagnostics → Backup & Restore*, section *Firewall Rules*), tableau de tests complété.

## Questions de validation

1. Pourquoi la règle de blocage final doit-elle être journalisée ?
2. Le port forward crée l'accès ; qu'est-ce qui assure réellement la sécurité du service publié ?
3. Un collègue propose une règle `N_LAN → any: any` « pour simplifier ». Que répondez-vous ?

---

[← TP2](../tp2/README.md) · [Sommaire](../README.md) · [Corrigé](corrige/README.md) · [En cas de blocage](../en-cas-de-blocage.md) · [TP4 →](../tp4/README.md)
