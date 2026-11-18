# Corrigé du TP4

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

**Préparation.** Sur chaque environnement : OpenLDAP préchargé avec `people` (alice, bob, carol), `groups` (`admins` : alice ; `users` : bob et carol) et `services` (`svc-radius`) ; certificats du laboratoire présents (AC dans `/etc/lab-pki`, copie publique dans `~formation/pki/ca.crt`, certificats de FreeRADIUS dans `/etc/freeradius/3.0/certs/lab/`) ; FreeRADIUS en configuration par défaut, module `ldap` **non activé** ; horloges synchronisées. La règle L4 du TP3 (`P_admin`) doit autoriser la Kali vers `srv-int` en 22, 389 et 636. `freeradius -X` est l'outil central : apprendre aux apprenants à le lire.

## Étapes 1 et 2 — L'annuaire

Trois personnes sous `ou=people`, deux groupes `groupOfNames` sous `ou=groups`, dont les membres sont désignés par leur DN complet dans `member` : `cn=admins` → `uid=alice,ou=people,dc=lab,dc=local` ; `cn=users` → bob et carol.

## Étapes 3 et 4 — LDAP en clair, LDAPS

- En `ldap://`, le `bindRequest` montre le mot de passe d'alice en clair dans Wireshark (champ `simple`).
- En `ldaps://`, seule la poignée de main TLS est visible, puis des données chiffrées.
- Si LDAPS échoue (« Can't contact LDAP server ») : AC non fournie (`LDAPTLS_CACERT`), nom différent de `srv-int.lab.local` (le certificat ne porte pas l'adresse IP comme nom principal), ou port 636 absent de `P_admin`.

**Question — forcer le chiffrement.** Deux possibilités :

- retirer `ldap:///` de `SLAPD_SERVICES` dans `/etc/default/slapd` (garder `ldapi:///` pour l'administration locale et `ldaps:///`), puis `sudo systemctl restart slapd` : le port 389 ne répond plus ;
- ou garder le port 389 mais exiger TLS (StartTLS) avec `olcSecurity: tls=1` dans `cn=config` (`ldapmodify -Y EXTERNAL -H ldapi:///`).

Point complémentaire : sur Ubuntu, les ACL par défaut de l'annuaire laissent tout utilisateur authentifié lire toutes les entrées (sauf les mots de passe). Un vrai durcissement limiterait `svc-radius` à la lecture de `ou=people` et `ou=groups` (`olcAccess`).

## Étapes 5 et 6 — FreeRADIUS adossé à LDAP

Pièges fréquents :

- **lien symbolique absent** dans `mods-enabled` : aucune ligne `ldap` dans la sortie de `-X` ;
- **erreur de syntaxe** dans le module (accolade manquante, apostrophe) : `-X` s'arrête au démarrage en indiquant le fichier et la ligne ;
- **`require_cert = 'demand'` et nom différent de celui du certificat** : échec de connexion TLS à l'annuaire ;
- **blocs non décommentés à l'étape 6** : alice est trouvée dans l'annuaire, mais aucune méthode ne peut vérifier son mot de passe (« No Auth-Type found: rejecting the user via Post-Auth-Type = Reject »). Le compte de service ne peut pas lire `userPassword` (ACL par défaut d'OpenLDAP) : l'authentification doit se faire par *bind* au nom de l'utilisateur.

Extrait attendu des sections modifiées de `sites-available/default` :

```
	-ldap
	if ((ok || updated) && User-Password && !control:Auth-Type) {
		update control {
			&Auth-Type := ldap
		}
	}
…
	Auth-Type LDAP {
		ldap
	}
```

## Étape 7 — `clients.conf`

```
client pfsense {
	ipaddr = 10.1.20.1
	secret = <44 caractères aléatoires>
	require_message_authenticator = yes
	shortname = pfsense
}
```

pfSense interroge `srv-int` depuis son interface **SRV** (10.1.20.1), pas depuis le LAN : avec une autre adresse, `-X` affiche « Ignoring request from unknown client 10.1.20.1 ».

## Étape 8 — Tests

- alice / bon mot de passe : `Access-Accept`.
- alice / mauvais mot de passe : `Access-Reject` (avec un délai d'une seconde, volontaire).
- bob / bon mot de passe : `Access-Accept` **avant** l'étape 9.

Si `freeradius -X` refuse de démarrer avec « Failed binding to auth address … port 1812 … Address already in use » : le service tourne encore, `sudo systemctl stop freeradius`.

## Étape 9 — Autorisation par groupe

- alice : `Access-Accept` avec `Class = 0x6c61622d61646d696e73` (« lab-admins »).
- bob : `Access-Reject` ; dans `-X`, la comparaison `LDAP-Group == "admins"` échoue et la politique renvoie `reject`.

C'est le deuxième A de AAA : bob est **authentifié** (son mot de passe est bon) mais pas **autorisé**. La décision est prise par FreeRADIUS, dans la section `post-auth`, à partir de l'appartenance au groupe dans l'annuaire : un seul endroit pour accorder ou retirer un droit d'administration, pour tous les équipements qui utilisent RADIUS.

Oubli fréquent : ne pas relancer le service après le mode débogage. pfSense n'obtient alors aucune réponse (délai dépassé à l'étape 11).

## Étapes 10 à 12 — pfSense

- Groupe local `lab-admins`, portée **Remote**, privilège **WebCfg - All pages** ; serveur RADIUS en **PAP**, secret identique, *Disable Message Authenticator* décoché.
- *Diagnostics → Authentication* : alice authentifiée et membre de `lab-admins` ; bob refusé. Si alice est authentifiée sans groupe, le nom du groupe local ne correspond pas exactement à la valeur de `Class`.
- Connexion à l'interface : alice entre avec tous les droits ; bob est refusé.
- La capture montre `Access-Request` / `Access-Accept` (avec `Class`) pour alice, `Access-Request` / `Access-Reject` pour bob, et l'attribut `Message-Authenticator` dans chaque paquet. Le nom d'utilisateur, les adresses et `Class` sont en clair ; le mot de passe est masqué, mais Wireshark le révèle dès qu'on lui donne le secret partagé : la sécurité de PAP repose entièrement sur ce secret et sur la confidentialité du réseau qui transporte RADIUS. En production, RadSec (RADIUS sur TLS) ou une méthode EAP.
- Le compte local `admin` reste le compte de secours : sans lui, une panne de `srv-int` enfermerait les administrateurs dehors. Lien avec le module 7 : ces authentifications sont des événements à journaliser.

## Défi ★ — EAP-TLS

`eapol_test` doit se terminer par `SUCCESS`. Aucun mot de passe n'est échangé : le serveur et le poste s'authentifient mutuellement par certificats. Avec `domain_suffix_match="autre.lab.local"`, l'échange échoue côté poste : le certificat du serveur ne porte pas ce nom. C'est la vérification indispensable en PEAP-MSCHAPv2 ; sans elle, un faux point d'accès présente son propre certificat et récupère les échanges MSCHAPv2, dont il peut extraire les mots de passe.

## Questions

1. Moindre privilège : `cn=admin` a tous les droits sur l'annuaire, en lecture et en écriture. Son mot de passe, stocké dans la configuration de FreeRADIUS, exposerait tout l'annuaire en cas de fuite. Le compte de service ne sert qu'à rechercher les utilisateurs et les groupes.
2. L'attribut **`Message-Authenticator`** (HMAC-MD5 sur tout le paquet), exigé par `require_message_authenticator = yes` dans `clients.conf` côté serveur, et envoyé par l'équipement (dans pfSense, *Disable Message Authenticator* décoché).
3. Un échec d'**autorisation** : l'authentification a réussi (le *bind* LDAP au nom de bob fonctionne), mais la politique `lab_admins`, dans la section `post-auth` de FreeRADIUS, le refuse parce qu'il n'est pas membre du groupe `admins`.
4. La **validation stricte du certificat du serveur RADIUS** (AC attendue et nom du serveur attendu), déployée sur les postes et non modifiable par l'utilisateur. Sans elle, un faux point d'accès se fait passer pour le réseau de l'entreprise et récupère les échanges MSCHAPv2, donc les mots de passe.

---

[← TP3](../../tp3/README.md) · [Sommaire](../../README.md) · [Énoncé](../README.md) · [En cas de blocage](../../en-cas-de-blocage.md) · [TP5 →](../../tp5/README.md)
