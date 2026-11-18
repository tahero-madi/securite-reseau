# Corrigé du TP5

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

**Préparation.** Le rôle « Internet » est tenu par `ext` (10.10.0.40), qui a une route vers `10.1.0.0/16` par pfSense. La première mise à jour ET Open télécharge quelques dizaines de mégaoctets.

**Gestion du temps (1 h).** Faire lancer l'étape 1 (installation du paquet et téléchargement des règles, 3 à 5 minutes d'attente) pendant la fin de l'apport théorique du module 5. Passer vérifier *Home Net* et *Pass List* sur chaque écran à la fin de l'étape 3 : c'est la seule erreur qui fait perdre beaucoup de temps, car elle ne se voit qu'à l'étape 6. Le réglage d'un faux positif (`suppress`) est passé en défi : le montrer en démonstration (3 minutes) si le temps le permet, c'est la compétence la plus utile en exploitation. Rappeler en fin de TP de retirer la publication du port 80 et de repasser Suricata en détection seule.

## Étape 1 — Installation et règles

*Updates* doit afficher une date du jour en face de *Emerging Threats Open Rules*. Si le téléchargement échoue : résolution DNS ou accès Internet de pfSense (*Diagnostics → Ping* vers `rules.emergingthreats.net`).

## Étape 2 — `HOME_NET`, le piège du laboratoire

Le WAN est en adresses privées (10.10.0.0/24). Par défaut, pfSense met dans `HOME_NET` tous les réseaux connectés, WAN compris, et dans la *Pass List* les réseaux locaux et la passerelle. Conséquences :

- `ext` est « interne » : les règles `$EXTERNAL_NET → $HOME_NET` ne se déclenchent pas contre lui ;
- en mode blocage, `ext` ne serait jamais bloqué, puisqu'il est dans la *Pass List*.

Il faut aussi `10.10.0.20` dans `HOME_NET` : la sonde est sur la carte WAN et voit les paquets **avant** la traduction d'adresses (destination 10.10.0.20, pas 10.1.30.10). Avec seulement `10.1.0.0/16`, une attaque `ext → 10.10.0.20` va d'une adresse « externe » à une autre, et aucune règle `→ $HOME_NET` ne s'applique.

Contenu attendu :

| Objet | Contenu |
|---|---|
| Alias `N_LAB` | `10.1.0.0/16`, `10.10.0.20/32` |
| Pass List `lab_home` | Cases auto-générées toutes décochées, alias `N_LAB` |
| Instance WAN | *Home Net* = `lab_home`, *External Net* = `default`, *Pass List* = `lab_home` |

C'est l'occasion de montrer qu'une variable mal définie rend un IDS aveugle **sans aucun message d'erreur**.

## Étape 3 — Instance WAN

Catégories `emerging-scan` et `emerging-web_server` ; état vert dans *Interfaces* ; `suricata.log` se termine par `Engine started`. Si le démarrage échoue : mémoire insuffisante ou règle invalide (le journal donne le fichier et la ligne).

## Étapes 4 à 6 — Premières alertes

- `.git/config` renvoie le fichier de configuration du dépôt, avec l'adresse `https://deploy:Deploy2019!@git.lab.local/intranet.git` : un identifiant et un mot de passe en clair. Constat **critique** pour le TP8 (exposition d'un secret, ISO 27002 8.4 et 8.12).
- L'injection renvoie en général `200` : la page d'accueil ignore le paramètre. Le code ne dit rien de la réussite d'une injection ; c'est l'alerte qui compte.
- Selon les catégories, ET Open produit des alertes de balayage (`ET SCAN …`) et éventuellement web. Si aucune alerte ET ne correspond à l'injection, ce n'est pas grave : les règles de l'étape 7 correspondent à coup sûr.
- Dans *Alerts*, la source est `10.10.0.40` et la destination `10.10.0.20` (avant traduction).

## Étapes 7 et 8 — Règles personnalisées

Les deux règles `LAB …` (9000001 `.git`, 9000002 injection) apparaissent dans *Alerts*. Erreurs classiques :

- `sid` en double : Suricata ne démarre pas ;
- règle saisie mais instance non redémarrée ;
- règle sur la mauvaise interface ;
- sens du flux inversé (`to_client` au lieu de `to_server`).

Montrer la structure action / en-tête / options, et l'intérêt des *sticky buffers* (`http.uri` : adresse décodée et normalisée, `%20` devient un espace) par rapport à un `content` sur le paquet brut, qui ne verrait que `%20OR%20`.

## Étape 9 — Blocage

Réglage attendu : *Block Offenders* coché, *Legacy Mode*, *Kill States* coché, *Block On DROP Only* coché, *Which IP to Block* = `SRC`, règle 9000001 en `drop` (`rev:2`).

- La première requête vers `/.git/config` peut encore aboutir (mode Legacy : copie des paquets, blocage après coup).
- La requête suivante vers `/` échoue (code `000`) : c'est l'adresse de `ext` qui est bloquée, pour tout trafic.
- *Blocks* affiche `10.10.0.40` et le message de la règle 9000001.
- La session SSH Kali → `ext` se fige : elle passe par pfSense (traduite en 10.10.0.20 → 10.10.0.40) et *Kill States* l'a coupée.

Pourquoi *Block On DROP Only* : sans lui, en mode Legacy, **toute** alerte bloque sa source, y compris une alerte `ET POLICY` sur une mise à jour légitime. Avec *Which IP to Block* = `BOTH`, on risque même de bloquer la passerelle ou un serveur de mises à jour. Insister : un faux positif en IPS coupe un flux légitime, d'où le réglage avant tout blocage généralisé.

Mode *Inline* : la règle `drop` supprime le paquet lui-même et seulement lui, sans bloquer l'adresse. Il exige une carte compatible *netmap* ; sur des cartes virtuelles, il peut être instable, d'où le choix de Legacy dans le laboratoire.

## Étape 10 — Remise en ordre

- Publication du port 80 supprimée ; depuis `ext`, `curl` vers `http://10.10.0.20/` renvoie `000`.
- *Block Offenders* décoché, instance toujours démarrée (détection seule) : les alertes alimenteront le TP7.

## Défi ★ — Balayage et réglage d'un faux positif

La règle 9000003 (`flags:S,12` + `detection_filter … count 30, seconds 10`) alerte sur le `nmap --top-ports 100` de l'étape 5. Liste `wan_suppress` :

```text
suppress gen_id 1, sig_id 9000003, track by_src, ip 10.10.0.40
```

associée à l'instance WAN (*Alert Suppression and Filtering*), instance redémarrée. Le balayage depuis `ext` ne produit plus 9000003 ; l'injection produit toujours 9000002.

Une bonne note de réglage contient : la règle, l'exception (portée **minimale** : une règle, une source), la justification (scanner autorisé par contrat), le responsable et la date de revue. Le `suppress` cible une règle pour une source précise, la protection reste active pour toutes les autres ; désactiver la règle la supprime partout. Le `threshold … type limit` garde une trace (une alerte par période) au lieu de tout taire.

## Défi ★★ — Instance DMZ

Instance DMZ : `HOME_NET` = `10.1.0.0/16` (tout le site), ou au moins `10.1.20.0/24` pour que la règle de rebond ait un sens. Exemple :

```text
alert tcp 10.1.30.10 any -> 10.1.20.0/24 any (msg:"LAB Rebond DMZ vers SRV"; flags:S,12; classtype:attempted-admin; sid:9000010; rev:1;)
```

La sonde WAN ne voit que ce qui traverse la carte WAN ; une sonde sur la DMZ voit les tentatives de déplacement latéral d'un serveur compromis vers l'interne, même quand le pare-feu les refuse. Lien avec la détection du mouvement latéral (modules 1 et 5), et avec la capture d'incident du TP7.

## Questions

1. La sonde WAN voit les paquets avant la traduction d'adresses : une attaque contre le service publié vise `10.10.0.20`. Sans cette adresse dans `HOME_NET`, la destination est « externe » et aucune règle `→ $HOME_NET` ne s'applique.
2. Pour éviter de bloquer du trafic légitime (faux positifs) tant que les règles ne sont pas réglées : on valide d'abord en observation.
3. Désactiver : la règle ne s'applique plus nulle part (perte de couverture). `suppress` : la règle reste active, on ignore seulement ses correspondances pour une source identifiée comme légitime.
4. Le trafic au sein d'un même réseau est commuté directement entre les deux machines, sans passer par le pare-feu où se trouve la sonde.

---

[← TP4](../../tp4/README.md) · [Sommaire](../../README.md) · [Énoncé](../README.md) · [En cas de blocage](../../en-cas-de-blocage.md) · [TP6 →](../../tp6/README.md)
