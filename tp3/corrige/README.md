# Corrigé du TP3

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

**Points de vigilance.** pfSense évalue les règles **par interface**, sur le trafic **entrant** dans cette interface, première correspondance gagnante, avec un refus implicite final (non journalisé par défaut → d'où la règle de blocage explicite journalisée). Rappeler que les règles s'appliquent au trafic qui *entre* par l'interface depuis le réseau nommé.

**Partie B.** Erreurs classiques : laisser la règle LAN par défaut « allow all » en plus des nouvelles (elle masque tout) ; oublier que sans règle DMZ→SRV explicitement refusée et journalisée, on ne verra pas les tentatives ; placer la règle de blocage avant les règles passantes. Vérifier l'ordre.

Admin access : la restriction se fait dans System → Advanced. Garder la règle anti-lockout ou une règle LAN-admin explicite. Montrer depuis `web` que `https://10.1.30.1` ne répond pas, et depuis `client` que `https://10.1.10.1` ne répond plus une fois l'admin restreinte à 10.1.10.10. Point d'architecture à souligner : le poste d'administration est ici dans le LAN utilisateurs, faute de zone d'administration dédiée ; on compense par des règles nominatives (`H_poste_admin`) — un auditeur le relèvera au TP 8.

**Partie C.** Le port forward NAT et la règle de filtrage sont deux choses distinctes : insister. La sécurité vient de la règle (443 uniquement, destination = alias du serveur), pas du NAT. En IPv6, pas de NAT : seule la règle compte.

**Partie D.** Les tests doivent tous passer comme « attendu ». Si DMZ→SRV est autorisé par erreur, c'est le constat pédagogique majeur : une segmentation annoncée mais non filtrée ne vaut rien. Les logs firewall montrent les refus → lien avec la journalisation (module 7).

**Questions.** 1 : pour détecter les tentatives et disposer de preuves ; un refus silencieux ne laisse aucune trace. 2 : la règle de filtrage associée (port et destination restreints) ; le NAT ne filtre pas. 3 : refuser : `any:any` supprime tout le cloisonnement sortant (canal de C2 et d'exfiltration ouvert), empêche la détection et contrevient au moindre privilège ; proposer des règles précises par besoin.

---

[← TP2](../../tp2/README.md) · [Sommaire](../../README.md) · [Énoncé](../README.md) · [En cas de blocage](../../en-cas-de-blocage.md) · [TP4 →](../../tp4/README.md)
