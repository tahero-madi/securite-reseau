# TP1 — Cartographie, couche 2 et analyse de risques

**Jour 1, 10:25 · 1 h 35.** Objectifs : prendre en main le laboratoire ; cartographier son propre réseau de façon autorisée ; observer concrètement la fragilité de la couche 2 ; produire une première matrice de risques.

**Prérequis** : module 1. **Périmètre autorisé** : uniquement les machines de votre laboratoire (réseaux 10.1.10.0/24, 10.1.20.0/24, 10.1.30.0/24, et sur le WAN 10.10.0.20, 10.10.0.30, 10.10.0.40). **Livrable** : un fichier `cartographie.md` (inventaire + schéma de flux observés) et une `matrice-risques` (tableau de 5 risques cotés).

## Partie A — Prise en main et cartographie (30 min)

1. Ouvrez la console de la **Kali** depuis le portail Hexceos : c'est votre poste d'administration. Dans un terminal, vérifiez votre adresse et vos routes :

```bash
ip -br a
ip route
```

Votre poste a l'adresse `10.1.10.10` sur `eth1` (LAN) et une seule route par défaut, via pfSense (`10.1.10.1`). La carte `eth0` est coupée : elle ne doit pas être rallumée (voir [Avant de commencer](../avant-de-commencer.md)).

2. Prenez un **instantané** de vos 6 machines depuis le portail (bouton appareil photo), nommé `depart` : vous pourrez y revenir à tout moment.
3. Vérifiez l'accès à l'interface de pfSense : dans Firefox, `https://10.1.10.1`. Connectez-vous avec le compte fourni par le portail (bouton clé). **Changez immédiatement le mot de passe admin** (*System → User Manager*) : c'est la première mesure de durcissement.
4. Découvrez les hôtes actifs de vos trois réseaux internes :

```bash
sudo nmap -sn 10.1.10.0/24 10.1.20.0/24 10.1.30.0/24
```

5. Identifiez les services du serveur interne et du serveur de la DMZ :

```bash
sudo nmap -sV -O --top-ports 200 10.1.20.10 10.1.30.10
```

6. Consignez le résultat dans `cartographie.md` : pour chaque hôte, adresse, rôle supposé, services et versions repérés. Comparez à la [topologie fournie](../avant-de-commencer.md#topologie) et notez les écarts : un hôte présent sur un réseau n'est-il pas documenté ? un serveur expose-t-il plus de services que son rôle ne l'exige ?

> **Hors périmètre.** Si un hôte inconnu apparaît, documentez-le, mais ne lancez **aucun** balayage de services sur lui : tant qu'on ne sait pas à qui il appartient, il est hors du périmètre autorisé. C'est la règle de tout audit.

> **Défi ★.** Utilisez un script NSE pour récupérer les en-têtes et le certificat du serveur web : `nmap --script ssl-cert,http-headers -p 80,443 10.1.30.10`. Qu'apprend un attaquant de ces informations ?

## Partie B — Observer la couche 2 (35 min)

L'objectif est de **constater** l'absence d'authentification de la couche 2, puis d'en déduire les protections. La démonstration se joue sur le réseau WAN de votre laboratoire, entre deux de vos machines : `ext` (10.10.0.40) va se faire passer, auprès de `cloud-gw` (10.10.0.30), pour pfSense (10.10.0.20).

7. Ouvrez **trois terminaux** sur la Kali et connectez-vous en SSH (compte `formation`) :
   - terminal 1 : `ssh formation@10.10.0.30` (cloud-gw, la victime) ;
   - terminal 2 : `ssh formation@10.10.0.40` (ext, l'usurpateur) ;
   - terminal 3 : `ssh formation@10.10.0.40` (ext, pour observer).

8. **Sur cloud-gw** (terminal 1), notez l'adresse MAC de pfSense dans la table ARP, puis lancez une surveillance ARP et un ping continu vers pfSense :

```bash
ping -c1 10.10.0.20 >/dev/null ; ip neigh show 10.10.0.20
sudo -v                                   # saisit le mot de passe sudo avant de passer en arrière-plan
sudo arpwatch -d -N -i ens18 2>&1 | grep -v '^$' &
ping 10.10.0.20
```

Si la carte de cloud-gw ne s'appelle pas `ens18`, remplacez le nom par celui affiché par `ip -br a`, ici comme sur ext.

9. **Sur ext** (terminal 3), observez ce qui arrive à ext : pour l'instant, rien de ce que cloud-gw envoie à pfSense.

```bash
sudo tcpdump -eni ens18 'icmp and host 10.10.0.30'
```

10. **Sur ext** (terminal 2), lancez l'usurpation pendant 20 secondes : ext annonce à cloud-gw « 10.10.0.20, c'est moi ». ext relaie les paquets (homme du milieu), pour que rien ne se voie côté victime :

```bash
ip neigh show 10.10.0.20     # notez la vraie MAC de pfSense, vue par ext
sudo sysctl -qw net.ipv4.ip_forward=1
sudo timeout 20 arpspoof -i ens18 -t 10.10.0.30 10.10.0.20
sudo sysctl -qw net.ipv4.ip_forward=0
```

Pendant ces 20 secondes, notez :
   - dans le terminal 3, les pings de cloud-gw qui **passent maintenant par ext**, avec l'adresse MAC d'ext en destination ;
   - dans le terminal 1, le ping qui continue de répondre : la victime ne s'aperçoit de rien ;
   - le message d'`arpwatch` sur cloud-gw (`changed ethernet address` pour 10.10.0.20) ;
   - sur cloud-gw, depuis un autre terminal : `ip neigh show 10.10.0.20` affiche la MAC d'**ext**.

À la fin, `arpspoof` réannonce la vraie adresse. Sur cloud-gw, arrêtez le ping (Ctrl+C) et `arpwatch` (`sudo pkill arpwatch`), puis vérifiez avec `ip neigh show 10.10.0.20` que la MAC de pfSense est revenue (sinon : `sudo ip neigh flush 10.10.0.20`).

11. **Capture d'un flux en clair.** Sur la Kali, ouvrez Wireshark sur `eth1` (l'interface de votre poste), filtre d'affichage `ftp`. Depuis un terminal de la Kali, connectez-vous au service FTP ancien exposé par `web` :

```bash
ftp 10.1.30.10
```

Compte `ftpdemo`, mot de passe dans `~/TP/identifiants-lab.txt`. Dans Wireshark, suivez le flux (*Analyze → Follow → TCP Stream*) : **l'identifiant et le mot de passe apparaissent en clair**. Capturez l'écran pour le livrable.

> **Cadre de la démonstration.** L'usurpation ARP ne vise que vos propres machines (ext et cloud-gw), pendant 20 secondes au plus, à l'initiative du formateur. Ne visez jamais 10.10.0.1 : c'est la passerelle de la plateforme. Les captures `~/TP/tp1-arp-demo.pcap` et `~/TP/tp1-ftp-clear.pcap` montrent les mêmes phénomènes si la manipulation en direct n'est pas possible : ouvrez-les dans Wireshark.

## Partie C — Analyse de risques (30 min)

12. À partir de la cartographie et des observations, remplissez une matrice de 5 risques selon la méthode simplifiée du module 1 (biens, scénario, vraisemblance 1-4, gravité 1-4, niveau, mesures, risque résiduel). Imposez-vous au moins : un risque de couche 2, un risque lié à un protocole en clair, un risque lié à la cible héritée (`web`), un risque lié à l'exposition DMZ.

**Livrable** : `cartographie.md` + `matrice-risques` (tableau), dans `~/livrables`.

## Questions de validation

1. Quelle fonction de commutateur aurait bloqué l'usurpation ARP observée, et sur quelle table s'appuie-t-elle ?
2. Pourquoi le mot de passe FTP est-il visible alors que le réseau est « interne » ?
3. Donnez deux mesures pour supprimer le risque lié à la cible héritée sans la corriger elle-même.

---

[Sommaire](../README.md) · [Corrigé](corrige/README.md) · [En cas de blocage](../en-cas-de-blocage.md) · [TP2 →](../tp2/README.md)
