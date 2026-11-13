# Corrigé du TP2

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

**Préparation.** Le flux Greenbone a été chargé dans le modèle avant clonage : vérifier « Current » dans *Feed Status* sur une VM la veille. Si un apprenant voit des tâches sans résultat, c'est presque toujours le flux encore en cours de chargement ou un scan lancé avant que `ospd-openvas` ne soit prêt (relancer). Le scanner sort sous l'adresse du poste (10.1.10.10) : à l'état initial, la règle LAN « allow all » de pfSense laisse tout passer.

**Partie B/C.** Résultats typiques : `web` remonte de nombreuses vulnérabilités élevées/critiques réelles via ses services anciens volontairement non durcis (FTP, Telnet, versions obsolètes) et ses applications vulnérables (DVWA, Juice Shop). Sur `srv-int` à jour, le scan non authentifié peut signaler des « versions anciennes » sur la base de bannières alors qu'Ubuntu rétroporte les correctifs → faux positif, à confirmer en authentifié. Le point clé : montrer la différence de couverture et de fiabilité. Les paquets de service de `web` (nginx, PHP, MariaDB, vsftpd, snmpd…) ont été installés dans leur version de sortie d'Ubuntu 24.04 sans les mises à jour : le scan authentifié (Notus) remonte donc de nombreux correctifs manquants réels, que `apt install --only-upgrade` corrige pour le contre-scan.

Compte de scan : insister sur le principe (dédié, clé, droits minimaux, restriction par source avec `from="10.1.10.10"`, journalisé). Faire constater qu'aucun `sudo` n'est nécessaire pour un scan de correctifs sur Ubuntu (lecture de `dpkg`). Ne jamais utiliser un compte root réutilisé.

**Partie D.** Les apprenants doivent articuler les trois signaux : CVSS (sévérité), EPSS (probabilité), KEV (exploitation avérée) + exposition de l'actif. Attendu : une vulnérabilité KEV sur `web` (exposé) passe avant une CVSS 9.8 théorique sur un hôte interne non exposé. Vérifier qu'ils consultent réellement KEV et EPSS et ne se fient pas au seul score.

**Partie E.** Exemples de remédiation faciles à démontrer : `sudo apt install --only-upgrade nginx` (ou `php8.3-fpm`), désactiver Telnet (`sudo systemctl disable --now openbsd-inetd`) ou SNMP (`snmpd`), durcir `sshd_config` (si une règle de conformité le remonte), mettre à jour un paquet applicatif non critique. L'essentiel pédagogique est la **boucle** correction → contre-scan → disparition du résultat.

**Questions.** 1 : il lit l'état réel des paquets installés et des correctifs via un compte, au lieu de déduire d'une bannière. 2 : vérifier manuellement (QoD faible = détection peu fiable) : confirmer l'existence du service/version, écarter le faux positif, sinon ne pas gaspiller d'effort. 3 : compte dédié, clé SSH, droits de lecture minimaux, restriction à l'IP du scanner, activation seulement pendant les fenêtres de scan, rotation du secret, journalisation.

---

[← TP1](../../tp1/README.md) · [Sommaire](../../README.md) · [Énoncé](../README.md) · [En cas de blocage](../../en-cas-de-blocage.md) · [TP3 →](../../tp3/README.md)
