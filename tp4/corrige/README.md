# Corrigé du TP4

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

**Préparation.** Vérifier sur un environnement : OpenLDAP préchargé avec `people` (alice, bob, carol), `groups` (admins, users), `services` (svc-radius en lecture seule) ; certificats serveur pour LDAPS et pour EAP présents (AC du lab créée sur srv-int dans `/etc/lab-pki`, copie publique dans `~formation/pki/ca.crt`) ; horloge synchronisée. Le flux Kali → srv-int en 389/636 doit être autorisé par la matrice du TP 3 (alias `P_admin`). `freeradius -X` est l'outil central : apprendre aux stagiaires à le lire.

**Partie A.** Point clé : le bind simple sur ldap:// expose le mot de passe (visible en capture) ; LDAPS/StartTLS le protège. Si `ldapsearch` en LDAPS échoue avec « Can't contact LDAP server », c'est presque toujours le certificat d'AC non fourni (`LDAPTLS_CACERT`) ou le nom utilisé : il faut `srv-int.lab.local` (nom présent dans le certificat), pas une autre adresse. Forcer le chiffrement : retirer `ldap:///` de `SLAPD_SERVICES` (on garde `ldapi:///` pour l'administration locale) ou poser `olcSecurity: tls=1`. Le compte de service doit être en lecture seule, limité à la branche `people`.

**Partie B.** Pièges fréquents : oubli du lien symbolique du module ldap ; `base_dn` erroné ; secret différent entre `clients.conf` et pfSense ; adresse du client RADIUS erronée (pfSense interroge srv-int depuis son interface SRV, `10.1.20.1`, et non depuis le LAN : `freeradius -X` affiche « Ignoring request from unknown client ») ; FreeRADIUS encore lancé en service pendant le test `-X` (port occupé → `sudo systemctl stop freeradius` d'abord). L'`Access-Accept` sur `alice` et l'`Access-Reject` sur mauvais mot de passe valident la chaîne RADIUS→LDAP.

**Partie C.** L'autorisation par groupe illustre le deuxième A de AAA : même authentifié, un utilisateur ne reçoit que les droits de son groupe. Implémentation via le module ldap (récupération de `memberOf` ou group membership) + `if (LDAP-Group == "admins")` en post-auth.

**Défi EAP-TLS.** `eapol_test -c tls.conf -s testing123` ; montrer que EAP-TLS n'échange pas de mot de passe (certificats mutuels) et que la faiblesse de PEAP vient de l'absence de validation du certificat serveur côté client (risque de faux point d'accès).

**Partie D.** Bien conserver le compte local de secours sur pfSense (sinon risque de verrouillage si RADIUS tombe). La capture (faite par pfSense sur son interface SRV) doit montrer `Message-Authenticator`. pfSense émet ses requêtes depuis 10.1.20.1 : c'est l'adresse à déclarer dans `clients.conf`. Lien avec le module 7 : ces authentifications sont des événements à journaliser.

**Questions.** 1 : moindre privilège — `cn=admin` a tous les droits ; une fuite du secret du service exposerait tout l'annuaire ; le compte de service est en lecture seule sur une branche. 2 : `Message-Authenticator` exigé (require_message_authenticator = yes) côté serveur et NAS. 3 : validation stricte du certificat du serveur RADIUS (AC attendue + nom du serveur) déployée sur les postes ; sans elle, un faux point d'accès récupère les échanges d'authentification.

---

[← TP3](../../tp3/README.md) · [Sommaire](../../README.md) · [Énoncé](../README.md) · [En cas de blocage](../../en-cas-de-blocage.md) · [TP5 →](../../tp5/README.md)
