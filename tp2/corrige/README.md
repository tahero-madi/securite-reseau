# Corrigé du TP2

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

**Préparation.** Le flux Greenbone se charge à l'installation de la Kali (`prep.sh`) et doit être « Current » dans *Feed Status* avant l'instantané de départ : le vérifier sur chaque environnement la veille. Si un apprenant voit des tâches sans résultat, c'est presque toujours le flux encore en cours de chargement ou un scan lancé avant que `ospd-openvas` ne soit prêt (relancer). Le scanner sort sous l'adresse de la Kali (10.1.10.10) : à l'état initial, les règles « HRA : tout autoriser » de pfSense laissent tout passer. Si la Kali manque de mémoire pendant un scan (12 Go pour Greenbone, Zabbix et le bureau), arrêter Zabbix le temps du TP : `sudo docker compose -f /opt/zabbix/compose.yaml stop`.

**Lancement et suivi.** L'erreur la plus fréquente : créer la tâche sans la lancer (état **New**). Il faut cliquer sur ▶ dans la colonne *Actions*. Le scan est terminé quand *Status* indique **Done** ; si la tâche passe en *Interrupted*, vérifier dans *Feed Status* que le flux est « Current » et que la Kali a assez de mémoire, puis relancer.

**Étapes 3 à 8.** Résultats typiques : `web` remonte de nombreuses vulnérabilités élevées/critiques réelles via ses services anciens volontairement non durcis (FTP, Telnet, versions obsolètes) et ses applications vulnérables (DVWA, Juice Shop). Sur `srv-int` à jour, le scan non authentifié peut signaler des « versions anciennes » sur la base de bannières alors qu'Ubuntu rétroporte les correctifs → faux positif, à confirmer en authentifié. Le point clé : montrer la différence de couverture et de fiabilité. Les paquets de service de `web` (nginx, PHP, MariaDB, vsftpd, snmpd…) ont été installés dans leur version de sortie d'Ubuntu 24.04 sans les mises à jour : le scan authentifié (Notus) remonte donc de nombreux correctifs manquants réels, que `apt install --only-upgrade` corrige pour le contre-scan.

Compte de scan : insister sur le principe (dédié, clé, droits minimaux, restriction par source avec `from="10.1.10.10"`, journalisé). Faire constater qu'aucun `sudo` n'est nécessaire pour un scan de correctifs sur Ubuntu (lecture de `dpkg`). Ne jamais utiliser un compte root réutilisé.

**Étape 9.** Les apprenants doivent articuler les trois signaux : CVSS (sévérité), EPSS (probabilité), KEV (exploitation avérée) + exposition de l'actif. Attendu : une vulnérabilité KEV sur `web` (exposé) passe avant une CVSS 9.8 théorique sur un hôte interne non exposé. Vérifier qu'ils consultent réellement KEV et EPSS et ne se fient pas au seul score.

**Défi ★ — exemple de script.**

```python
import csv
ordre = {"Critical": 4, "High": 3, "Medium": 2, "Low": 1, "Log": 0}
with open("/home/formation/livrables/tp2-scan-auth.csv", newline="") as f:
    lignes = list(csv.DictReader(f))
lignes.sort(key=lambda r: (ordre.get(r["Severity"], 0), float(r["CVSS"] or 0), int(r["QoD"] or 0)), reverse=True)
for r in lignes[:5]:
    print(r["Severity"], r["CVSS"], r["QoD"] + " %", r["IP"], r["Port"], r["NVT Name"], r["CVEs"], sep=" | ")
```

Point de discussion : le tri par CVSS ignore l'exposition de la machine, la probabilité d'exploitation (EPSS) et l'exploitation avérée (KEV) ; à CVSS égal, une vulnérabilité exposée sur Internet et au KEV passe en premier.

**Étapes 10 et 11.** Exemples de remédiation faciles à démontrer : `sudo apt install --only-upgrade nginx` (ou `php8.3-fpm`), désactiver Telnet (`sudo systemctl disable --now openbsd-inetd`) ou SNMP (`snmpd`), durcir `sshd_config` (si une règle de conformité le remonte), mettre à jour un paquet applicatif non critique. L'essentiel pédagogique est la **boucle** correction → contre-scan → disparition du résultat.

**Questions.** 1 : il lit l'état réel des paquets installés et des correctifs via un compte, au lieu de déduire d'une bannière. 2 : vérifier manuellement (QoD faible = détection peu fiable) : confirmer l'existence du service/version, écarter le faux positif, sinon ne pas gaspiller d'effort. 3 : compte dédié, clé SSH, droits de lecture minimaux, restriction à l'IP du scanner, activation seulement pendant les fenêtres de scan, rotation du secret, journalisation.

---

[← TP1](../../tp1/README.md) · [Sommaire](../../README.md) · [Énoncé](../README.md) · [En cas de blocage](../../en-cas-de-blocage.md) · [TP3 →](../../tp3/README.md)
