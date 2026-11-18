# TP8 — Audit de sécurité réseau et rapport

**Jour 4, 13:35 · 1 h 45, pause incluse.** Objectifs : conduire l'audit complet de votre propre laboratoire (architecture, configuration, vérification active) ; prouver chaque constat ; le coter et le relier à un référentiel ; produire un rapport d'audit exploitable par une direction et par une équipe technique. Ce TP fait la synthèse de toute la formation.

**Prérequis** : modules 1 à 8 et tous les TP. **Périmètre** : votre laboratoire uniquement, selon le mandat. **Livrable** : `rapport-audit.md` (synthèse pour la direction, constats cotés et prouvés, plan d'action priorisé) et le dossier `preuves/`, dans `~/livrables`.

**Déroulé** : étapes 1 à 3 (mandat, préparation, collecte) 15 min · étape 4 (architecture) 10 min · étapes 5 à 9 (configurations) 25 min · étapes 10 à 13 (vérification active) 20 min · étapes 14 et 15 (cotation et rapport) 20 min.

## Mise en situation

Vous intervenez comme auditeur sur le système d'information d'une PME, reproduit par votre laboratoire. Vous êtes en **boîte blanche** : vous avez accès aux configurations et aux comptes d'administration. Votre client attend un rapport qui lui dise, preuves à l'appui, où il en est et par quoi commencer.

## Étape 1 — Lire le mandat

**Pourquoi.** Sans autorisation écrite, un audit est une intrusion, pénalement sanctionnée (articles 323-1 et suivants du Code pénal). Le mandat fixe ce que vous avez le droit de tester, ce qui est interdit, et qui prévenir en cas de problème. Un auditeur qui sort de son périmètre engage sa responsabilité, même avec de bonnes intentions.

```bash
xdg-open ~/TP/mandat-audit-TP8.pdf
```

- `xdg-open` : ouvre le fichier avec le lecteur PDF par défaut.

Relevez :

- **dans le périmètre** : vos six machines ; les réseaux LAN, SRV, DMZ et le VPC ; sur l'« Internet simulé », 10.10.0.20 (pfSense), 10.10.0.30 (`cloud-gw`) et 10.10.0.40 (`ext`) ;
- **hors périmètre** : l'infrastructure de la plateforme (10.10.0.1 et les adresses en `.254`), qui peut être documentée mais pas testée sans accord explicite ;
- **interdit** : toute action destructrice (déni de service, modification de données, exploitation au-delà de la preuve).

Signez le mandat (nom et date dans le document, ou sur papier selon les consignes du formateur).

## Étape 2 — Préparer le rapport et le dossier de preuves

**Pourquoi.** Chaque constat du rapport doit renvoyer à une preuve : une sortie de commande, une capture d'écran, un extrait de configuration. On range les preuves au fur et à mesure, avec des noms explicites, plutôt que de les reconstituer à la fin.

```bash
mkdir -p ~/livrables/preuves
cd ~/livrables
curl -fsSLO https://raw.githubusercontent.com/tahero-madi/securite-reseau/main/tp8/modeles/rapport-audit.md
mousepad rapport-audit.md &
```

**Ligne par ligne.**

- `mkdir -p ~/livrables/preuves` : crée le dossier des preuves (`-p` : sans erreur s'il existe déjà).
- `curl -fsSLO <adresse>` : télécharge le modèle du rapport et garde son nom.
- `mousepad rapport-audit.md &` : l'ouvre dans l'éditeur, en arrière-plan.

## Étape 3 — Collecter la documentation

**Pourquoi.** L'audit compare ce qui **devrait** être (la documentation) à ce qui **est** (la configuration et le comportement réels). On commence donc par rassembler la documentation : vos livrables des TP précédents jouent le rôle de la documentation du client.

```bash
ls ~/livrables
```

- `ls ~/livrables` : liste vos livrables. Repérez la cartographie et l'inventaire (TP1), le rapport de vulnérabilités (TP2), la matrice de flux (TP3), les traces RADIUS (TP4), les règles Suricata (TP5), l'état du tunnel et la capture prouvant le chiffrement (TP6).

Exportez la configuration de pfSense : *Diagnostics → Backup & Restore*, *Backup area* `All`, *Download configuration as XML*. Rangez le fichier dans `~/livrables/preuves/`.

> **Confidentialité.** Cette sauvegarde contient des secrets (empreintes de mots de passe, clé IPsec, secret RADIUS). Dans un vrai audit, elle se transmet et se conserve chiffrée, et se détruit en fin de mission, comme le prévoit le mandat.

## Étape 4 — Auditer l'architecture

**Pourquoi.** Avant le détail des configurations, on vérifie les grands principes du module 3 : des zones de confiance séparées, des flux limités entre elles, une administration protégée, une traçabilité. Une architecture mal conçue ne se rattrape pas avec de bons réglages.

Remplissez la grille de la section 3 du rapport. Pour chaque point, indiquez *Conforme*, *Partiel* ou *Non conforme*, et la preuve (règle, schéma, test). Les étapes suivantes vous fourniront une partie des preuves : revenez compléter la grille au fur et à mesure.

| Point de contrôle | Où chercher |
|---|---|
| Zones de confiance définies et cloisonnées | Cartographie (TP1), interfaces de pfSense |
| DMZ : flux entrants terminés en DMZ, DMZ → interne restreint | Règles W1 et DMZ |
| Filtrage sortant en place | Règles L9, S3, D3 ; refus par défaut |
| Administration isolée, protocoles chiffrés | Règles L1, L4 ; poste d'administration dans le LAN des utilisateurs ? |
| Services d'infrastructure protégés (LDAP chiffré, SNMPv3, RADIUS) | Étape 9 |
| Interconnexion cloud chiffrée et filtrée | TP6, étape 8 |
| Journalisation centralisée et horodatée | TP7 |
| IPv6 pris en compte ou neutralisé | Règles de refus en IPv4+IPv6 ? |
| Aucun chemin ne contourne le pare-feu | Équipements en `.254` (TP1), étape 12 |

## Étape 5 — Auditer les règles du pare-feu

**Pourquoi.** Les règles de pare-feu dérivent avec le temps : ouvertures « temporaires » jamais refermées, règles `any` ajoutées pour dépanner, règles devenues inutiles. Les compteurs de pfSense indiquent combien de paquets chaque règle a laissé passer : une règle jamais utilisée est candidate à la suppression.

Dans pfSense, *Diagnostics → Command Prompt*, champ *Execute Shell Command* :

```bash
pfctl -vsr
```

**Ligne par ligne.**

- `pfctl -sr` : affiche toutes les règles chargées dans le filtre, y compris celles que pfSense génère lui-même (anti-verrouillage, règles IPsec automatiques, règles associées aux redirections).
- `-v` : ajoute sous chaque règle ses compteurs : `Evaluations` (combien de fois elle a été examinée), `Packets` et `Bytes` (combien de paquets elle a laissé passer ou bloqué), `States` (connexions en cours).

Copiez la sortie dans `~/livrables/preuves/pfctl-vsr.txt`. Puis vérifiez :

- une règle `pass` sans restriction (`from any to any`, ou tous les ports) sur une interface ;
- des règles `pass` dont les compteurs `Packets` sont à 0 : inutilisées depuis le dernier chargement ;
- le refus par défaut journalisé (mot-clé `log`) en fin de chaque interface ;
- la règle d'anti-verrouillage (`anti-lockout`) : active ou désactivée ? (*System → Advanced → Admin Access*) ;
- les redirections : *Firewall → NAT → Port Forward* ne doit plus contenir que W1 (la publication temporaire du TP5 a-t-elle été retirée ?).

Dans *Firewall → Rules*, la colonne *States* donne la même information par interface, de façon plus lisible.

## Étape 6 — Auditer le TLS du serveur web

**Pourquoi.** Le chiffrement d'un service n'est utile que s'il repose sur des versions et des algorithmes encore sûrs, et sur un certificat que les clients peuvent vérifier. TLS 1.0 et 1.1 sont interdits par les guides de l'ANSSI et par PCI DSS.

Depuis la Kali :

```bash
testssl.sh --quiet --color 0 https://10.1.30.10 | tee ~/livrables/preuves/testssl-web.txt
```

**Ligne par ligne.**

- `testssl.sh` : teste les versions de TLS, les suites de chiffrement, le certificat et les vulnérabilités connues d'un service TLS.
- `--quiet` : sans la bannière de présentation.
- `--color 0` : sans codes de couleur, pour que le fichier de preuve soit lisible.
- `https://10.1.30.10` : le serveur web, joint depuis le LAN (règle L7).
- `| tee …` : affiche la sortie et l'enregistre en même temps.

> **Durée.** Le test prend **une à deux minutes**.

Dans la sortie, lisez :

- *Testing protocols* : `TLS 1` et `TLS 1.1` doivent être `not offered` ;
- *Testing cipher categories* : aucune suite `NULL`, `EXPORT`, `RC4`, `3DES` proposée ;
- *Testing server defaults* : le certificat (émetteur, validité, *Chain of trust*) ;
- *Testing vulnerabilities* : chaque ligne doit être `not vulnerable` ;
- le résumé final (*Rating*), s'il est affiché.

## Étape 7 — Auditer SSH

**Pourquoi.** SSH est la porte d'administration des serveurs. On vérifie deux choses : les algorithmes proposés (certains sont aujourd'hui faibles) et le mode d'authentification (un mot de passe peut être deviné ou volé ; une clé, beaucoup moins).

Depuis la Kali :

```bash
ssh-audit 10.1.20.10 | tee ~/livrables/preuves/ssh-audit-srv-int.txt
```

**Ligne par ligne.**

- `ssh-audit 10.1.20.10` : se connecte au service SSH de `srv-int` (règle L4) et analyse ce qu'il propose, sans s'authentifier. Sections : `(gen)` version du logiciel, `(kex)` échanges de clés, `(key)` clés d'hôte, `(enc)` chiffrements, `(mac)` intégrité, `(rec)` recommandations. Les lignes `[fail]` et `[warn]` sont des constats.

Puis, sur `srv-int`, lisez la configuration **effective** du service :

```bash
ssh formation@10.1.20.10
sudo sshd -T | grep -Ei '^(passwordauthentication|permitrootlogin|pubkeyauthentication|maxauthtries) '
```

**Ligne par ligne.**

- `sudo sshd -T` : affiche la configuration que le service applique réellement, après lecture de tous ses fichiers (y compris `sshd_config.d/`). C'est plus fiable que de lire un seul fichier.
- `grep -Ei '^(…) '` : ne garde que quatre réglages :
  - `passwordauthentication` : `yes` = connexion par mot de passe acceptée ;
  - `permitrootlogin` : connexion directe de `root` ;
  - `pubkeyauthentication` : connexion par clé ;
  - `maxauthtries` : nombre d'essais par connexion.

Faites de même sur `web` (`ssh formation@10.1.30.10`). Rappelez-vous l'alerte Zabbix du TP7 : elle détectait exactement l'attaque que permet `passwordauthentication yes`.

## Étape 8 — Auditer le VPN IPsec

**Pourquoi.** On vérifie que le tunnel du TP6 est toujours conforme aux recommandations : algorithmes, PFS, sélecteurs restreints, filtrage aux deux extrémités.

```bash
ssh -t formation@10.10.0.30 sudo swanctl --list-sas | tee ~/livrables/preuves/ipsec-sas.txt
```

**Ligne par ligne.**

- `ssh -t formation@10.10.0.30 sudo swanctl --list-sas` : exécute la commande sur `cloud-gw` sans ouvrir de session interactive. `-t` attribue un terminal, nécessaire pour que `sudo` puisse demander le mot de passe.
- `| tee …` : enregistre la sortie sur la Kali.

Vérifiez : `IKEv2`, `AES_GCM_16-256`, `PRF_HMAC_SHA2_256`, `ECP_256` (phase 1 et PFS), sélecteurs `10.101.1.0/24 ↔ 10.1.20.0/24`. Côté pfSense : règles S6 et I1 (TP6). Si le tunnel n'apparaît pas, il est peut-être simplement inactif : `start_action = trap` le remonte au premier paquet ; lancez `curl -k https://10.101.1.1` depuis `srv-int`, puis recommencez.

## Étape 9 — Auditer les services d'infrastructure

**Pourquoi.** Les services d'infrastructure (annuaire, supervision, authentification) sont rarement exposés à Internet, donc rarement durcis. Ils contiennent pourtant ce qui intéresse le plus un attaquant déjà entré : la liste des comptes, la configuration des équipements, les secrets partagés.

Les tests SNMP vers la DMZ ne sont pas autorisés par les règles du LAN. Comme pour une campagne de scan, **activez la règle L5** (scanner, *Firewall → Rules → LAN*, icône de la ligne L5, *Apply Changes*) le temps des étapes 9 à 11. Puis, depuis la Kali :

```bash
snmpwalk -v2c -c public -t 2 -r 0 10.1.30.10 system | tee ~/livrables/preuves/snmp-web.txt
ldapsearch -x -LLL -H ldap://10.1.20.10 -b "dc=lab,dc=local" "(objectClass=inetOrgPerson)" uid cn mail | tee ~/livrables/preuves/ldap-anonyme.txt
```

**Ligne par ligne.**

- `snmpwalk -v2c -c public` : interroge `web` en SNMP v2c avec la communauté par défaut `public`.
- `-t 2 -r 0` : délai de 2 secondes, sans nouvel essai.
- `10.1.30.10 system` : la branche `system` (nom, système, emplacement, contact). Si une réponse arrive, n'importe quelle machine qui joint `web` peut lire sa configuration, et la communauté circule en clair.
- `ldapsearch -x -LLL -H ldap://10.1.20.10` : interroge l'annuaire en clair, sur le port 389…
- … **sans `-D` ni `-W`** : sans s'authentifier, en anonyme.
- `-b "dc=lab,dc=local" "(objectClass=inetOrgPerson)" uid cn mail` : demande toutes les personnes. Si des entrées s'affichent, la liste des comptes est lisible par n'importe qui sur le réseau : c'est le point de départ d'une attaque par force brute ou par hameçonnage ciblé.

Puis, sur `srv-int` (session SSH) :

```bash
sudo grep -A 5 'client pfsense' /etc/freeradius/3.0/clients.conf
grep -E '^SLAPD_SERVICES' /etc/default/slapd
```

**Ligne par ligne.**

- `sudo grep -A 5 'client pfsense' …` : affiche le bloc `client pfsense` et les 5 lignes suivantes. Vérifiez `require_message_authenticator = yes` (protection contre BlastRADIUS) et la longueur du secret (ne le recopiez pas dans le rapport : notez seulement sa longueur).
- `grep -E '^SLAPD_SERVICES' /etc/default/slapd` : les modes d'écoute de l'annuaire. `ldap:///` présent = l'authentification en clair sur le port 389 est toujours possible (TP4, étape 3).

## Étape 10 — Vérifier l'exposition depuis Internet

**Pourquoi.** Le schéma dit que seul le port 443 est publié. Seul un test depuis l'extérieur le prouve : c'est la vue qu'a un attaquant.

Depuis la Kali, ouvrez une session sur `ext` :

```bash
ssh formation@10.10.0.40
sudo nmap -sS -sV -Pn --top-ports 1000 10.10.0.20 | tee ~/tp8-nmap-ext.txt
nc -vz -w 3 10.1.30.10 443
nc -vz -w 3 10.1.20.10 22
exit
scp formation@10.10.0.40:tp8-nmap-ext.txt ~/livrables/preuves/
```

**Ligne par ligne.**

- `sudo nmap -sS` : balayage SYN de l'adresse publique.
- `-sV` : pour chaque port ouvert, identifie le service et sa version.
- `-Pn` : ne vérifie pas d'abord que la machine répond au ping (pfSense ne répond pas au ping sur le WAN) ; balaye directement.
- `--top-ports 1000` : les 1 000 ports les plus courants.
- `| tee ~/tp8-nmap-ext.txt` : enregistre le résultat sur `ext`.
- `nc -vz -w 3 10.1.30.10 443` : tente de joindre `web` **directement**, par son adresse privée. `ext` a une route vers 10.1.0.0/16 par pfSense : c'est le cas d'un attaquant sur le même segment que votre accès Internet. Attendu : `timed out` (refus par défaut du WAN).
- `nc -vz -w 3 10.1.20.10 22` : même test vers `srv-int`.
- `exit` puis `scp …` : de retour sur la Kali, rapatrie le résultat du balayage.

Attendu : seul `443/tcp open` sur 10.10.0.20. Tout autre port ouvert est un constat.

## Étape 11 — Vérifier les chemins d'isolation internes

**Pourquoi.** La segmentation se prouve, elle ne se présume pas : PCI DSS exige de **tester** régulièrement que les zones sont réellement isolées. On rejoue les tests de flux du TP3 qui doivent échouer, et on balaye les zones depuis le LAN pour comparer avec l'inventaire.

Depuis `web` (session SSH depuis la Kali) :

```bash
ssh formation@10.1.30.10
nc -vz -w 3 10.1.20.10 22
nc -vz -w 3 10.1.10.10 22
exit
```

- `nc -vz -w 3 10.1.20.10 22` : `web` (la machine la plus exposée) tente d'atteindre le SSH de `srv-int`. Attendu : `timed out` (règle D4).
- `nc -vz -w 3 10.1.10.10 22` : `web` tente d'atteindre le poste d'administration. Attendu : `timed out`.

Depuis la Kali, en poste utilisateur (seconde adresse, comme au TP3) :

```bash
sudo ip addr add 10.1.10.20/24 dev eth0
nc -vz -w 3 -s 10.1.10.20 10.1.20.10 22
curl -kI -m 5 --interface 10.1.10.20 https://10.1.10.1
sudo ip addr del 10.1.10.20/24 dev eth0
```

**Ligne par ligne.**

- `sudo ip addr add 10.1.10.20/24 dev eth0` : donne à la Kali l'adresse d'un poste utilisateur, en plus de la sienne.
- `nc … -s 10.1.10.20 10.1.20.10 22` : un poste utilisateur tente le SSH de `srv-int`. Attendu : `timed out`.
- `curl -kI -m 5 --interface 10.1.10.20 https://10.1.10.1` : un poste utilisateur tente l'interface d'administration de pfSense. Attendu : échec au bout de 5 secondes (si la page répond, revoyez la règle d'anti-verrouillage : TP3).
- `sudo ip addr del …` : retire l'adresse de test.

Enfin, balayez les zones depuis le poste d'administration (règle L5 active) :

```bash
sudo nmap -sS -sV --top-ports 1000 10.1.20.10 10.1.30.10 | tee ~/livrables/preuves/nmap-zones.txt
```

- `--top-ports 1000 10.1.20.10 10.1.30.10` : les 1 000 ports les plus courants des deux serveurs.

> **Durée.** Comptez **deux à trois minutes**.

Comparez avec l'inventaire du TP1 et le rapport du TP2 : un service toujours présent alors que sa suppression était recommandée (FTP, Telnet) est un constat, avec le TP2 comme historique.

## Étape 12 — Tester le contournement par l'équipement en `.254`

**Pourquoi.** Au TP1, vous avez découvert une adresse en `.254` dans chaque réseau : un équipement de la plateforme d'hébergement, présent dans toutes les zones. S'il route entre elles, la segmentation ne repose plus sur pfSense mais sur la seule table de routage de chaque machine. Cet équipement est **hors périmètre** : le test ne se fait qu'**avec l'accord du formateur**, qui joue ici le client. On ne le teste pas directement : on vérifie seulement si deux machines du périmètre peuvent se joindre à travers lui.

Ouvrez deux terminaux de la Kali, l'un sur `srv-int`, l'autre sur `web`.

Sur `srv-int` :

```bash
sudo ip route add 10.1.30.10/32 via 10.1.20.254
```

Sur `web` :

```bash
sudo ip route add 10.1.20.10/32 via 10.1.30.254
nc -vz -w 3 10.1.20.10 22
traceroute -n 10.1.20.10
sudo ip route del 10.1.20.10/32 via 10.1.30.254
```

Sur `srv-int` :

```bash
sudo ip route del 10.1.30.10/32 via 10.1.20.254
```

**Ligne par ligne.**

- `sudo ip route add 10.1.30.10/32 via 10.1.20.254` (sur `srv-int`) : pour joindre `web`, et seulement `web` (`/32`), passer par l'équipement en `.254` au lieu de pfSense. Sans cette route, les réponses de `srv-int` repartiraient par pfSense, qui les refuserait.
- `sudo ip route add 10.1.20.10/32 via 10.1.30.254` (sur `web`) : même chose dans l'autre sens.
- `nc -vz -w 3 10.1.20.10 22` : le flux `web → srv-int:22`, refusé par pfSense à l'étape 11. Réussit-il maintenant ?
- `traceroute -n 10.1.20.10` : affiche les routeurs traversés. Un seul saut, `10.1.30.254`, montre que le paquet n'est pas passé par pfSense.
- `sudo ip route del …` : retire aussitôt les routes de test, d'abord sur `web`, puis sur `srv-int`. Vérifiez avec `ip route` qu'elles ont disparu.

Qu'en concluez-vous sur la segmentation réelle de l'architecture ? Qui est responsable de ce point : vous, ou l'hébergeur ? Que faudrait-il exiger de lui ?

## Étape 13 — Remettre le laboratoire en ordre

**Pourquoi.** Un audit ne doit laisser aucune trace dans le système audité : pas de règle ouverte, pas de route ajoutée, pas de compte de test.

- *Firewall → Rules → LAN* : **désactivez la règle L5**, *Apply Changes*.
- Sur `srv-int` et sur `web` : `ip route` ne doit plus contenir de route via `.254`.
- Sur la Kali : `ip -br a show eth0` ne doit plus montrer `10.1.10.20`.

## Étape 14 — Coter les constats

**Pourquoi.** Un rapport qui liste cinquante constats sans les hiérarchiser ne sert à rien : le client ne sait pas par où commencer. La cotation combine l'impact possible et la facilité d'exploitation, dans le contexte réel (un service exposé à Internet n'a pas le même poids qu'un service interne).

Échelle à utiliser :

| Criticité | Définition | Délai de traitement attendu |
|---|---|---|
| **Critique** | Exploitable facilement, impact majeur (compromission, fuite de données), souvent depuis Internet | Immédiat |
| **Majeure** | Exploitable par un attaquant déjà dans le réseau, ou impact important | Moins d'un mois |
| **Mineure** | Exploitation difficile ou impact limité ; écart aux bonnes pratiques | Prochain cycle de maintenance |
| **Observation** | Point d'amélioration ou point positif à signaler | — |

Pour chaque constat, renseignez dans la section 4 du rapport : titre, criticité, description du **fait**, **preuve** (fichier de `preuves/`), **risque** (ce qui peut arriver), référentiel (ISO/IEC 27002:2022, PCI DSS v4.0.1, guide ANSSI), **recommandation** actionnable, effort estimé.

## Étape 15 — Rédiger le rapport

**Pourquoi.** Le rapport a deux lecteurs : la direction, qui décide et finance, et l'équipe technique, qui corrige. La synthèse est écrite pour la première, sans jargon ; les constats détaillés pour la seconde, avec les preuves.

Complétez `rapport-audit.md` :

1. **Synthèse pour la direction** (une demi-page) : niveau global, les trois risques majeurs en langage métier, les priorités.
2. **Contexte, périmètre et limites** : ce qui a été audité, ce qui ne l'a pas été, et pourquoi.
3. **Audit d'architecture** : la grille de l'étape 4.
4. **Constats détaillés**, triés par criticité.
5. **Plan d'action priorisé** : qui, quoi, quand.
6. **Annexe** : outils et versions, méthode, liste des preuves.

> **Défi ★.** Reliez chacun de vos constats majeurs à une exigence précise de PCI DSS v4.0.1 et à une mesure d'ISO/IEC 27002:2022. La segmentation de votre laboratoire permettrait-elle de réduire le périmètre d'un environnement de données de cartes (CDE) ? Qu'ajouterait NIS 2 en termes d'obligations, si la PME était une entité importante ?

**Livrable** (dans `~/livrables`) : `rapport-audit.md` complet et le dossier `preuves/`. Restitution orale de 5 minutes par apprenant (synthèse et trois premières recommandations) si le temps le permet.

## Questions de validation

1. Quelle est la différence entre un constat, un risque et une recommandation dans un rapport d'audit ?
2. Pourquoi faut-il vérifier activement l'isolation plutôt que se fier au schéma ?
3. Citez un constat de votre audit et reliez-le à un référentiel précis.

---

[← TP7](../tp7/README.md) · [Sommaire](../README.md) · [Corrigé](corrige/README.md) · [En cas de blocage](../en-cas-de-blocage.md)
