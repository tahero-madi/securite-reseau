# Installation de pfSense CE dans la VM « fw »

À faire **une seule fois, sur la VM modèle** (Hexceos clone ensuite le modèle pour chaque apprenant). Durée : 15 à 20 minutes.

## 0. Récupérer l'installateur

pfSense CE s'installe avec le **Netgate Installer** (installation en ligne). L'image se télécharge gratuitement depuis la boutique Netgate (shop.netgate.com, article « pfSense CE », prix 0 €, compte Netgate requis). Prenez la version **AMD64 / ISO**. Fichier obtenu : `netgate-installer-amd64.iso.gz`.

Déposez-le sur la VM (navigateur de la VM, ou transfert de fichiers de la console Hexceos), puis :

```
sudo ./05-pfsense.sh ~/Téléchargements/netgate-installer-amd64.iso.gz
lab console fw
```

## 1. Installateur Netgate

Cartes de la VM (dans l'ordre) :

| Carte | MAC | Pont | Rôle |
|---|---|---|---|
| vtnet0 | 52:54:00:30:20:01 | lab-wan | WAN |
| vtnet1 | 52:54:00:30:20:02 | lab-lan | LAN |
| vtnet2 | 52:54:00:30:20:03 | lab-srv | OPT1 → SRV |
| vtnet3 | 52:54:00:30:20:04 | lab-dmz | OPT2 → DMZ |

1. Acceptez la notice, choisissez **Install**.
2. **Interface WAN** : `vtnet0`, mode **Static** :
   adresse `203.0.113.11/24`, passerelle `203.0.113.254`, DNS `1.1.1.1`.
3. **Interface LAN** : `vtnet1`, adresse `10.1.10.1/24`, **serveur DHCP désactivé**.
4. L'installateur vérifie l'accès Internet (via le « FAI » de la VM hôte), puis propose les éditions : choisissez **Install CE** et la **dernière version stable**.
5. Disque : options par défaut (ZFS, `vtbd0`). Validez, laissez télécharger et installer, puis **Reboot**.

> Si l'installateur ne joint pas Internet : sur la VM, `systemctl status lab-net` et `sudo iptables -t nat -L POSTROUTING -n` (une règle MASQUERADE pour 203.0.113.0/24 doit exister).

## 2. Console pfSense (après redémarrage)

Menu console :

- **1) Assign Interfaces** : VLANs → `n` ; WAN `vtnet0` ; LAN `vtnet1` ; Optional 1 `vtnet2` ; Optional 2 `vtnet3` ; confirmez `y`.
- **2) Set interface(s) IP address** :
  - OPT1 (`vtnet2`) : `10.1.20.1`, masque `24`, pas de passerelle, pas d'IPv6, **pas de DHCP**.
  - OPT2 (`vtnet3`) : `10.1.30.1`, masque `24`, pas de passerelle, pas d'IPv6, **pas de DHCP**.
  - Vérifiez que LAN = `10.1.10.1/24` et WAN = `203.0.113.11/24`.

Puis éjectez l'ISO depuis la VM hôte :

```
virsh -c qemu:///system domblklist fw          # repérer le lecteur (sda ou hdc)
sudo virsh change-media fw sda --eject
```

## 3. Interface web (depuis le navigateur de la VM)

Ouvrez `https://10.1.10.1` (acceptez le certificat), compte `admin` / `pfsense`.

**Assistant (Setup Wizard)** :

| Écran | Valeur |
|---|---|
| Hostname / Domain | `fw` / `lab.local` |
| DNS | `1.1.1.1`, `9.9.9.9` ; décocher « Override DNS » |
| Time server / Timezone | `pool.ntp.org` / **`Etc/UTC`** |
| WAN | conserver Static `203.0.113.11/24`, passerelle `203.0.113.254` ; **décocher « Block bogon networks »** (203.0.113.0/24 est une plage de documentation, classée « bogon ») ; laisser « Block RFC1918 » coché |
| LAN | `10.1.10.1/24` |
| Admin password | valeur `PW_PFSENSE` de `lab.conf` (changée par l'apprenant au TP 1) |

**Interfaces** :
- *Interfaces → OPT1* : *Enable*, description **SRV**, Save, Apply.
- *Interfaces → OPT2* : *Enable*, description **DMZ**, Save, Apply.

**État initial volontairement perfectible** (durci par les apprenants au TP 3) :
- *Firewall → Rules → SRV* : *Add* — Action Pass, Protocol **Any**, Source *SRV subnets*, Destination *any*, description `TEMPORAIRE - a remplacer au TP 3`.
- *Firewall → Rules → DMZ* : même règle avec *DMZ subnets*.
- LAN : conserver la règle par défaut « Default allow LAN to any ».
- Ne pas activer SNMP, ne pas installer Suricata (faits en TP).

**Réglages techniques** :
- *System → Advanced → Networking* : cocher **Disable hardware checksum offloading** (cartes virtio), Save, puis redémarrer pfSense.
- *Services → DNS Resolver* : actif (valeur par défaut) — c'est le DNS des machines du lab.

## 4. Contrôle et instantané

Sur la VM :

```
sudo ./99-verif.sh                  # tout doit être [OK], sauf le flux Greenbone s'il charge encore
sudo lab instantane initial         # instantané de fw + de tous les conteneurs
```

Le paquet **Suricata** s'installe pendant le TP 5 depuis le gestionnaire de paquets (accès Internet par le WAN). Pour gagner du temps le jour J, vous pouvez l'installer sur le modèle **sans l'activer sur aucune interface**, puis refaire l'instantané.
