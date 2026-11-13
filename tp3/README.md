# TP3 — Cloisonnement et filtrage avec pfSense

**Jour 2, 10:20 · 1 h 40.** Objectifs : mettre en œuvre un zonage LAN/SRV/DMZ sur pfSense ; traduire une matrice de flux en règles « refus par défaut » ; configurer le NAT de publication ; activer la journalisation ; vérifier le cloisonnement par des tests de flux.

**Prérequis** : module 3, TP 1. **Livrable** : une `matrice-flux` documentée + l'export de configuration des règles (capture ou XML) + un tableau de tests de flux (attendu/obtenu).

## Partie A — État des lieux et matrice (15 min)

1. Sur `fw` (https://10.1.10.1), repérez les interfaces : WAN, LAN (10.1.10.1), SRV (10.1.20.1), DMZ (10.1.30.1). Dans *Firewall → Rules*, observez les règles existantes (souvent une règle LAN « autoriser tout » par défaut : à restreindre).
2. Rédigez votre `matrice-flux` cible. Exigences minimales :
   - LAN (postes utilisateurs, dont `client`) → DMZ web (`web`) en 80/443 ; LAN → Internet via le pare-feu ;
   - **poste d'administration** (`10.1.10.10`, votre poste) → SRV et DMZ en SSH, LDAP(S) ; et, parce qu'il héberge les outils, → SRV/DMZ pour le scanner (TP 2) et la supervision (agent Zabbix 10050) ;
   - SRV → poste `10.1.10.10` en TCP 10051 (agents Zabbix actifs, TP 7) ;
   - DMZ → SRV **interdit** sauf un flux précis justifié (ou aucun) ;
   - SRV → Internet **interdit** sauf mises à jour ;
   - Internet (WAN) → DMZ web en 443 uniquement (publication) ;
   - tout le reste refusé et **journalisé**.

## Partie B — Alias et règles (35 min)

3. Créez des **alias** (*Firewall → Aliases*) pour les hôtes et groupes de ports : `H_poste_admin` (10.1.10.10), `H_web`, `H_srv_int`, `N_LAN`, `N_SRV`, `N_DMZ`, `P_web` (80,443), `P_admin` (22,443,389,636). Les alias rendent les règles lisibles et maintenables.
4. Sur l'interface **LAN**, remplacez la règle « autoriser tout » par des règles précises conformes à la matrice. Exemple de logique (une règle par ligne de matrice), en terminant par une règle de **blocage journalisé** `N_LAN → any` (log coché). Ordre : les règles passantes d'abord, le blocage final ensuite.
5. Sur l'interface **DMZ**, créez les règles : `N_DMZ → any` vers Internet refusé sauf si justifié ; `N_DMZ → N_SRV` refusé et journalisé ; autoriser uniquement ce que la matrice prévoit. La DMZ ne doit pas joindre le LAN.
6. Sur l'interface **SRV**, autorisez SRV → dépôts de mises à jour (ou via un proxy) et refusez le reste vers Internet ; journalisez.
7. **Protection de l'administration** : dans *System → Advanced → Admin Access*, restreignez l'accès à la GUI au seul poste d'administration `H_poste_admin` (règle LAN explicite, puis désactivation de la règle anti-verrouillage) ; activez le renvoi HTTPS ; (si disponible) limitez par règle anti-verrouillage. Vérifiez que la GUI n'est pas joignable depuis la DMZ.

> **Ne vous enfermez pas dehors.** Avant de durcir l'accès d'administration, gardez une session ouverte et testez depuis un autre onglet. En cas de blocage : `lab console fw` ouvre la console de pfSense (option 4 : remise à zéro, option 8 : shell avec `pfctl -d` pour désactiver le filtrage le temps de corriger), ou `lab restaurer avant-tp3 fw` si vous avez pris l'instantané.

## Partie C — NAT de publication (15 min)

8. Publiez `web` : *Firewall → NAT → Port Forward*, WAN, destination port 443 → cible `10.1.30.10:443`. pfSense propose de créer la règle de filtrage associée : vérifiez qu'elle n'autorise **que** 443 depuis WAN vers `H_web`.
9. Testez depuis **Internet**, c'est-à-dire depuis la machine `ext` (203.0.113.31) :

```bash
ssh stagiaire@203.0.113.31
curl -kI https://203.0.113.11          # doit répondre : nginx de web
nc -vz -w3 203.0.113.11 22             # doit échouer
nc -vz -w3 203.0.113.11 80             # doit échouer
```

Remarque : la publication de 443 masque désormais la GUI de pfSense côté WAN (le NAT passe avant), ce qui est souhaitable.

## Partie D — Vérifier le cloisonnement (20 min)

10. Construisez un tableau de tests (attendu/obtenu) et exécutez-les depuis les bonnes sources :

| Depuis | Vers | Port | Attendu |
|---|---|---|---|
| poste (LAN, admin) | web (DMZ) | 443 | Autorisé |
| poste (LAN, admin) | srv-int (SRV) | 22 | Autorisé |
| client (LAN, utilisateur) | srv-int (SRV) | 22 | Refusé |
| web (DMZ) | srv-int (SRV) | 22 | Refusé |
| web (DMZ) | poste (LAN) | tout | Refusé |
| srv-int (SRV) | Internet | 443 | Refusé (sauf dépôt) |
| ext (WAN) | 203.0.113.11 | 22 | Refusé |
| ext (WAN) | 203.0.113.11 | 443 | Autorisé (web) |

Pour tester un flux, connectez-vous à la machine source (`ssh stagiaire@10.1.30.10` pour web, `ssh stagiaire@10.1.10.20` pour client…) et utilisez `nc -vz -w3 <ip> <port>`. Si une règle vous empêche d'y entrer en SSH, `lab shell <machine>` ouvre un terminal sans passer par le réseau. Consultez *Status → System Logs → Firewall* : vos refus apparaissent, horodatés. Filtrez par interface.

> **Défi ★.** Ajoutez un VLAN invité (interface virtuelle, par exemple VLAN 90) isolé : accès Internet seulement, aucun accès aux autres zones. Vérifiez l'isolation. Discutez de la sécurité L2 nécessaire sur le commutateur pour que ce VLAN tienne réellement.

**Livrable** : `matrice-flux`, export des règles, tableau de tests complété.

## Questions de validation

1. Pourquoi la règle de blocage final doit-elle être journalisée ?
2. Le port forward crée l'accès ; qu'est-ce qui assure réellement la sécurité du service publié ?
3. Un collègue propose une règle `N_LAN → any: any` « pour simplifier ». Que répondez-vous ?

---

[← TP2](../tp2/README.md) · [Sommaire](../README.md) · [Corrigé](corrige/README.md) · [En cas de blocage](../en-cas-de-blocage.md) · [TP4 →](../tp4/README.md)
