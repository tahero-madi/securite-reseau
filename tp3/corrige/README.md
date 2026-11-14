# Corrigé du TP3

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

**Points de vigilance.** pfSense évalue les règles **par interface**, sur le trafic **entrant** dans cette interface, première correspondance gagnante, avec un refus implicite final (non journalisé par défaut → d'où la règle de blocage explicite journalisée). Une règle pour le flux LAN → DMZ s'écrit donc sur l'interface **LAN**.

**Étape 1.** Les règles « HRA : tout autoriser » sur le **WAN** signifient que toute machine d'Internet (ici `ext`) joint tout ce que pfSense route : pfSense lui-même, et les réseaux internes. C'est le constat de départ : un pare-feu livré grand ouvert ne filtre rien.

La matrice complète est celle des étapes 5 à 9 de l'énoncé (L1 à L10, S1 à S5, D1 à D4, W1). Points à faire justifier par les apprenants :

- **Ordre** : les services de pfSense (L1 à L3), puis l'administration (L4 à L6), puis les flux utilisateurs (L7 à L9), et le blocage journalisé en dernier. Entre règles « Pass », l'ordre ne change pas le résultat ; il compte dès qu'une règle « Block » s'intercale.
- **« LAN address » plutôt que « This Firewall (self) »** : *self* désigne **toutes** les adresses de pfSense, WAN comprise.
- **DNS en TCP/UDP** : en TCP seul, la plupart des requêtes (UDP) sont refusées dès que le blocage final est en place.
- **L5, le scanner** : volontairement large, et désactivée hors des campagnes de scan (TP 2, TP 8) — un scanner est un outil d'attaque.
- **L9, `! N_PRIVE`** : la navigation Internet est ouverte à tout le LAN, mais pas les réseaux internes ; les droits internes du poste d'administration passent par des règles nominatives.
- **S3 et D3** : seules sorties de SRV et DMZ, vers les dépôts. Le flux syslog web → srv-int du TP 7 viendra s'insérer avant D4 : c'est le « flux justifié » de la DMZ.

**Étapes 3 à 8.** Erreurs classiques :
- garder les règles HRA en plus des nouvelles : en tête de liste, elles masquent tout ;
- oublier DNS et NTP vers pfSense : les machines ne résolvent plus rien, `apt` échoue, l'horloge dérive ;
- oublier les règles IPv6 HRA : un réseau « fermé » en IPv4 reste ouvert en IPv6 ;
- placer la règle de blocage avant les règles passantes ;
- mettre le DNS en TCP seul ;
- oublier d'appliquer : les règles ne prennent effet qu'après **Apply Changes** ;
- oublier la DMZ dans les droits d'administration de la Kali (plus de SSH vers web).

L'alias de noms pour les dépôts (`archive.ubuntu.com`…) est résolu périodiquement par pfSense ; si `apt update` échoue sur une adresse, c'est qu'elle a changé depuis la dernière résolution. En production, on passe plutôt par un miroir ou un proxy interne.

Admin access : montrer depuis `web` que `https://10.1.30.1` ne répond pas, et depuis l'adresse 10.1.10.20 que `https://10.1.10.1` ne répond plus. Point d'architecture : le poste d'administration est ici dans le LAN utilisateurs, faute de zone d'administration dédiée ; on compense par des règles nominatives (`H_poste_admin`) — un auditeur le relèvera au TP 8.

**Pour le formateur.** La suppression des règles HRA du WAN ne gêne pas la console du portail Hexceos (accès à l'écran de la VM, pas par le réseau). Si la plateforme utilisait un accès réseau à pfSense pour sa supervision, il faudrait le savoir avant le TP : à tester sur un environnement.

**Étape 9.** Le port forward (NAT) et la règle de filtrage sont deux choses distinctes : insister. La sécurité vient de la règle (443 uniquement, destination = alias du serveur), pas du NAT. En IPv6, pas de NAT : seule la règle compte.

**« À méditer ».** Avec la règle associée par défaut, `ext` joint `10.1.30.10:443` directement : pfSense filtre après traduction, donc la règle autorise « vers 10.1.30.10:443 », quelle que soit l'adresse visée au départ. `ext` peut le faire parce qu'il a une route vers 10.1.0.0/16 par pfSense (comme le ferait un voisin de segment). Avec *Filter rule association* = **Pass**, pfSense laisse passer ce qui a été traduit par la règle NAT, sans règle de filtrage : le trafic direct vers l'adresse privée tombe sur le refus par défaut. Contrepartie : plus de règle de filtrage, donc plus de compteurs ni de journalisation propre à ce flux.

**Étapes 11 et 12.** Les tests doivent tous passer comme « attendu ». Si DMZ → SRV est autorisé par erreur, c'est le constat pédagogique majeur : une segmentation annoncée mais non filtrée ne vaut rien. Les journaux du pare-feu montrent les refus → lien avec la journalisation (module 7). L'adresse 10.1.10.20 ajoutée à la Kali simule un poste utilisateur : pfSense ne connaît que l'adresse source, il applique donc les règles « utilisateur ».

**Questions.** 1 : pour détecter les tentatives et disposer de preuves ; un refus silencieux ne laisse aucune trace. 2 : la règle de filtrage associée (port et destination restreints) et le durcissement du service lui-même ; le NAT ne filtre pas. 3 : refuser : `any:any` supprime tout le cloisonnement sortant (canal de C2 et d'exfiltration ouvert), empêche la détection et contrevient au moindre privilège ; proposer des règles précises par besoin.

---

[← TP2](../../tp2/README.md) · [Sommaire](../../README.md) · [Énoncé](../README.md) · [En cas de blocage](../../en-cas-de-blocage.md) · [TP4 →](../../tp4/README.md)
