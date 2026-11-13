# TP1 — Cartographie, couche 2 et analyse de risques

**Jour 1, 10:25 · 1 h 35.** Objectifs : prendre en main le laboratoire ; cartographier son propre réseau de façon autorisée ; observer concrètement la fragilité de la couche 2 ; produire une première matrice de risques.

**Prérequis** : module 1. **Périmètre autorisé** : uniquement les machines de votre laboratoire (réseaux 10.1.10.0/24, 10.1.20.0/24, 10.1.30.0/24, et sur le WAN 10.10.0.20, 10.10.0.30, 10.10.0.40). **Livrable** : un fichier `cartographie.md` (inventaire + schéma de flux observés) et une `matrice-risques` (tableau de 5 risques cotés), dans `~/livrables`.

**Déroulé** : étapes 1 à 4 (cartographie) 30 min · étapes 5 et 6 (couche 2) 35 min · étape 7 (analyse de risques) 30 min.

> **Instantané `initial`.** Chacune de vos 6 machines a un instantané nommé **`initial`**, avec la description « NE PAS SUPPRIMER !!!!! ». C'est l'état de départ de la formation : en cas de fausse manœuvre grave, le formateur vous y ramènera. **Ne le supprimez jamais.** Vous pourrez créer vos propres instantanés avant les TP suivants.

## Étape 1 — Prendre en main la Kali

**Pourquoi.** La Kali est votre poste d'administration, branché sur le LAN derrière pfSense. Avant toute chose, on vérifie son adresse et son chemin vers les autres réseaux : si la route par défaut ne passe pas par pfSense, aucun des tests de la formation n'aurait de sens.

Ouvrez la console de la **Kali** depuis le portail Hexceos, puis un terminal :

```bash
ip -br a
ip route
```

**Ligne par ligne.**

- `ip -br a` : liste les cartes réseau et leurs adresses, en format court (`-br` pour *brief*). La Kali n'a qu'une carte, `eth0`, avec l'adresse `10.1.10.10/24`.
- `ip route` : affiche la table de routage. Une seule route par défaut doit apparaître : `default via 10.1.10.1`, c'est-à-dire pfSense. Tout ce que vous faites depuis la Kali traverse donc le pare-feu.

## Étape 2 — Sécuriser l'accès à pfSense

**Pourquoi.** Un pare-feu dont le mot de passe d'administration est connu (ici, celui fourni par la plateforme) n'en est pas un. C'est la toute première mesure de durcissement.

Dans Firefox, ouvrez `https://10.1.10.1`, acceptez l'avertissement sur le certificat (autosigné), puis connectez-vous avec le compte fourni par le portail (bouton clé). **Changez immédiatement le mot de passe admin** : *System → User Manager*, utilisateur `admin`, icône crayon. Notez le nouveau mot de passe : vous en aurez besoin à chaque TP.

## Étape 3 — Découvrir les hôtes

**Pourquoi.** On ne protège bien que ce que l'on connaît. La première étape de toute démarche de sécurité est l'inventaire : quelles machines sont réellement présentes sur chaque réseau, documentées ou non.

> **Prédiction.** D'après la [topologie](../avant-de-commencer.md#topologie), combien d'hôtes devriez-vous trouver sur vos trois réseaux internes ? Notez votre réponse avant de lancer la commande.

```bash
sudo nmap -sn 10.1.10.0/24 10.1.20.0/24 10.1.30.0/24
```

**Ligne par ligne.**

- `sudo` : nmap a besoin des droits administrateur pour envoyer des paquets « bruts » (requêtes ARP, ICMP construites à la main).
- `nmap -sn` : découverte d'hôtes seulement (*ping scan*), sans balayage de ports. Sur le LAN, nmap interroge chaque adresse en ARP, et affiche donc l'adresse MAC et le constructeur de la carte ; pour SRV et DMZ, de l'autre côté de pfSense, il utilise ICMP et TCP.
- `10.1.10.0/24 10.1.20.0/24 10.1.30.0/24` : les trois réseaux internes, soit 768 adresses.

Comparez le résultat à votre prédiction et à la topologie. Notez tout écart.

> **Hors périmètre.** Si un hôte inconnu apparaît, documentez-le, mais ne lancez **aucun** balayage de services sur lui : tant qu'on ne sait pas à qui il appartient, il est hors du périmètre autorisé. C'est la règle de tout audit.

## Étape 4 — Identifier les services

**Pourquoi.** Chaque service exposé est une porte d'entrée possible. On relève les ports ouverts, le logiciel qui répond et sa version, et l'on compare avec le rôle de la machine : un serveur ne devrait exposer que ce dont son rôle a besoin.

```bash
sudo nmap -sV -O --top-ports 200 10.1.20.10 10.1.30.10
```

**Ligne par ligne.**

- `-sV` : détection des versions ; nmap dialogue avec chaque port ouvert pour identifier le logiciel et sa version. C'est l'étape la plus longue.
- `-O` : détection du système d'exploitation, d'après la façon dont la pile réseau répond.
- `--top-ports 200` : se limite aux 200 ports les plus courants, au lieu des 65 535. Un service sur un port inhabituel peut donc échapper au balayage.
- `10.1.20.10 10.1.30.10` : les deux serveurs, `srv-int` et `web`.

**La commande prend plusieurs minutes** (environ 3 minutes) : nmap attend les réponses des services lents ou inconnus. Pendant ce temps, appuyez sur Entrée dans le terminal pour afficher la progression.

Consignez le résultat dans `cartographie.md` : pour chaque hôte, adresse, rôle supposé, services et versions repérés. Regardez d'un œil critique ce que nmap annonce : les versions et le système détectés sont-ils tous plausibles pour des serveurs Ubuntu 24.04 ? Un serveur expose-t-il plus de services que son rôle ne l'exige ?

> **Défi ★.** Récupérez les en-têtes HTTP et le certificat du serveur web avec des scripts NSE :
>
> ```bash
> nmap --script ssl-cert,http-headers -p 80,443 10.1.30.10
> ```
>
> - `--script ssl-cert,http-headers` : lance deux scripts du moteur NSE de nmap, l'un qui lit le certificat TLS, l'autre qui affiche les en-têtes de la réponse HTTP.
> - `-p 80,443` : seulement les ports HTTP et HTTPS.
>
> Qu'apprend un attaquant de ces informations ? Regardez en particulier les adresses citées dans le certificat.

## Étape 5 — Observer l'usurpation ARP

**Pourquoi.** ARP associe une adresse IP à une adresse MAC, sans aucune authentification : n'importe quelle machine du segment peut répondre « cette adresse, c'est moi », et les autres la croient. On va le constater sur le réseau WAN de votre laboratoire, entre deux de vos machines : `ext` (10.10.0.40) va se faire passer, auprès de `cloud-gw` (10.10.0.30), pour pfSense (10.10.0.20).

> **Cadre de la démonstration.** L'usurpation ne vise que vos propres machines (ext et cloud-gw), pendant 20 secondes au plus, à l'initiative du formateur. Ne visez jamais 10.10.0.1 : c'est la passerelle de la plateforme. La capture `~/TP/tp1-arp-demo.pcap` montre le même phénomène si la manipulation en direct n'est pas possible : ouvrez-la dans Wireshark.

> **Prédiction.** Pendant l'usurpation, cloud-gw continuera-t-il de recevoir les réponses à ses pings vers pfSense ? Pourquoi ?

Ouvrez **trois terminaux** sur la Kali et connectez-vous en SSH avec le compte `formation` (mot de passe : portail, bouton clé). À la première connexion, répondez `yes` pour accepter l'empreinte de la machine.

- terminal 1 : `ssh formation@10.10.0.30` (cloud-gw, la victime) ;
- terminal 2 : `ssh formation@10.10.0.40` (ext, l'usurpateur) ;
- terminal 3 : `ssh formation@10.10.0.40` (ext, pour observer).

**Terminal 1, sur cloud-gw** : on relève l'adresse MAC de pfSense, puis on lance une surveillance ARP et un ping continu.

```bash
ping -c1 10.10.0.20 >/dev/null ; ip neigh show 10.10.0.20
sudo -v
sudo arpwatch -d -N -i ens18 2>&1 | grep -v '^$' &
ping 10.10.0.20
```

**Ligne par ligne.**

- `ping -c1 10.10.0.20 >/dev/null ; ip neigh show 10.10.0.20` : un ping pour remplir la table ARP, puis l'affichage de l'entrée de pfSense. Notez son adresse MAC (`lladdr`) : c'est la vraie.
- `sudo -v` : saisit le mot de passe sudo maintenant ; sans cela, la commande suivante, lancée en arrière-plan, ne pourrait pas le demander.
- `sudo arpwatch -d -N -i ens18 2>&1 | grep -v '^$' &` : lance arpwatch, qui surveille les associations IP ↔ MAC et signale tout changement. `-d` affiche les messages à l'écran au lieu de les envoyer par courriel, `-N` ignore les adresses hors du réseau local, `-i ens18` désigne la carte surveillée. Le `&` final le laisse tourner en arrière-plan.
- `ping 10.10.0.20` : ping continu vers pfSense, qui va servir de trafic témoin.

Si la carte de cloud-gw ne s'appelle pas `ens18`, remplacez le nom par celui affiché par `ip -br a`, ici comme sur ext.

**Terminal 3, sur ext** : on observe ce que reçoit ext.

```bash
sudo tcpdump -eni ens18 'icmp and host 10.10.0.30'
```

**Ligne par ligne.**

- `tcpdump -eni ens18` : capture sur la carte `ens18` ; `-e` affiche les adresses MAC de chaque trame, `-n` n'essaie pas de traduire les adresses en noms.
- `'icmp and host 10.10.0.30'` : ne garde que les paquets ICMP (les pings) qui concernent cloud-gw. Pour l'instant, rien ne s'affiche : les pings de cloud-gw vont directement à pfSense.

**Terminal 2, sur ext** : on lance l'usurpation pendant 20 secondes.

```bash
ip neigh show 10.10.0.20
sudo sysctl -qw net.ipv4.ip_forward=1
sudo timeout 20 arpspoof -i ens18 -t 10.10.0.30 10.10.0.20
sudo sysctl -qw net.ipv4.ip_forward=0
```

**Ligne par ligne.**

- `ip neigh show 10.10.0.20` : la vraie MAC de pfSense, vue par ext.
- `sysctl -qw net.ipv4.ip_forward=1` : active le routage sur ext, pour qu'il **relaie** les paquets détournés vers pfSense. La victime ne voit alors aucune coupure : c'est une attaque de l'homme du milieu.
- `timeout 20 arpspoof -i ens18 -t 10.10.0.30 10.10.0.20` : envoie en boucle à cloud-gw (`-t`, la cible) des réponses ARP affirmant que 10.10.0.20 a l'adresse MAC d'ext. `timeout 20` arrête l'attaque au bout de 20 secondes ; à l'arrêt, arpspoof réannonce la vraie adresse.
- `sysctl -qw net.ipv4.ip_forward=0` : désactive le routage sur ext.

Pendant ces 20 secondes, notez :

- dans le terminal 3, les pings de cloud-gw qui **arrivent maintenant à ext**, adressés à la MAC d'ext, puis repartent vers la MAC de pfSense ;
- dans le terminal 1, le ping qui continue de répondre, et le message d'arpwatch sur le changement d'adresse de 10.10.0.20 ;
- depuis un quatrième terminal sur cloud-gw, `ip neigh show 10.10.0.20` : elle affiche la MAC d'**ext**.

À la fin, sur cloud-gw, arrêtez le ping (Ctrl+C) et arpwatch :

```bash
sudo pkill arpwatch
ip neigh show 10.10.0.20
```

**Ligne par ligne.**

- `sudo pkill arpwatch` : arrête arpwatch, qui tournait en arrière-plan.
- `ip neigh show 10.10.0.20` : la MAC de pfSense doit être revenue. Sinon, `sudo ip neigh flush 10.10.0.20` vide l'entrée, qui sera réapprise au prochain paquet.

Arrêtez aussi le `tcpdump` du terminal 3 (Ctrl+C).

## Étape 6 — Capturer un mot de passe en clair

**Pourquoi.** Un protocole sans chiffrement transporte identifiants et données lisiblement : quiconque se trouve sur le chemin, ou a détourné le trafic comme ext à l'étape précédente, les lit. Le serveur `web` expose un service FTP ancien : on va voir ce qu'il laisse passer.

Sur la Kali, ouvrez **Wireshark**, choisissez l'interface `eth0` et lancez la capture. Dans la barre de filtre d'affichage, tapez `ftp` puis Entrée. Dans un terminal de la Kali :

```bash
ftp 10.1.30.10
```

**Ligne par ligne.**

- `ftp 10.1.30.10` : ouvre une session FTP vers `web`. Saisissez le compte `ftpdemo` et le mot de passe indiqué dans `~/TP/identifiants-lab.txt`, puis tapez `ls` et `bye`.

Dans Wireshark, faites un clic droit sur un paquet FTP, puis *Follow → TCP Stream* : **l'identifiant et le mot de passe apparaissent en clair** (`USER ftpdemo`, `PASS …`). Faites une capture d'écran pour le livrable. Repli : `~/TP/tp1-ftp-clear.pcap`.

## Étape 7 — Analyse de risques

**Pourquoi.** Les constats techniques ne valent que s'ils sont reliés aux enjeux : quel bien est menacé, par quel scénario, avec quelle vraisemblance et quelle gravité. La matrice de risques permet de prioriser les mesures.

À partir de la cartographie et des observations, remplissez une matrice de 5 risques selon la méthode simplifiée du module 1 : bien, scénario, vraisemblance (1 à 4), gravité (1 à 4), niveau, mesures, risque résiduel. Imposez-vous au moins :

- un risque de couche 2 ;
- un risque lié à un protocole en clair ;
- un risque lié à la cible héritée (`web`) ;
- un risque lié à l'exposition de la DMZ.

## Questions de validation

1. Quelle fonction de commutateur aurait bloqué l'usurpation ARP observée, et sur quelle table s'appuie-t-elle ?
2. Pourquoi le mot de passe FTP est-il visible alors que le réseau est « interne » ?
3. Donnez deux mesures pour supprimer le risque lié à la cible héritée sans la corriger elle-même.

---

[Sommaire](../README.md) · [Corrigé](corrige/README.md) · [En cas de blocage](../en-cas-de-blocage.md) · [TP2 →](../tp2/README.md)
