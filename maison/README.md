# Refaire le laboratoire chez soi

Cette page explique comment recréer le laboratoire de la formation sur un PC sous Ubuntu, avec **quatre machines virtuelles** au lieu de six : pfSense, une VM « interne » (poste Kali + srv-int), une VM `web` et une VM « externe » (cloud-gw + ext). Les adresses, les zones et les TP restent identiques à ceux de la plateforme.

Comptez une demi-journée, dont la plus grande partie en attente (installation des systèmes, téléchargement de Greenbone).

## Architecture

| VM | Rôle(s) | Carte → réseau | Adresse | Adresse MAC à imposer |
|---|---|---|---|---|
| `pfsense` | pare-feu | WAN → `lab-wan` | 10.10.0.20 | `52:54:00:00:00:20` |
| | | LAN → `lab-lan` | 10.1.10.1 | `52:54:00:10:00:01` |
| | | SRV → `lab-srv` | 10.1.20.1 | `52:54:00:20:00:01` |
| | | DMZ → `lab-dmz` | 10.1.30.1 | `52:54:00:30:00:01` |
| `interne` | **poste Kali** (bureau, outils, Greenbone, Zabbix) | `lab-lan` | 10.1.10.10 | `52:54:00:10:00:10` |
| | **srv-int** (LDAP, RADIUS, syslog, agent Zabbix) | `lab-srv` | 10.1.20.10 | `52:54:00:20:00:10` |
| `web` | web (DMZ) | `lab-dmz` | 10.1.30.10 | `52:54:00:30:00:10` |
| `externe` | **cloud-gw** (IPsec, « VPC » 10.101.1.1) | `lab-wan` | 10.10.0.30 | `52:54:00:00:00:30` |
| | **ext** (machine « Internet ») | `lab-wan` | 10.10.0.40 | `52:54:00:00:00:40` |

Le PC hôte tient le rôle de la passerelle de la plateforme : il porte `10.10.0.1` sur le réseau `lab-wan`, fait le DNS et la traduction d'adresses vers votre box. Les réseaux `lab-lan`, `lab-srv` et `lab-dmz` sont isolés : l'hôte n'y a pas d'adresse, seul pfSense les relie.

**Deux rôles dans une VM, sans contourner pfSense.** Dans `interne` et `externe`, chaque rôle a sa propre carte réseau, placée dans un **espace de noms réseau** (*network namespace*) distinct : sa propre adresse, ses propres routes, ses propres ports. Le poste Kali ne voit pas la carte SRV : pour joindre srv-int, son trafic passe par pfSense, exactement comme sur la plateforme. Le script `maison.sh` met cela en place.

## Prérequis

- Un PC sous **Ubuntu 24.04** (bureau), processeur avec virtualisation matérielle (Intel VT-x ou AMD-V activée dans le BIOS).
- **16 Go de RAM** au minimum (la VM `interne` en prend 8, Greenbone compris), 32 Go pour être à l'aise.
- **150 Go** d'espace disque libre.
- Pas de Docker installé sur l'hôte : il charge un module (`br_netfilter`) qui filtre les ponts des VM et casse les réseaux du lab.
- Trois images à télécharger dans votre dossier de téléchargements :
  - pfSense CE : [pfsense.org/download](https://www.pfsense.org/download/), installateur Netgate pour **AMD64**, format ISO (décompressez-le s'il est en `.gz`) ;
  - [Ubuntu 24.04 Desktop](https://ubuntu.com/download/desktop) (pour `interne`) ;
  - [Ubuntu 24.04 Server](https://ubuntu.com/download/server) (pour `web` et `externe`).

## Étape 1 — Préparer l'hôte (10 min)

**Pourquoi.** KVM est l'hyperviseur intégré à Linux ; libvirt le pilote. On crée les quatre réseaux du lab : `lab-wan` joue Internet, les trois autres sont les zones internes.

```bash
sudo apt install -y qemu-kvm libvirt-daemon-system virtinst virt-manager
sudo usermod -aG libvirt,kvm $USER
cat > /tmp/lab-wan.xml <<'EOF'
<network>
  <name>lab-wan</name>
  <forward mode='nat'/>
  <bridge name='virbr-wan' stp='off' delay='0'/>
  <ip address='10.10.0.1' netmask='255.255.255.0'/>
</network>
EOF
for n in lan srv dmz; do
  printf "<network>\n  <name>lab-%s</name>\n  <bridge name='virbr-%s' stp='off' delay='0'/>\n</network>\n" $n $n > /tmp/lab-$n.xml
done
for n in wan lan srv dmz; do
  sudo virsh net-define /tmp/lab-$n.xml
  sudo virsh net-autostart lab-$n
  sudo virsh net-start lab-$n
done
sudo virsh net-list
sudo install -d /var/lib/libvirt/boot
sudo cp ~/Téléchargements/<installateur-pfsense>.iso /var/lib/libvirt/boot/pfsense.iso
sudo cp ~/Téléchargements/ubuntu-24.04*-desktop-amd64.iso /var/lib/libvirt/boot/ubuntu-desktop.iso
sudo cp ~/Téléchargements/ubuntu-24.04*-live-server-amd64.iso /var/lib/libvirt/boot/ubuntu-server.iso
```

**Ligne par ligne.**

- `apt install …` : KVM, libvirt, `virt-install` (création des VM en ligne de commande) et `virt-manager` (console graphique).
- `usermod -aG libvirt,kvm $USER` : vous autorise à piloter les VM. Fermez puis rouvrez votre session pour que ce soit pris en compte.
- `lab-wan.xml` : réseau en traduction d'adresses (`nat`) ; l'hôte y porte `10.10.0.1`, qui sert de passerelle et de DNS (comme la plateforme). Pas de DHCP : toutes les adresses sont fixes.
- `printf … > /tmp/lab-$n.xml` : réseaux `lab-lan`, `lab-srv` et `lab-dmz`, sans adresse pour l'hôte : de simples commutateurs isolés.
- `virsh net-define`, `net-autostart`, `net-start` : enregistre chaque réseau, le démarre avec l'hôte, et le démarre maintenant. `net-list` doit afficher les quatre réseaux `active`.
- `cp … /var/lib/libvirt/boot/…` : place les images d'installation là où libvirt peut les lire, sous des noms courts. Remplacez `<installateur-pfsense>` par le nom du fichier téléchargé.

## Étape 2 — pfSense (20 min)

```bash
sudo virt-install --name pfsense --memory 2048 --vcpus 2 --osinfo freebsd14.0 \
  --cdrom /var/lib/libvirt/boot/pfsense.iso --disk size=16,bus=virtio \
  --network network=lab-wan,model=virtio,mac=52:54:00:00:00:20 \
  --network network=lab-lan,model=virtio,mac=52:54:00:10:00:01 \
  --network network=lab-srv,model=virtio,mac=52:54:00:20:00:01 \
  --network network=lab-dmz,model=virtio,mac=52:54:00:30:00:01
```

- `--memory 2048` : 2 Go, nécessaires à Suricata (TP5).
- `--osinfo freebsd14.0` : pfSense repose sur FreeBSD. Si la commande refuse ce nom, `osinfo-query os | grep -i freebsd` donne ceux que votre hôte connaît.
- `--network … mac=…` : les quatre cartes, dans l'ordre WAN, LAN, SRV, DMZ. Dans pfSense, elles s'appellent `vtnet0` à `vtnet3`, dans le même ordre.

Dans la console qui s'ouvre, installez pfSense CE :

1. Interface **WAN** : `vtnet0`, adresse **statique** 10.10.0.20/24, passerelle 10.10.0.1, DNS 10.10.0.1 (l'installateur Netgate télécharge pfSense par ce chemin).
2. Interface **LAN** : `vtnet1`, 10.1.10.1/24.
3. Choisissez **pfSense CE**, installez, redémarrez.
4. Au menu de la console, option **1** (*Assign Interfaces*) : pas de VLAN ; WAN `vtnet0`, LAN `vtnet1`, OPT1 `vtnet2`, OPT2 `vtnet3`.
5. Option **2** (*Set interface IP address*) : OPT1 en 10.1.20.1/24, OPT2 en 10.1.30.1/24, sans passerelle, sans serveur DHCP. Vérifiez au passage WAN et LAN.

La suite de la configuration se fait dans l'interface web, depuis la VM `interne` (étape 3).

## Étape 3 — VM « interne » : poste Kali + srv-int (1 h, surtout de l'attente)

```bash
sudo virt-install --name interne --memory 8192 --vcpus 4 --osinfo ubuntu24.04 \
  --cdrom /var/lib/libvirt/boot/ubuntu-desktop.iso --disk size=80,bus=virtio \
  --network network=lab-lan,model=virtio,mac=52:54:00:10:00:10 \
  --network network=lab-srv,model=virtio,mac=52:54:00:20:00:10
```

Installez Ubuntu Desktop : nom de la machine **`interne`**, utilisateur **`formation`**. L'installateur n'a pas d'accès Internet à ce stade : c'est normal, ne cochez pas les mises à jour pendant l'installation.

### 3a — Réseau du poste

Après le redémarrage, ouvrez un terminal :

```bash
IF=$(ip -o link | awk 'tolower($0) ~ /52:54:00:10:00:10/ {sub(/:$/,"",$2); print $2}')
sudo nmcli con add type ethernet ifname "$IF" con-name lab-lan ipv4.method manual \
  ipv4.addresses 10.1.10.10/24 ipv4.gateway 10.1.10.1 ipv4.dns 10.1.10.1 ipv6.method disabled \
  connection.autoconnect-priority 100
sudo nmcli con up lab-lan
ping -c2 10.1.10.1
```

- `IF=$(…)` : retrouve le nom de la carte LAN à partir de son adresse MAC.
- `nmcli con add …` : adresse fixe 10.1.10.10, passerelle et DNS sur pfSense, comme la Kali de la plateforme ; la priorité 100 la fait choisir au démarrage plutôt que la connexion DHCP créée par défaut.
- `ping -c2 10.1.10.1` : pfSense doit répondre.

### 3b — Configuration de pfSense, dans le navigateur

Ouvrez `https://10.1.10.1` (compte `admin`, mot de passe `pfsense`), terminez l'assistant (changez le mot de passe), puis appliquez les réglages de l'[étape 1 de la préparation Hexceos](../hexceos/README.md#étape-1--pfsense-à-la-main), en remplaçant les noms d'interfaces si besoin. En plus, à la maison :

| Où | Réglage |
|---|---|
| *Interfaces → WAN* | **Block private networks** et **Block bogon networks** décochés |
| *Firewall → Rules → LAN* | Renommez les deux règles « Default allow LAN to any » (IPv4 et IPv6) en **HRA : tout autoriser** |
| *Firewall → Rules → WAN*, *SRV*, *DMZ* | Sur chaque onglet, deux règles *Pass*, protocole *Any*, source et destination *Any* : l'une en IPv4, l'autre en IPv6, description **HRA : tout autoriser** |

**Pourquoi.** La plateforme livre pfSense « grand ouvert », avec ces règles « HRA » sur chaque interface ; le TP3 commence par les supprimer. On reproduit cet état de départ pour que les énoncés restent justes.

### 3c — srv-int dans son espace réseau, puis les logiciels

```bash
curl -fsSL https://raw.githubusercontent.com/tahero-madi/securite-reseau/main/maison/maison.sh | sudo bash -s interne
curl -fsSL https://raw.githubusercontent.com/tahero-madi/securite-reseau/main/hexceos/prep.sh | sudo ip netns exec srvint bash
curl -fsSL https://raw.githubusercontent.com/tahero-madi/securite-reseau/main/hexceos/prep.sh | sudo bash
sudo sed -i 's/^NTP=.*/NTP=10.1.10.1/' /etc/systemd/timesyncd.conf.d/10-lab.conf && sudo systemctl restart systemd-timesyncd
```

**Ligne par ligne.**

- `maison.sh … interne` : crée l'espace réseau `srvint`, y place la carte SRV en 10.1.20.10 (passerelle et DNS 10.1.20.1), à chaque démarrage. Les services de srv-int (SSH, LDAP, RADIUS, rsyslog, agent Zabbix) sont rattachés à cet espace. Installe aussi `mousepad` et `masscan`, présents sur Kali. Doit se terminer par « VM interne prête ».
- `prep.sh | sudo ip netns exec srvint bash` : le script de préparation de la plateforme, exécuté **dans** l'espace de srv-int : il ne voit que 10.1.20.10 et installe donc le rôle srv-int. 5 à 10 minutes.
- `prep.sh | sudo bash` : le même script, dans l'espace principal : il voit 10.1.10.10 et installe le rôle Kali (outils, Docker, Zabbix, Greenbone). **30 à 60 minutes.**
- `sed … NTP=10.1.10.1` : srv-int règle l'heure sur 10.1.20.1, mais l'horloge est commune à la VM et le service de temps tourne côté poste : on le fait pointer sur l'adresse LAN de pfSense.

Fermez puis rouvrez la session (groupes `docker` et `wireshark`).

## Étape 4 — VM web (20 min)

```bash
sudo virt-install --name web --memory 2048 --vcpus 2 --osinfo ubuntu24.04 \
  --cdrom /var/lib/libvirt/boot/ubuntu-server.iso --disk size=25,bus=virtio \
  --network network=lab-dmz,model=virtio,mac=52:54:00:30:00:10
```

Installez Ubuntu Server : nom **`web`**, utilisateur **`formation`**, cochez **Install OpenSSH server**. À l'écran réseau, carte en **Manual** : sous-réseau 10.1.30.0/24, adresse 10.1.30.10, passerelle 10.1.30.1, DNS 10.1.30.1. Puis, comme sur la plateforme :

```bash
curl -fsSL https://raw.githubusercontent.com/tahero-madi/securite-reseau/main/hexceos/reseau.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/tahero-madi/securite-reseau/main/hexceos/prep.sh | sudo bash
```

## Étape 5 — VM « externe » : cloud-gw + ext (20 min)

```bash
sudo virt-install --name externe --memory 1536 --vcpus 2 --osinfo ubuntu24.04 \
  --cdrom /var/lib/libvirt/boot/ubuntu-server.iso --disk size=15,bus=virtio \
  --network network=lab-wan,model=virtio,mac=52:54:00:00:00:30 \
  --network network=lab-wan,model=virtio,mac=52:54:00:00:00:40
```

Installez Ubuntu Server : nom **`externe`**, utilisateur **`formation`**, OpenSSH coché. À l'écran réseau :

- la carte `52:54:00:00:00:30` (la première) en **Manual** : sous-réseau 10.10.0.0/24, adresse 10.10.0.30, passerelle 10.10.0.1, DNS 10.10.0.1 ;
- la carte `52:54:00:00:00:40` en **Disabled** : elle sera celle de ext.

Puis :

```bash
curl -fsSL https://raw.githubusercontent.com/tahero-madi/securite-reseau/main/hexceos/reseau.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/tahero-madi/securite-reseau/main/maison/maison.sh | sudo bash -s externe
curl -fsSL https://raw.githubusercontent.com/tahero-madi/securite-reseau/main/hexceos/prep.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/tahero-madi/securite-reseau/main/hexceos/prep.sh | sudo ip netns exec ext bash
```

- `reseau.sh` : configure cloud-gw (10.10.0.30, route vers 10.1.0.0/16 par pfSense), comme sur la plateforme.
- `maison.sh … externe` : crée l'espace réseau `ext` avec la seconde carte en 10.10.0.40 (passerelle 10.10.0.1, route 10.1.0.0/16 via 10.10.0.20) et un serveur SSH propre à ext.
- `prep.sh | sudo bash` : installe le rôle cloud-gw (strongSwan, nftables, « VPC » 10.101.1.1…).
- `prep.sh | sudo ip netns exec ext bash` : installe le rôle ext (nmap, testssl.sh, hping3…).

## Étape 6 — Vérifier et prendre les instantanés

Depuis la VM `interne` :

```bash
curl -fsSL https://raw.githubusercontent.com/tahero-madi/securite-reseau/main/hexceos/verif.sh | bash
```

Puis, quand le flux Greenbone est « Current » (*Administration → Feed Status*), arrêtez les quatre VM et, sur l'hôte :

```bash
for vm in pfsense interne web externe; do sudo virsh snapshot-create-as $vm initial "NE PAS SUPPRIMER !!!!!"; done
```

Pour revenir à l'état de départ : `sudo virsh snapshot-revert <vm> initial`.

## Travailler avec les rôles regroupés

| Dans l'énoncé | À la maison |
|---|---|
| « sur la Kali » | Le bureau et les terminaux de la VM `interne` |
| « sur srv-int » | `ssh formation@10.1.20.10` depuis le poste (passe par pfSense), ou la commande **`srv-int`** dans un terminal de `interne` |
| « sur cloud-gw » | Le terminal de la VM `externe` |
| « sur ext », « depuis ext » | La commande **`ext`** dans un terminal de `externe` (ou `ssh formation@10.10.0.40`) |

Les commandes `srv-int` et `ext` ouvrent un shell dans l'espace réseau du rôle ; l'invite affiche alors son nom. `exit` pour revenir.

## Différences avec la plateforme

- **Disque, processus, journaux et heure sont communs** aux deux rôles d'une même VM. `/var/log/auth.log` de `interne` contient aussi les `sudo` du poste ; `ps` montre les processus des deux rôles. Seul le réseau est séparé.
- **Scan authentifié de srv-int (TP2)** : Greenbone voit tous les paquets de la VM `interne`, donc aussi Docker et les outils du poste. Le rapport contiendra plus de vulnérabilités que sur la plateforme.
- **Pas d'équipement en `.254`** : les réseaux internes n'ont pas de routeur de l'hébergeur. Le contournement par le `.254` du dossier d'audit du TP8 ne se reproduit pas ; le dossier reste utilisable tel quel.
- **Mots de passe** : les VM utilisent le compte `formation` que vous avez créé, pas celui du portail Hexceos.

## En cas de problème

| Symptôme | Cause probable | Correction |
|---|---|---|
| Une VM ne joint pas sa passerelle pfSense | Carte branchée au mauvais réseau ou mauvaise MAC | `sudo virsh domiflist <vm>` sur l'hôte : comparez au tableau de l'architecture |
| Pas d'Internet depuis les zones internes | Règles « HRA » absentes ou DNS de pfSense | Étape 3b ; *Diagnostics → Ping* de pfSense vers 1.1.1.1 depuis le WAN |
| `maison.sh` : « Carte … introuvable » | MAC différente de celle du tableau | Recréez la carte avec la bonne MAC dans `virt-manager` (*Détails → NIC → MAC*) |
| Un service de srv-int ne répond pas sur 10.1.20.10 | Service démarré hors de l'espace `srvint` | `sudo systemctl restart <service>` ; `sudo ip netns exec srvint ss -tlnp` doit le montrer |
| Les VM ne se voient plus après installation de Docker sur l'hôte | `br_netfilter` filtre les ponts | `sudo modprobe -r br_netfilter`, ou désinstallez Docker de l'hôte |
| L'IPsec du TP6 ne monte pas | ESP filtré | Vérifiez que pfSense et `externe` sont bien tous deux sur `lab-wan` ; rien d'autre à régler côté hôte |

---

[Sommaire](../README.md)
