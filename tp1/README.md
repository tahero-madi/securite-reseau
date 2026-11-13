# TP1 — Cartographie, couche 2 et analyse de risques

**Jour 1, 10:25 · 1 h 35.** Objectifs : prendre en main le laboratoire ; cartographier son propre réseau de façon autorisée ; observer concrètement la fragilité de la couche 2 ; produire une première matrice de risques.

**Prérequis** : module 1. **Périmètre autorisé** : uniquement les machines de votre laboratoire (réseaux 10.1.0.0/16 et votre VPC). **Livrable** : un fichier `cartographie.md` (inventaire + schéma de flux observés) et une `matrice-risques` (tableau de 5 risques cotés).

## Partie A — Prise en main et cartographie (30 min)

1. Ouvrez votre console web Hexceos : le bureau est votre `poste`. Dans un terminal, lancez `lab statut` (toutes les machines doivent être *running*) puis `lab instantane depart`. Vérifiez votre adresse sur le LAN : `ip -4 a show lab-lan` et `ip r`. Notez par où passent les routes vers 10.1.20.0/24 et 10.1.30.0/24.
2. Vérifiez l'accès à l'interface de `fw` : dans le navigateur, `https://10.1.10.1`. Connectez-vous (identifiants fournis). **Changez immédiatement le mot de passe admin** (System → User Manager) : c'est la première mesure de durcissement.
3. Depuis le terminal de `poste`, découvrez les hôtes actifs de votre LAN et de la zone serveurs. Le balayage ne porte que sur **vos** sous-réseaux :

```bash
sudo nmap -sn 10.1.10.0/24 10.1.20.0/24 10.1.30.0/24
```

4. Identifiez les services d'une machine serveur et d'une machine DMZ (découverte de versions) :

```bash
sudo nmap -sV -O --top-ports 200 10.1.20.10 10.1.30.10
```

5. Consignez le résultat dans `cartographie.md` : pour chaque hôte, adresse, rôle supposé, services et versions repérés. Comparez à la topologie fournie et notez les écarts : un hôte du LAN n'est-il pas documenté ? un serveur expose-t-il plus de services que son rôle ne l'exige ?

> **Défi ★.** Utilisez un script NSE pour récupérer les en-têtes et certificats du serveur web : `nmap --script ssl-cert,http-headers -p 80,443 10.1.30.10`. Qu'apprend un attaquant de ces informations ?

## Partie B — Observer la couche 2 (35 min)

L'objectif est de **constater** l'absence d'authentification de la couche 2, puis d'en déduire les protections. On travaille uniquement sur son propre segment.

6. Affichez votre table ARP : `ip neigh show dev lab-lan`. Repérez l'adresse MAC de la passerelle `10.1.10.1`.
7. On observe le segment LAN du point de vue du poste utilisateur `client` (10.1.10.20). Son interface côté commutateur, `v-client`, sert de **port miroir**. Lancez une surveillance ARP dessus :

```bash
sudo arpwatch -d -N -i v-client 2>&1 | tee ~/arp-tp1.log
```

Dans un second terminal, ouvrez Wireshark sur `v-client`, filtre d'affichage `arp || icmp`. Le client émet du trafic normal toutes les 20 secondes (ping de la passerelle, accès à l'intranet). Notez l'adresse MAC qu'il associe à `10.1.10.1`.

8. **Démonstration encadrée de l'usurpation ARP.** Au signal du formateur, lancez la démonstration (15 secondes, arrêt et nettoyage automatiques) :

```bash
lab demo-arp
```

Pendant ces quelques secondes, la machine `intrus` (10.1.10.66) annonce au client qu'elle est la passerelle. Rien n'authentifie les réponses ARP : le client la croit. Notez :
   - le message d'`arpwatch` (`changed ethernet address` pour 10.1.10.1) ;
   - dans Wireshark, les réponses ARP **non sollicitées** et la MAC de la « passerelle » qui change ;
   - les pings du client, qui partent désormais vers la MAC de l'intrus avant d'être relayés : l'intrus est **au milieu** ;
   - le fait que le commutateur, sans DAI, laisse passer ces réponses.

9. **Capture d'un flux en clair.** Ouvrez Wireshark sur `lab-lan` (l'interface de votre poste), filtre d'affichage `ftp`. Depuis le terminal, connectez-vous au service FTP ancien exposé par `web` :

```bash
ftp 10.1.30.10
```

(compte `ftpdemo`, mot de passe dans `~/TP/identifiants-lab.txt`). Dans Wireshark, suivez le flux (*Follow TCP Stream*) : **l'identifiant et le mot de passe apparaissent en clair**. Capturez l'écran pour le livrable.

> **Cadre de la démonstration.** L'usurpation ARP se joue uniquement entre deux machines de votre laboratoire, pendant 15 secondes au plus, à l'initiative du formateur ; la table ARP du client est purgée à la fin. Les captures `~/TP/tp1-arp-demo.pcap` et `~/TP/tp1-ftp-clear.pcap` montrent les mêmes phénomènes si la manipulation en direct n'est pas possible.

## Partie C — Analyse de risques (30 min)

10. À partir de la cartographie et des observations, remplissez une matrice de 5 risques selon la méthode simplifiée du module 1 (biens, scénario, vraisemblance 1-4, gravité 1-4, niveau, mesures, risque résiduel). Imposez-vous au moins : un risque de couche 2, un risque lié à un protocole en clair, un risque lié à la cible héritée, un risque lié à l'exposition DMZ.

**Livrable** : `cartographie.md` + `matrice-risques` (tableau). Déposez-les à l'endroit indiqué par le formateur.

## Questions de validation

1. Quelle fonction de commutateur aurait bloqué l'usurpation ARP observée, et sur quelle table s'appuie-t-elle ?
2. Pourquoi le mot de passe FTP est-il visible alors que le réseau est « interne » ?
3. Donnez deux mesures pour supprimer le risque lié à la cible héritée sans la corriger elle-même.

---

[Sommaire](../README.md) · [Corrigé](corrige/README.md) · [En cas de blocage](../en-cas-de-blocage.md) · [TP2 →](../tp2/README.md)
