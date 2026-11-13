# Préparation réseau des environnements Hexceos

Le routeur de la plateforme Hexceos (10.10.0.1, et .254 sur chaque réseau interne) route entre tous les réseaux du lab. Pour que tout le trafic passe par pfSense, chaque VM est configurée avec une route par défaut et un DNS fixes.

| VM | Adresse | Passerelle | Route en plus | DNS |
| --- | --- | --- | --- | --- |
| Kali | 10.1.10.10/24 (eth1), eth0 coupée | 10.1.10.1 | — | 10.1.10.1 |
| srv-int | 10.1.20.10/24 | 10.1.20.1 | — | 10.1.20.1 |
| web | 10.1.30.10/24 | 10.1.30.1 | — | 10.1.30.1 |
| cloud-gw | 10.10.0.30/24 | 10.10.0.1 | 10.1.0.0/16 via 10.10.0.20 | 10.10.0.1 |
| ext | 10.10.0.40/24 | 10.10.0.1 | 10.1.0.0/16 via 10.10.0.20 | 10.10.0.1 |

Sur chaque VM, après avoir configuré pfSense :

```bash
curl -fsSL https://raw.githubusercontent.com/tahero-madi/securite-reseau/main/hexceos/reseau.sh | sudo bash
```

Sur srv-int et web, qui ne sortent pas encore sur Internet, ajouter d'abord une route temporaire : `sudo ip route replace default via 10.1.20.1` (10.1.30.1 sur web).

Le script reconnaît la machine à son adresse, écrit la configuration (netplan sur Ubuntu, NetworkManager sur Kali), désactive la gestion du réseau par cloud-init et IPv6, puis affiche une ligne OK ou KO par vérification. La configuration d'origine est gardée dans `/root/netplan-origine/`.
