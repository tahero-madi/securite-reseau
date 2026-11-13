# TP2 — Gestion des vulnérabilités avec Greenbone

**Jour 1, 13:40 · 2 h 10, pause incluse.** Objectifs : conduire une campagne complète : scan non authentifié puis authentifié avec Greenbone, priorisation des résultats (CVSS/EPSS/KEV), remédiation d'au moins une vulnérabilité, contre-scan de vérification.

**Prérequis** : module 2, TP 1. **Livrable** : `rapport-vulns.md` (10 à 15 vulnérabilités priorisées, format du module 2), à remplir à partir du modèle fourni, + les exports CSV de chaque scan + la preuve avant/après d'une remédiation, dans `~/livrables`.

**Déroulé** : étapes 1 et 2 (préparer le scanner) 20 min · étapes 3 à 5 (scan non authentifié) 25 min · étapes 6 à 8 (scan authentifié) 30 min · étape 9 (prioriser) 20 min · étapes 10 et 11 (remédier, contre-scanner) 20 min.

## Étape 1 — Vérifier le scanner

**Pourquoi.** Greenbone tourne **sur votre Kali**, dans des conteneurs Docker : le scanner est donc vu par le réseau comme le poste d'administration `10.1.10.10`, et ses paquets traversent pfSense pour atteindre SRV et DMZ. Il se compose de plusieurs services : `gvmd`, le gestionnaire (tâches, résultats, base de données), `ospd-openvas`, le scanner qui envoie les tests, et `gsa`, l'interface web. Avant de scanner, on vérifie que tout tourne et que le scanner est bien relié au gestionnaire.

```bash
sudo docker compose -p greenbone-community-edition -f /opt/greenbone/compose.yaml ps
sudo docker compose -p greenbone-community-edition -f /opt/greenbone/compose.yaml exec -u gvmd gvmd gvmd --get-scanners
```

**Ligne par ligne.**

- `docker compose -p greenbone-community-edition -f /opt/greenbone/compose.yaml` : désigne le groupe de conteneurs de Greenbone : `-p` donne le nom du projet, `-f` le fichier qui le décrit.
- `ps` : liste les conteneurs du projet et leur état. `gvmd`, `gsa`, `ospd-openvas`, `pg-gvm` et `redis-server` doivent être *running* (*Up*). Les conteneurs de données du flux (`vulnerability-tests`, `scap-data`, `notus-data`…) sont *exited* : ils ont fini de copier leurs données, c'est normal.
- `exec -u gvmd gvmd gvmd --get-scanners` : exécute une commande dans un conteneur. `-u gvmd` choisit l'utilisateur ; le premier `gvmd` est le **conteneur**, le second la **commande** à lancer, et `--get-scanners` son option. Attention à bien écrire `gvmd` deux fois. La ligne « OpenVAS Default » doit apparaître : le scanner est enregistré.

## Étape 2 — Se connecter à la console

**Pourquoi.** La console GSA est l'interface web de Greenbone : on y crée les cibles et les tâches, on lance les scans et on lit les rapports. Comme pour pfSense, on change d'abord le mot de passe par défaut du compte d'administration.

1. Dans Firefox, ouvrez **`http://127.0.0.1`**. Connectez-vous avec le compte `admin` et le mot de passe indiqué dans `~/TP/identifiants-lab.txt`.
2. **Changez le mot de passe** : menu de l'utilisateur en haut à droite → *My Settings* → icône crayon en haut de la page → *Change Password*. Un compte ne peut pas modifier son propre mot de passe depuis *Administration → Users*.
3. Vérifiez le flux de vulnérabilités : *Administration → Feed Status*. Toutes les lignes doivent indiquer **Current**.

## Étape 3 — Créer la cible

**Pourquoi.** Une **cible** décrit *quoi* scanner : des adresses et une liste de ports. On la crée une fois et on la réutilise dans plusieurs tâches.

*Configuration → Targets*, puis l'icône **New Target** (étoile, en haut à gauche) :

- *Name* : `SRV-DMZ` ;
- *Hosts* : *Manual*, `10.1.30.10, 10.1.20.10` ;
- *Port List* : **All IANA assigned TCP** ;
- laissez le reste par défaut, puis *Save*.

`web` (10.1.30.10) est la cible riche en vulnérabilités (services anciens) ; `srv-int` est un serveur à jour, utile pour la comparaison.

## Étape 4 — Créer et lancer le scan non authentifié

**Pourquoi.** Une **tâche** associe une cible, une configuration de scan (quels tests lancer) et un scanner. Le scan *non authentifié* voit les machines comme un attaquant sur le réseau : il ne connaît que ce que les services révèlent.

*Scans → Tasks*, puis l'icône **New Task** (étoile, en haut à gauche) :

- *Name* : `Scan-non-auth` ;
- *Scan Targets* : `SRV-DMZ` ;
- *Scanner* : `OpenVAS Default` ;
- *Scan Config* : **Full and fast** ;
- *Save*.

La tâche apparaît dans la liste avec l'état **New** : créer une tâche ne la lance pas. **Pour lancer le scan, cliquez sur le bouton ▶ (*Start*)** dans la colonne *Actions*, sur la ligne de la tâche.

**Savoir où en est le scan.** Dans *Scans → Tasks*, la colonne **Status** évolue :

| Status | Signification |
|---|---|
| New | Tâche créée, jamais lancée |
| Requested | Lancement demandé, en attente du scanner |
| Queued | En file d'attente (un autre scan tourne) |
| Barre de progression avec un pourcentage | Scan en cours ; la page se rafraîchit seule |
| **Done** | Scan terminé : le rapport est complet |
| Stopped / Interrupted | Scan arrêté avant la fin : relancez-le avec ▶ |

La colonne **Reports** compte les rapports de la tâche, et **Last Report** donne la date du dernier. Comptez **10 à 20 minutes** pour ce scan. Pendant ce temps, *Scans → Results* montre les résultats au fur et à mesure.

## Étape 5 — Lire le rapport et l'exporter en CSV

**Pourquoi.** Le rapport rassemble les résultats d'une exécution de la tâche. On le lit pour repérer les vulnérabilités les plus graves, et on l'exporte en CSV pour garder une trace, comparer les scans entre eux et traiter les données avec d'autres outils.

1. Une fois la tâche à **Done**, cliquez sur la **date** dans la colonne *Last Report* (ou *Scans → Reports*, puis la date du rapport).
2. Onglet **Results** : cliquez sur l'en-tête **Severity** pour trier. Notez le nombre de vulnérabilités **High** et **Critical**, et observez la colonne **QoD** (*Quality of Detection* : la fiabilité de la détection, en %).
3. **Exportez le rapport en CSV** : icône **Download** (flèche vers le bas, en haut à gauche de la page du rapport), *Report Format* : **CSV Results**, puis *OK*. Firefox enregistre le fichier dans `~/Téléchargements`.
4. Rangez-le dans vos livrables sous un nom explicite :

```bash
ls -t ~/Téléchargements/*.csv | head -3
mv "$(ls -t ~/Téléchargements/*.csv | head -1)" ~/livrables/tp2-scan-non-auth.csv
head -3 ~/livrables/tp2-scan-non-auth.csv
```

**Ligne par ligne.**

- `ls -t ~/Téléchargements/*.csv | head -3` : liste les fichiers CSV téléchargés, du plus récent au plus ancien (`-t`), et n'affiche que les trois premiers. Le nom donné par Greenbone (`report-…csv`) n'est pas parlant.
- `mv "$(ls -t ~/Téléchargements/*.csv | head -1)" ~/livrables/tp2-scan-non-auth.csv` : déplace le CSV le plus récent vers vos livrables en le renommant. `$( … )` insère le résultat de la commande entre parenthèses ; les guillemets protègent le nom s'il contient des espaces.
- `head -3 ~/livrables/tp2-scan-non-auth.csv` : affiche les trois premières lignes : la ligne d'en-tête (`IP,Hostname,Port,Port Protocol,CVSS,Severity,QoD,…`) puis les premiers résultats.

Le CSV contient les résultats affichés par le **filtre** du rapport (en haut de la page) : par défaut, les résultats de simple information (*Log*) sont masqués, ce qui convient ici.

> **Lecture critique.** Sur `web`, le scan non authentifié remonte beaucoup de résultats fiables (services anciens réellement exposés). Sur un serveur à jour comme `srv-int`, certains résultats fondés sur une bannière peuvent être des faux positifs : d'où l'intérêt du scan authentifié.

## Étape 6 — Préparer un compte de scan

**Pourquoi.** Un scan **authentifié** se connecte à la machine pour lire la liste exacte des paquets installés et les comparer aux correctifs publiés. Il faut donc un compte, et ce compte est sensible : on le veut dédié, sans mot de passe, accessible par clé uniquement, depuis la seule adresse du scanner, et sans droits d'administration (lire la liste des paquets ne demande aucun privilège).

Sur la **Kali** :

```bash
ssh-keygen -t ed25519 -f ~/gvm-scan -N '' -C gvm-scan
scp ~/gvm-scan.pub formation@10.1.30.10:
ssh formation@10.1.30.10
```

**Ligne par ligne.**

- `ssh-keygen -t ed25519 -f ~/gvm-scan -N '' -C gvm-scan` : crée une paire de clés : `-t ed25519` choisit l'algorithme, `-f` le fichier (`~/gvm-scan` pour la clé privée, `~/gvm-scan.pub` pour la publique), `-N ''` une phrase de passe vide (le scanner doit pouvoir l'utiliser seul), `-C` un commentaire qui identifie la clé.
- `scp ~/gvm-scan.pub formation@10.1.30.10:` : copie la clé **publique** dans le dossier personnel de `formation` sur `web`. La clé privée ne quitte jamais la Kali.
- `ssh formation@10.1.30.10` : ouvre une session sur `web` pour la suite.

Puis, sur **web** :

```bash
sudo useradd -m -s /bin/bash gvm-scan
sudo install -d -m 700 -o gvm-scan -g gvm-scan /home/gvm-scan/.ssh
echo "from=\"10.1.10.10\" $(cat ~/gvm-scan.pub)" | sudo tee /home/gvm-scan/.ssh/authorized_keys
sudo chown gvm-scan:gvm-scan /home/gvm-scan/.ssh/authorized_keys
sudo chmod 600 /home/gvm-scan/.ssh/authorized_keys
exit
```

**Ligne par ligne.**

- `useradd -m -s /bin/bash gvm-scan` : crée l'utilisateur `gvm-scan`, avec un dossier personnel (`-m`) et un shell (`-s`). Aucun mot de passe n'est défini : la connexion par mot de passe est impossible.
- `install -d -m 700 -o gvm-scan -g gvm-scan /home/gvm-scan/.ssh` : crée le dossier `.ssh` du compte, accessible à lui seul (`700`).
- `echo "from=\"10.1.10.10\" $(cat ~/gvm-scan.pub)" | sudo tee …/authorized_keys` : autorise la clé publique, avec l'option `from="10.1.10.10"` : la clé n'est acceptée que depuis l'adresse du scanner. `tee` écrit le fichier avec les droits de `sudo`.
- `chown` puis `chmod 600` : le fichier appartient au compte et n'est lisible que par lui ; sinon, SSH refuse de l'utiliser.
- `exit` : revient sur la Kali.

Vérifiez depuis la **Kali** :

```bash
ssh -i ~/gvm-scan gvm-scan@10.1.30.10 'dpkg -l | wc -l'
```

**Ligne par ligne.**

- `ssh -i ~/gvm-scan gvm-scan@10.1.30.10` : se connecte avec la clé privée (`-i`) en tant que `gvm-scan`.
- `'dpkg -l | wc -l'` : exécute à distance la commande qui compte les paquets installés : c'est, en simplifié, ce que fera le scanner. Un nombre de plusieurs centaines doit s'afficher.

## Étape 7 — Déclarer l'identifiant et la cible authentifiée

**Pourquoi.** Greenbone doit connaître le compte et la clé pour se connecter. On les enregistre comme **identifiant**, puis on crée une cible qui l'utilise.

1. *Configuration → Credentials* → **New Credential** :
   - *Name* : `cred-ssh` ;
   - *Type* : **Username + SSH Key** ;
   - *Username* : `gvm-scan` ;
   - *Private Key* : choisissez le fichier `~/gvm-scan` de la Kali (dans la fenêtre de sélection, Ctrl+H affiche les fichiers cachés si besoin) ;
   - *Save*.
2. *Configuration → Targets* → **New Target** :
   - *Name* : `WEB-auth` ;
   - *Hosts* : `10.1.30.10` ;
   - *Port List* : **All IANA assigned TCP** ;
   - *Credentials for authenticated checks*, ligne **SSH** : `cred-ssh`, port 22 ;
   - *Save*.

## Étape 8 — Lancer le scan authentifié et comparer

**Pourquoi.** Le scan authentifié détecte les **correctifs manquants** (paquets non mis à jour), invisibles depuis le réseau, avec une QoD élevée et moins de faux positifs.

1. *Scans → Tasks* → **New Task** : *Name* `Scan-auth`, *Scan Targets* `WEB-auth`, *Scan Config* **Full and fast**, *Save*.
2. **Cliquez sur ▶ (*Start*)** sur la ligne de `Scan-auth`, puis suivez la colonne *Status* jusqu'à **Done** (comptez 10 à 15 minutes).
3. Ouvrez le rapport, triez par *Severity*, puis exportez-le en CSV comme à l'étape 5, sous le nom `~/livrables/tp2-scan-auth.csv` :

```bash
mv "$(ls -t ~/Téléchargements/*.csv | head -1)" ~/livrables/tp2-scan-auth.csv
```

4. Comparez avec le scan non authentifié, pour `web` : nombre de résultats, sévérités, QoD. Dans un rapport authentifié, cherchez des résultats dont le nom commence par le nom de la distribution (« Ubuntu: Security Advisory… ») : ce sont les correctifs manquants.

Pour vérifier que l'authentification a bien fonctionné, ouvrez l'onglet **Hosts** du rapport : la colonne *Auth* doit indiquer une authentification SSH réussie. Si ce n'est pas le cas, le résultat « SSH Login Failed » apparaît dans les résultats.

## Étape 9 — Prioriser

**Pourquoi.** Un scan produit des dizaines de résultats ; on ne peut pas tout corriger en même temps. Prioriser, c'est croiser la gravité (CVSS), la probabilité d'exploitation (EPSS), l'exploitation avérée (KEV) et l'exposition de la machine.

Récupérez le modèle du rapport et ouvrez-le :

```bash
cd ~/livrables
curl -fsSLO https://raw.githubusercontent.com/tahero-madi/securite-reseau/main/tp2/modeles/rapport-vulns.md
mousepad rapport-vulns.md &
```

**Ligne par ligne.**

- `curl -fsSLO <adresse>` : télécharge le modèle depuis le dépôt et garde son nom (`-O`).
- `mousepad rapport-vulns.md &` : l'ouvre dans l'éditeur, en arrière-plan.

Sélectionnez 10 à 15 vulnérabilités et, pour chacune : hôte, CVE, CVSS, QoD, et un classement de priorité P0 à P3 (module 2). Pour les 3 plus hautes, vérifiez manuellement :

- la CVE figure-t-elle au **KEV**, le catalogue des vulnérabilités exploitées de la CISA (`https://www.cisa.gov/known-exploited-vulnerabilities-catalog`) ?
- quel est son **EPSS**, la probabilité d'exploitation publiée par le FIRST (`https://www.first.org/epss/`) ?

Justifiez l'ordre de traitement.

> **Défi ★.** Sur la Kali, écrivez un court script (Python ou awk) qui lit `tp2-scan-auth.csv`, trie les vulnérabilités par sévérité puis par QoD, et affiche les 5 prioritaires. Discutez : trier par CVSS seul suffit-il ?

## Étape 10 — Remédier

**Pourquoi.** Un rapport de vulnérabilités ne sert à rien s'il n'est pas suivi de corrections. On en corrige au moins une, choisie dans votre rapport.

Choisissez **une** vulnérabilité corrigeable sur `web` : un service ancien inutile à désactiver, un paquet à mettre à jour, ou une configuration à durcir. Sur **web** (`ssh formation@10.1.30.10`), selon le cas :

```bash
sudo apt update
sudo apt install --only-upgrade nginx
```

ou :

```bash
sudo systemctl disable --now openbsd-inetd
```

**Ligne par ligne.**

- `apt update` : met à jour la liste des versions disponibles (la machine passe par pfSense pour joindre les dépôts Ubuntu).
- `apt install --only-upgrade nginx` : met à jour le paquet `nginx` (remplacez par le paquet de votre vulnérabilité), sans installer de nouveau paquet (`--only-upgrade`).
- `systemctl disable --now openbsd-inetd` : arrête immédiatement (`--now`) le service qui fait tourner Telnet sur web, et l'empêche de redémarrer au prochain démarrage (`disable`).

## Étape 11 — Contre-scanner

**Pourquoi.** Une correction n'est acquise que lorsqu'elle est **vérifiée**. On relance le même scan et on montre que la vulnérabilité a disparu.

1. *Scans → Tasks* : cliquez sur **▶ (*Start*)** sur la ligne de `Scan-auth` (ou `Scan-non-auth` si vous avez désactivé un service). La tâche produit un nouveau rapport ; la colonne *Reports* passe à 2.
2. Une fois à **Done**, exportez le nouveau rapport en CSV : `~/livrables/tp2-contre-scan.csv`.

```bash
mv "$(ls -t ~/Téléchargements/*.csv | head -1)" ~/livrables/tp2-contre-scan.csv
```

3. Montrez que la vulnérabilité a **disparu** en cherchant son nom dans les deux CSV (GSA sait aussi comparer deux rapports d'une même tâche : *Scans → Reports*, icône *Delta*) :

```bash
grep -c "<nom de la vulnérabilité>" ~/livrables/tp2-scan-auth.csv ~/livrables/tp2-contre-scan.csv
```

**Ligne par ligne.**

- `grep -c "<texte>" fichier1 fichier2` : compte, dans chaque fichier, les lignes qui contiennent le texte. Le résultat doit passer de 1 (ou plus) dans le premier rapport à 0 dans le second.

Faites des captures d'écran avant/après pour le livrable.

**Livrable** (dans `~/livrables`) : `rapport-vulns.md`, `tp2-scan-non-auth.csv`, `tp2-scan-auth.csv`, `tp2-contre-scan.csv` et les captures avant/après de la remédiation.

## Questions de validation

1. Pourquoi le scan authentifié produit-il moins de faux positifs ?
2. Une vulnérabilité CVSS 10 a une QoD de 30 % : que faites-vous avant de la déclarer prioritaire ?
3. Comment protégez-vous le compte de scan authentifié ?

---

[← TP1](../tp1/README.md) · [Sommaire](../README.md) · [Corrigé](corrige/README.md) · [En cas de blocage](../en-cas-de-blocage.md) · [TP3 →](../tp3/README.md)
