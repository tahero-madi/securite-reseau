# TP2 — Gestion des vulnérabilités avec Greenbone

**Jour 1, 13:40 · 2 h 10, pause incluse.** Objectifs : conduire une campagne complète : scan non authentifié puis authentifié avec Greenbone, priorisation des résultats (CVSS/EPSS/KEV), remédiation d'au moins une vulnérabilité, contre-scan de vérification.

**Prérequis** : module 2, TP 1. **Livrable** : un `rapport-vulns` (10 à 15 vulnérabilités priorisées, format du module 2) + la preuve avant/après d'une remédiation.

## Partie A — Préparer le scanner (20 min)

1. Greenbone tourne **sur votre Kali**, dans des conteneurs Docker : le scanner est donc vu par le réseau comme le poste d'administration `10.1.10.10`, et ses paquets traversent pfSense pour atteindre SRV et DMZ. Vérifiez l'état des conteneurs dans un terminal de la Kali :

```bash
sudo docker compose -p greenbone-community-edition -f /opt/greenbone/compose.yaml ps
```

Les services `gvmd`, `gsa`, `ospd-openvas`, `pg-gvm`, `redis-server` doivent être *running* ; les conteneurs de données du flux (`vulnerability-tests`, `scap-data`…) sont *exited* : ils ont fini de copier leurs données, c'est normal.

2. Vérifiez que le scanner est enregistré auprès du gestionnaire :

```bash
sudo docker compose -p greenbone-community-edition -f /opt/greenbone/compose.yaml \
     exec -u gvmd gvmd gvmd --get-scanners
```

3. Ouvrez la console GSA dans Firefox, à l'adresse indiquée dans `~/TP/identifiants-lab.txt` (`http://127.0.0.1:9392` ou `https://127.0.0.1` selon la version). Connectez-vous (compte `admin`, mot de passe dans le même fichier) et **changez le mot de passe** : menu de l'utilisateur en haut à droite → *My Settings* → icône crayon → *Change Password* (un compte ne peut pas modifier son propre mot de passe depuis *Administration → Users*). Dans *Administration → Feed Status*, vérifiez que les flux sont « Current ».

## Partie B — Scan non authentifié (25 min)

4. Créez une cible (*Configuration → Targets → New*) nommée `SRV-DMZ` avec les hôtes `10.1.30.10, 10.1.20.10`, liste de ports « All IANA assigned TCP ». `web` (10.1.30.10) est la cible riche en vulnérabilités (services anciens) ; `srv-int` est un serveur à jour, utile pour la comparaison.
5. Créez une tâche (*Scans → Tasks → New Task*) `Scan-non-auth` sur cette cible, configuration **Full and Fast**. Lancez-la.
6. Pendant le scan (5 à 10 min), observez dans *Scans → Results* l'arrivée des résultats. Une fois terminé, ouvrez le rapport : triez par sévérité, notez le nombre de vulnérabilités **High/Critical** et observez la colonne **QoD**.

> **Lecture critique.** Sur `web`, le scan non authentifié remonte beaucoup de résultats fiables (services anciens réellement exposés). Sur un serveur à jour comme `srv-int`, certains résultats fondés sur une bannière peuvent être des faux positifs : d'où l'intérêt du scan authentifié.

## Partie C — Scan authentifié (30 min)

7. Préparez un **compte de scan dédié** sur `web`. Le principe : un compte sans mot de passe, accessible par clé uniquement, depuis la seule adresse du scanner, sans droits d'administration (lire la liste des paquets ne demande aucun privilège). Sur la Kali, générez la clé puis copiez la partie publique :

```bash
ssh-keygen -t ed25519 -f ~/gvm-scan -N '' -C gvm-scan
scp ~/gvm-scan.pub formation@10.1.30.10:
ssh formation@10.1.30.10
```

Puis, sur `web` :

```bash
sudo useradd -m -s /bin/bash gvm-scan
sudo install -d -m 700 -o gvm-scan -g gvm-scan /home/gvm-scan/.ssh
echo "from=\"10.1.10.10\" $(cat ~/gvm-scan.pub)" | sudo tee /home/gvm-scan/.ssh/authorized_keys
sudo chown gvm-scan:gvm-scan /home/gvm-scan/.ssh/authorized_keys
sudo chmod 600 /home/gvm-scan/.ssh/authorized_keys
```

Vérifiez depuis la Kali : `ssh -i ~/gvm-scan gvm-scan@10.1.30.10 'dpkg -l | wc -l'`.

8. Dans GSA, créez un identifiant SSH (*Configuration → Credentials → New*, type « Username + SSH Key ») `cred-ssh` : utilisateur `gvm-scan`, clé privée = le fichier `~/gvm-scan` de la Kali.
9. Créez une cible `WEB-auth` sur `10.1.30.10` en y associant l'identifiant SSH (champ *SSH credential*).
10. Lancez une tâche authentifiée `Scan-auth`. Comparez : le scan authentifié détecte les **correctifs manquants** (paquets), invisibles au scan réseau, avec une QoD élevée et moins de faux positifs.

## Partie D — Prioriser (20 min)

11. Constituez `rapport-vulns` : sélectionnez 10 à 15 vulnérabilités et, pour chacune : hôte, CVE, CVSS, et un classement de priorité P0-P3 (module 2). Pour les 3 plus hautes, vérifiez manuellement : la CVE est-elle au **KEV** (catalogue CISA) ? quel **EPSS** (site FIRST/EPSS) ? Justifiez l'ordre de traitement.

> **Défi ★.** Exportez le rapport au format CSV depuis GSA et, sur la Kali, écrivez un court script (Python/awk) qui trie les vulnérabilités par couple (sévérité, QoD) et sort les 5 prioritaires. Discutez : trier par CVSS seul suffit-il ?

## Partie E — Remédier et contre-scanner (20 min)

12. Choisissez **une** vulnérabilité corrigeable sur `web` (par exemple un service ancien inutile à désactiver, un paquet à mettre à jour, ou une configuration SSH à durcir). Appliquez la correction :

Sur `web` (`ssh formation@10.1.30.10`) :

```bash
# exemple : mise à jour ciblée d'un paquet
sudo apt update && sudo apt install --only-upgrade <paquet>
# ou désactivation d'un service inutile
sudo systemctl disable --now <service>
```

13. Relancez la tâche authentifiée (contre-scan) et montrez que la vulnérabilité a **disparu** du rapport. Capturez l'avant/après.

**Livrable** (dans `~/livrables`) : `rapport-vulns` + captures avant/après de la remédiation.

## Questions de validation

1. Pourquoi le scan authentifié produit-il moins de faux positifs ?
2. Une vulnérabilité CVSS 10 a une QoD de 30 % : que faites-vous avant de la déclarer prioritaire ?
3. Comment protégez-vous le compte de scan authentifié ?

---

[← TP1](../tp1/README.md) · [Sommaire](../README.md) · [Corrigé](corrige/README.md) · [En cas de blocage](../en-cas-de-blocage.md) · [TP3 →](../tp3/README.md)
