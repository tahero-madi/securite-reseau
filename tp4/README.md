# TP4 — Authentification réseau : LDAP, RADIUS, 802.1X

**Jour 2, 13:40 · 2 h 10, pause incluse.** Objectifs : exploiter un annuaire LDAP et constater l'intérêt de LDAPS ; adosser FreeRADIUS à cet annuaire ; durcir RADIUS (secret long et unique, `Message-Authenticator`) ; faire de l'**autorisation** par groupe, pas seulement de l'authentification ; authentifier les administrateurs de pfSense sur RADIUS.

**Prérequis** : module 4, TP3 terminé (la règle L4 autorise la Kali à joindre `srv-int` en 22, 389 et 636). **Livrable** : traces `radtest` (accepté et refusé), extrait de `clients.conf`, capture RADIUS annotée, note sur le choix de la méthode EAP, dans `~/livrables`.

**Déroulé** : étapes 1 à 4 (LDAP) 25 min · étapes 5 à 8 (FreeRADIUS) 40 min · étape 9 (autorisation par groupe) 20 min · étapes 10 à 12 (pfSense) 25 min.

> **Instantané conseillé.** Avant de commencer, prenez un instantané de `srv-int` et de pfSense depuis le portail (par exemple `avant-tp4`).

Les mots de passe du laboratoire (annuaire, compte de service, utilisateurs) sont dans `~/TP/identifiants-lab.txt` sur la Kali :

| Compte | DN | Mot de passe | Rôle |
|---|---|---|---|
| Administrateur de l'annuaire | `cn=admin,dc=lab,dc=local` | `Ldap-Admin-3020` | Tous les droits sur l'annuaire |
| Compte de service RADIUS | `cn=svc-radius,ou=services,dc=lab,dc=local` | `Svc-Radius-3020` | Recherches de FreeRADIUS |
| alice | `uid=alice,ou=people,dc=lab,dc=local` | `Alice-3020` | Groupe `admins` |
| bob | `uid=bob,ou=people,dc=lab,dc=local` | `Bob-3020` | Groupe `users` |
| carol | `uid=carol,ou=people,dc=lab,dc=local` | `Carol-3020` | Groupe `users` |

## Étape 1 — Explorer l'annuaire

**Pourquoi.** FreeRADIUS va chercher les utilisateurs dans l'annuaire OpenLDAP de `srv-int`. Avant de le brancher, on regarde comment cet annuaire est organisé : où sont les personnes, où sont les groupes, comment on désigne une entrée.

Depuis la Kali, connectez-vous à `srv-int`, puis listez les personnes :

```bash
ssh formation@10.1.20.10
ldapsearch -x -LLL -H ldap://localhost -D "cn=admin,dc=lab,dc=local" -W -b "dc=lab,dc=local" "(objectClass=inetOrgPerson)" uid cn mail
```

**Ligne par ligne.**

- `ssh formation@10.1.20.10` : ouvre une session sur `srv-int` avec le compte `formation` (mot de passe : portail Hexceos, bouton clé). Les commandes suivantes s'exécutent sur `srv-int`.
- `ldapsearch` : l'outil de recherche LDAP en ligne de commande.
- `-x` : authentification **simple** (un DN et un mot de passe), par opposition à SASL.
- `-LLL` : affichage au format LDIF, sans commentaires ni ligne de version : plus lisible.
- `-H ldap://localhost` : le serveur à interroger, ici l'annuaire local, sur le port 389.
- `-D "cn=admin,dc=lab,dc=local"` : le DN avec lequel on s'authentifie (*bind*), ici l'administrateur de l'annuaire.
- `-W` : demande le mot de passe de ce DN au clavier (`Ldap-Admin-3020`), sans l'afficher ni le laisser dans l'historique.
- `-b "dc=lab,dc=local"` : la **base** de la recherche, ici la racine de l'annuaire.
- `"(objectClass=inetOrgPerson)"` : le **filtre** : toutes les entrées qui sont des personnes.
- `uid cn mail` : les seuls attributs à afficher.

Vous obtenez trois entrées. Leur DN se lit de gauche à droite, de la feuille vers la racine : `uid=alice,ou=people,dc=lab,dc=local` est l'entrée `alice`, dans l'unité `people`, dans le domaine `lab.local`.

## Étape 2 — Repérer les groupes

**Pourquoi.** L'autorisation de l'étape 9 reposera sur l'appartenance au groupe `admins`. Il faut savoir comment l'annuaire l'enregistre.

```bash
ldapsearch -x -LLL -H ldap://localhost -D "cn=admin,dc=lab,dc=local" -W -b "ou=groups,dc=lab,dc=local" "(objectClass=groupOfNames)" cn member
```

**Ligne par ligne.**

- `-b "ou=groups,dc=lab,dc=local"` : la recherche part cette fois de l'unité `groups`.
- `"(objectClass=groupOfNames)"` : les entrées de type groupe.
- `cn member` : le nom du groupe et ses membres.

Chaque groupe liste ses membres par leur **DN complet** dans l'attribut `member` : `admins` contient `alice`, `users` contient `bob` et `carol`. Notez-le : c'est ce lien que FreeRADIUS interrogera.

## Étape 3 — Constater le mot de passe en clair

**Pourquoi.** Une authentification simple sur `ldap://` envoie le mot de passe tel quel sur le réseau. On le vérifie de ses yeux, depuis le point de vue de quelqu'un qui capture le trafic.

Sur la **Kali**, ouvrez Wireshark sur `eth0` avec le filtre d'affichage `ldap`, lancez la capture, puis, dans un **terminal de la Kali** (pas dans la session SSH) :

```bash
ldapsearch -x -LLL -H ldap://10.1.20.10 -D "uid=alice,ou=people,dc=lab,dc=local" -W -b "dc=lab,dc=local" "(uid=alice)" cn
```

**Ligne par ligne.**

- `-H ldap://10.1.20.10` : l'annuaire de `srv-int`, joint depuis la Kali sur le port 389, à travers pfSense (règle L4).
- `-D "uid=alice,…"` puis `-W` : alice s'authentifie elle-même, avec son mot de passe `Alice-3020`.
- `"(uid=alice)" cn` : elle lit son propre nom.

Dans Wireshark, ouvrez le paquet `bindRequest` : le champ `simple` contient `Alice-3020`, **en clair**. Quiconque se trouve sur le chemin (usurpation ARP du TP1, port miroir, équipement compromis) le lit de la même façon.

## Étape 4 — Passer en LDAPS

**Pourquoi.** LDAPS chiffre toute la connexion avec TLS, avant même l'authentification. Mais un chiffrement ne protège que si le client **vérifie** qu'il parle au bon serveur : il lui faut le certificat de l'autorité de certification (AC) du laboratoire, et le nom exact du serveur.

Sur la Kali, changez le filtre Wireshark en `tcp.port == 636`, puis :

```bash
scp formation@10.1.20.10:pki/ca.crt ~/pki/ca-lab.crt
LDAPTLS_CACERT=~/pki/ca-lab.crt ldapsearch -x -LLL -H ldaps://srv-int.lab.local -D "cn=svc-radius,ou=services,dc=lab,dc=local" -W -b "ou=people,dc=lab,dc=local" "(uid=alice)" dn
```

**Ligne par ligne.**

- `scp formation@10.1.20.10:pki/ca.crt ~/pki/ca-lab.crt` : copie le certificat **public** de l'AC du laboratoire depuis le dossier `pki` de `formation` sur `srv-int`, vers `~/pki/ca-lab.crt` sur la Kali.
- `LDAPTLS_CACERT=~/pki/ca-lab.crt` : variable d'environnement, valable pour cette seule commande, qui indique à `ldapsearch` quelle AC accepter pour vérifier le certificat du serveur.
- `-H ldaps://srv-int.lab.local` : LDAP sur TLS, port 636. On utilise le **nom** du serveur, car c'est lui qui figure dans son certificat ; avec l'adresse IP, la vérification échoue.
- `-D "cn=svc-radius,…"` : on s'authentifie cette fois avec le compte de service de FreeRADIUS (`Svc-Radius-3020`), pour vérifier qu'il fonctionne avant de le confier à FreeRADIUS.
- `-b "ou=people,…" "(uid=alice)" dn` : retrouve le DN d'alice, exactement la recherche que fera FreeRADIUS.

Dans Wireshark, vous ne voyez plus que la poignée de main TLS puis des *Application Data* : plus aucun mot de passe lisible.

> **Si la commande échoue** (« Can't contact LDAP server ») : l'AC n'est pas fournie, le nom n'est pas `srv-int.lab.local`, ou la règle L4 du TP3 n'inclut pas le port 636.

**Question.** L'annuaire accepte encore `ldap://` en clair sur le port 389. Comment **interdire** les connexions non chiffrées côté serveur ? Notez votre réponse (indice : `/etc/default/slapd`, ou l'attribut `olcSecurity`). Ne l'appliquez pas aujourd'hui : l'audit du TP8 doit encore pouvoir le constater.

## Étape 5 — Brancher FreeRADIUS sur l'annuaire

**Pourquoi.** FreeRADIUS est installé avec sa configuration par défaut ; son module `ldap` est présent mais inactif. On le configure pour qu'il cherche les utilisateurs dans l'annuaire, en LDAPS, avec le compte de service en lecture seule, jamais avec `cn=admin`.

Sur **`srv-int`** (dans la session SSH) :

```bash
sudo cp /etc/freeradius/3.0/mods-available/ldap /etc/freeradius/3.0/mods-available/ldap.orig
sudo tee /etc/freeradius/3.0/mods-available/ldap > /dev/null <<'EOF'
ldap {
	server = 'ldaps://srv-int.lab.local'
	identity = 'cn=svc-radius,ou=services,dc=lab,dc=local'
	password = 'Svc-Radius-3020'
	base_dn = 'dc=lab,dc=local'
	user {
		base_dn = "ou=people,${..base_dn}"
		filter = "(uid=%{%{Stripped-User-Name}:-%{User-Name}})"
	}
	group {
		base_dn = "ou=groups,${..base_dn}"
		filter = '(objectClass=groupOfNames)'
		name_attribute = cn
		membership_filter = "(member=%{control:LDAP-UserDn})"
	}
	tls {
		ca_file = /etc/freeradius/3.0/certs/lab/ca.pem
		require_cert = 'demand'
	}
}
EOF
sudo ln -sf ../mods-available/ldap /etc/freeradius/3.0/mods-enabled/ldap
```

**Ligne par ligne.**

- `sudo cp … ldap ldap.orig` : garde une copie du fichier d'origine, très commenté, pour pouvoir le relire ou revenir en arrière.
- `sudo tee … > /dev/null <<'EOF'` … `EOF` : remplace le contenu du fichier par les lignes comprises entre les deux `EOF`. `tee` s'exécute avec `sudo`, ce que ne permettrait pas une simple redirection `>` ; `> /dev/null` évite de réafficher le texte ; les apostrophes de `'EOF'` empêchent le shell d'interpréter les `${…}` et `%{…}`, destinés à FreeRADIUS.
- `server = 'ldaps://srv-int.lab.local'` : l'annuaire, joint en LDAPS (port 636), par le nom présent dans son certificat.
- `identity` et `password` : le **compte de service** avec lequel FreeRADIUS fait ses recherches.
- `base_dn = 'dc=lab,dc=local'` : la racine de l'annuaire.
- `user { … }` : où et comment trouver un utilisateur : dans `ou=people` (`${..base_dn}` reprend la racine définie plus haut), avec le filtre `(uid=<nom saisi>)`.
- `group { … }` : où trouver les groupes (`ou=groups`), de quel type (`groupOfNames`), quel attribut donne leur nom (`cn`), et comment savoir si l'utilisateur en est membre : un groupe dont l'attribut `member` contient son DN (`%{control:LDAP-UserDn}`, retrouvé par la recherche de l'utilisateur).
- `tls { … }` : l'AC du laboratoire (copiée par l'installation dans `certs/lab/ca.pem`) et `require_cert = 'demand'` : FreeRADIUS refuse de parler à un annuaire dont le certificat n'est pas valide.
- `sudo ln -sf ../mods-available/ldap …/mods-enabled/ldap` : active le module. FreeRADIUS ne charge que les modules présents dans `mods-enabled`, sous forme de liens vers `mods-available`.

## Étape 6 — Authentifier par l'annuaire

**Pourquoi.** Le compte de service ne peut pas lire les mots de passe des utilisateurs (ils sont protégés par l'annuaire, et c'est bien ainsi). FreeRADIUS vérifiera donc le mot de passe en tentant une connexion LDAP **au nom de l'utilisateur** : si elle réussit, le mot de passe est bon. Il faut activer ce mode, prévu mais commenté dans la configuration par défaut.

```bash
cd /etc/freeradius/3.0/sites-available
sudo sed -i '/^#\tif ((ok || updated) && User-Password/,/^#\t}/ s/^#//' default
sudo sed -i '/^#\tAuth-Type LDAP {/,/^#\t}/ s/^#//' default
grep -n -A4 -e 'Auth-Type := ldap' -e '^\s*Auth-Type LDAP' default
```

**Ligne par ligne.**

- `cd /etc/freeradius/3.0/sites-available` : le dossier des « serveurs virtuels » ; `default` traite les requêtes RADIUS ordinaires.
- Premier `sed -i` : retire le `#` en début de ligne (`s/^#//`) sur le bloc qui commence par `#	if ((ok || updated) && User-Password` et se termine à la première ligne `#	}`. Ce bloc, dans la section `authorize`, dit : « si le module ldap a trouvé l'utilisateur et qu'un mot de passe a été saisi, l'authentification se fera par LDAP » (`Auth-Type := ldap`).
- Second `sed -i` : décommente de la même façon le bloc `Auth-Type LDAP { ldap }`, dans la section `authenticate` : c'est lui qui exécute la connexion LDAP au nom de l'utilisateur.
- `grep -n -A4 …` : affiche les deux blocs avec leurs numéros de ligne et les 4 lignes suivantes. Ils ne doivent plus commencer par `#`. Si `grep` n'affiche rien, ouvrez le fichier (`sudo nano default`), cherchez `Auth-Type LDAP` et retirez les `#` à la main.

## Étape 7 — Déclarer pfSense comme client RADIUS

**Pourquoi.** Le client RADIUS n'est pas l'utilisateur, c'est l'**équipement** qui pose la question au serveur : ici pfSense, qui interrogera `srv-int` depuis son adresse côté SRV, 10.1.20.1. FreeRADIUS ignore toute requête d'un équipement non déclaré. Chaque équipement a son **secret partagé**, long, aléatoire et unique ; on exige en plus l'attribut `Message-Authenticator`, qui neutralise l'attaque BlastRADIUS (module 4).

```bash
SECRET=$(openssl rand -base64 33)
echo "$SECRET"
sudo tee -a /etc/freeradius/3.0/clients.conf > /dev/null <<EOF

client pfsense {
	ipaddr = 10.1.20.1
	secret = $SECRET
	require_message_authenticator = yes
	shortname = pfsense
}
EOF
sudo tail -7 /etc/freeradius/3.0/clients.conf
```

**Ligne par ligne.**

- `SECRET=$(openssl rand -base64 33)` : tire 33 octets aléatoires et les encode en base64, soit un secret de 44 caractères, stocké dans la variable `SECRET`.
- `echo "$SECRET"` : l'affiche. **Copiez-le** dans un fichier de votre Kali : vous le saisirez dans pfSense à l'étape 10.
- `sudo tee -a … <<EOF` : **ajoute** (`-a`) le bloc à la fin de `clients.conf`, sans effacer les clients existants. Ici `EOF` est sans apostrophes : le shell remplace `$SECRET` par sa valeur.
- `client pfsense { … }` : la déclaration d'un client : `ipaddr`, l'adresse d'où viendront ses requêtes ; `secret`, le secret partagé ; `require_message_authenticator = yes`, le refus de toute requête sans `Message-Authenticator` ; `shortname`, le nom affiché dans les journaux.
- `sudo tail -7 …` : affiche les 7 dernières lignes du fichier pour vérifier le bloc ajouté. Copiez-les dans votre livrable (`tp4-clients-conf.txt`), en masquant le secret.

## Étape 8 — Tester en mode débogage

**Pourquoi.** `freeradius -X` est l'outil de diagnostic numéro un : il lance le serveur au premier plan et détaille chaque requête, module par module. On vérifie que la configuration se charge, que l'annuaire répond, et que les bons mots de passe sont acceptés et les mauvais refusés.

Dans la session SSH sur `srv-int` :

```bash
sudo systemctl stop freeradius
sudo freeradius -X
```

**Ligne par ligne.**

- `sudo systemctl stop freeradius` : arrête le service ; sinon, le port 1812 est déjà occupé et le mode débogage ne démarre pas.
- `sudo freeradius -X` : lance FreeRADIUS au premier plan, en mode débogage complet. La dernière ligne doit être `Ready to process requests`. En cas d'erreur, le message indique le fichier et la ligne en cause.

Ouvrez un **second terminal** sur la Kali, reconnectez-vous à `srv-int` (`ssh formation@10.1.20.10`), puis :

```bash
radtest alice Alice-3020 localhost 0 testing123
radtest alice mauvais localhost 0 testing123
radtest bob Bob-3020 localhost 0 testing123
```

**Ligne par ligne.**

- `radtest <utilisateur> <mot de passe> <serveur> <port NAS> <secret>` : envoie une requête RADIUS de test. Le serveur est `localhost`, déclaré par défaut comme client avec le secret d'exemple `testing123` (acceptable pour un test local, jamais en production). Le `0` est un numéro de port d'accès fictif.
- Première commande : `Received Access-Accept` : alice est authentifiée.
- Deuxième : `Received Access-Reject` (après une seconde) : mauvais mot de passe.
- Troisième : `Access-Accept` également : bob est authentifié. Pour l'instant, tout utilisateur de l'annuaire est accepté : l'étape 9 corrigera cela.

Dans le **premier terminal**, retrouvez dans la sortie de `-X`, pour la requête d'alice : les lignes `ldap` qui montrent la connexion à `ldaps://srv-int.lab.local` avec le compte `cn=svc-radius,…`, puis `User object found at DN "uid=alice,…"`, puis le passage dans `Auth-Type LDAP`, avec une seconde connexion au nom d'alice. Copiez les sorties de `radtest` dans votre livrable (`tp4-radtest.txt`).

## Étape 9 — Autoriser par groupe

**Pourquoi.** S'authentifier, c'est prouver qui l'on est ; être autorisé, c'est avoir le droit de faire quelque chose. Bob a un compte valide, mais il n'est pas administrateur : il ne doit pas pouvoir administrer pfSense, même avec le bon mot de passe. On ajoute une règle : membres de `admins` acceptés, avec l'attribut `Class` qui indiquera leur groupe à pfSense ; tous les autres refusés.

Arrêtez `freeradius -X` (**Ctrl+C** dans le premier terminal), puis :

```bash
sudo tee /etc/freeradius/3.0/policy.d/lab-admins > /dev/null <<'EOF'
lab_admins {
	if (LDAP-Group == "admins") {
		update reply {
			&Class := "lab-admins"
		}
	}
	else {
		reject
	}
}
EOF
sudo sed -i '/^post-auth {/a lab_admins' /etc/freeradius/3.0/sites-available/default
grep -n -A1 '^post-auth {' /etc/freeradius/3.0/sites-available/default
sudo freeradius -X
```

**Ligne par ligne.**

- `sudo tee …/policy.d/lab-admins` : crée une **politique**, c'est-à-dire un bloc de règles nommé, réutilisable. FreeRADIUS lit au démarrage tous les fichiers de `policy.d`.
- `if (LDAP-Group == "admins")` : interroge l'annuaire (selon la section `group` de l'étape 5) pour savoir si l'utilisateur est membre du groupe `admins`.
- `update reply { &Class := "lab-admins" }` : ajoute à la réponse l'attribut RADIUS `Class`, avec la valeur `lab-admins`. pfSense s'en servira pour rattacher l'utilisateur à son groupe local du même nom.
- `else { reject }` : tout autre utilisateur reçoit un `Access-Reject`, même avec le bon mot de passe.
- `sudo sed -i '/^post-auth {/a lab_admins' …` : ajoute la ligne `lab_admins` juste après `post-auth {`, pour appeler la politique après chaque authentification réussie.
- `grep -n -A1 '^post-auth {' …` : vérifie que `lab_admins` est bien la ligne suivante.
- `sudo freeradius -X` : relance le serveur en mode débogage avec la nouvelle politique.

Dans le second terminal, relancez :

```bash
radtest alice Alice-3020 localhost 0 testing123
radtest bob Bob-3020 localhost 0 testing123
```

**Ligne par ligne.**

- alice : `Access-Accept`, avec dans la réponse `Class = 0x6c61622d61646d696e73` (« lab-admins » en hexadécimal).
- bob : `Access-Reject`. Dans la sortie de `-X`, repérez la comparaison `LDAP-Group == "admins"` qui échoue, puis le `reject`.

Ajoutez ces deux sorties à `tp4-radtest.txt`. Enfin, arrêtez le mode débogage (**Ctrl+C**) et **relancez le service**, indispensable pour la suite :

```bash
sudo systemctl start freeradius
systemctl is-active freeradius
```

**Ligne par ligne.**

- `sudo systemctl start freeradius` : redémarre FreeRADIUS comme service, en arrière-plan.
- `systemctl is-active freeradius` : doit répondre `active`.

## Étape 10 — Préparer pfSense

**Pourquoi.** pfSense devient le client RADIUS. Il lui faut l'adresse du serveur et le secret partagé ; et, pour donner des droits aux utilisateurs authentifiés par RADIUS, un **groupe local** dont le nom correspond à l'attribut `Class` renvoyé par FreeRADIUS.

Sur pfSense (`https://10.1.10.1`) :

1. *System → User Manager → Groups* → **Add** : *Group name* `lab-admins`, *Scope* **Remote**, *Description* « Administrateurs authentifiés par RADIUS » ; **Save**. Rouvrez le groupe (crayon), *Assigned Privileges* → **Add**, choisissez **WebCfg - All pages**, **Save**, puis **Save** à nouveau.
2. *System → User Manager → Authentication Servers* → **Add** :
   - *Descriptive name* : `RADIUS srv-int` ; *Type* : **RADIUS** ;
   - *Protocol* : **PAP** ;
   - *Hostname or IP address* : `10.1.20.10` ;
   - *Shared Secret* : le secret de l'étape 7 ;
   - *Services offered* : **Authentication** ; *Authentication port* : `1812` ;
   - *Disable Message Authenticator* : **non coché** ;
   - *RADIUS NAS IP Attribute* : **SRV** ;
   - **Save**.

**Pourquoi PAP ?** FreeRADIUS vérifie le mot de passe par une connexion LDAP au nom de l'utilisateur : il a besoin du mot de passe lui-même, que PAP transmet masqué avec le secret partagé. Les méthodes à défi (CHAP, MS-CHAPv2) ne le transmettent pas, et ne fonctionneraient pas ici. C'est acceptable sur un réseau d'administration maîtrisé, avec un secret fort et `Message-Authenticator` ; hors de ce cadre, on utilise RadSec ou une méthode EAP.

## Étape 11 — Tester depuis pfSense

**Pourquoi.** Avant de confier l'accès à l'interface d'administration à RADIUS, on teste sans risque : si quelque chose ne va pas, on n'est pas enfermé dehors.

*Diagnostics → Authentication* : *Authentication Server* `RADIUS srv-int`, puis testez successivement :

| Utilisateur | Mot de passe | Résultat attendu |
|---|---|---|
| `alice` | `Alice-3020` | *User alice authenticated successfully*, avec le groupe **lab-admins** |
| `alice` | un mauvais mot de passe | Échec |
| `bob` | `Bob-3020` | Échec : bob n'est pas autorisé |

> **Si tout échoue** : sur `srv-int`, `sudo journalctl -u freeradius -n 20` ; « Ignoring request from unknown client 10.1.20.1 » signale une adresse erronée dans `clients.conf` ; « Shared secret is incorrect » un secret différent. Le service FreeRADIUS doit être démarré (étape 9).

## Étape 12 — Administrer pfSense avec un compte de l'annuaire, et capturer l'échange

**Pourquoi.** C'est la chaîne complète : un administrateur se connecte à pfSense avec son compte de l'annuaire, pfSense interroge FreeRADIUS, qui interroge l'annuaire, puis applique la règle de groupe. On capture l'échange pour voir ce qui circule réellement sur le réseau.

1. *Diagnostics → Packet Capture* : *Interface* **SRV**, *Protocol* **UDP**, *Port* `1812`, **Start**.
2. *System → User Manager → Settings* : *Authentication Server* `RADIUS srv-int`, **Save**. Le compte local `admin` reste votre compte de secours : **gardez cette session ouverte** jusqu'à la fin du test.
3. Ouvrez une **fenêtre de navigation privée** de Firefox, allez sur `https://10.1.10.1` et connectez-vous avec `alice` / `Alice-3020`, puis essayez avec `bob` / `Bob-3020`.
4. Revenez dans la première fenêtre : *Packet Capture* → **Stop**, puis **Download Capture**, et enregistrez le fichier dans `~/livrables/tp4-radius.pcap`.

Ouvrez la capture dans Wireshark, avec le filtre `radius` :

- repérez l'`Access-Request` d'alice et l'`Access-Accept` qui suit (avec l'attribut `Class`), puis l'`Access-Request` de bob et son `Access-Reject` ;
- dans chaque paquet, repérez l'attribut **`Message-Authenticator`** ;
- le champ `User-Password` est **masqué**, mais le nom d'utilisateur, les adresses et l'attribut `Class` circulent **en clair** ;
- *Edit → Preferences → Protocols → RADIUS → Shared Secret* : collez le secret de l'étape 7. Wireshark affiche alors le mot de passe d'alice : la protection de PAP ne vaut **que** ce que vaut le secret partagé.

Annotez la capture (*Edit → Packet Comment*) sur ces points.

> **Retour arrière.** Si vous ne pouvez plus vous connecter avec `alice`, reconnectez-vous avec `admin` dans la fenêtre restée ouverte et remettez *Authentication Server* sur **Local Database**. En dernier recours : console de pfSense, ou restauration de l'instantané `avant-tp4`.

> **Défi ★ — EAP-TLS.** EAP-TLS est la méthode d'authentification 802.1X de référence : le poste présente un certificat au lieu d'un mot de passe. Sur `srv-int`, `~/pki/` contient le certificat d'alice (`alice.crt`, `alice.key`) et le certificat de l'AC ; les certificats du serveur RADIUS sont dans `/etc/freeradius/3.0/certs/lab/`. Activez EAP-TLS, puis simulez un poste 802.1X avec `eapol_test` :
>
> ```bash
> E=/etc/freeradius/3.0/mods-available/eap
> sudo cp $E $E.orig
> sudo sed -i -e '0,/default_eap_type = /s/default_eap_type = .*/default_eap_type = tls/' -e 's|^\(\s*private_key_password\s*=\)|#\1|' -e 's|^\(\s*private_key_file\s*=\).*|\1 ${certdir}/lab/server.key|' -e 's|^\(\s*certificate_file\s*=\).*|\1 ${certdir}/lab/server.pem|' -e 's|^\(\s*ca_file\s*=\).*|\1 ${certdir}/lab/ca.pem|' $E
> sudo systemctl restart freeradius
> cat > ~/tls.conf <<'EOF'
> network={
>     key_mgmt=WPA-EAP
>     eap=TLS
>     identity="alice"
>     ca_cert="/home/formation/pki/ca.crt"
>     domain_suffix_match="radius.lab.local"
>     client_cert="/home/formation/pki/alice.crt"
>     private_key="/home/formation/pki/alice.key"
> }
> EOF
> eapol_test -c ~/tls.conf -a 127.0.0.1 -s testing123 | tail -3
> ```
>
> - `sudo cp $E $E.orig` : copie de sauvegarde du module `eap`.
> - `sed -i -e … $E` : passe la méthode par défaut à `tls` (première occurrence seulement), désactive le mot de passe de clé d'exemple, et remplace la clé, le certificat et l'AC du serveur par ceux du laboratoire.
> - `sudo systemctl restart freeradius` : recharge la configuration.
> - `~/tls.conf` : la configuration du « poste » : méthode EAP-TLS, identité `alice`, AC attendue, **nom attendu du serveur** (`domain_suffix_match`), certificat et clé d'alice.
> - `eapol_test -c ~/tls.conf -a 127.0.0.1 -s testing123` : joue le rôle du commutateur et du poste, contre le serveur local ; la dernière ligne doit être `SUCCESS`.
>
> Remplacez ensuite `radius.lab.local` par `autre.lab.local` dans `tls.conf` et relancez : l'échange échoue, car le poste refuse un serveur dont le nom ne correspond pas. C'est exactement la vérification qui manque aux postes PEAP-MSCHAPv2 mal configurés, et qui permet à un faux point d'accès de récupérer les mots de passe.

**Livrable** (dans `~/livrables`) :

- `tp4-radtest.txt` : les sorties de `radtest` (alice acceptée avec `Class`, mauvais mot de passe refusé, bob refusé) ;
- `tp4-clients-conf.txt` : le bloc `client pfsense`, secret masqué ;
- `tp4-radius.pcap` : la capture annotée ;
- `tp4-note-eap.md` : cinq lignes justifiant le choix d'EAP-TLS plutôt que PEAP-MSCHAPv2 pour un déploiement 802.1X.

## Questions de validation

1. Pourquoi faut-il un compte de service LDAP dédié pour FreeRADIUS plutôt que `cn=admin` ?
2. Quel attribut RADIUS, et quel réglage de FreeRADIUS, neutralisent BlastRADIUS ?
3. Bob a donné le bon mot de passe et a pourtant été refusé : est-ce un échec d'authentification ou d'autorisation ? Où est-ce décidé ?
4. En PEAP-MSCHAPv2, quel réglage côté poste est indispensable, et pourquoi ?

---

[← TP3](../tp3/README.md) · [Sommaire](../README.md) · [Corrigé](corrige/README.md) · [En cas de blocage](../en-cas-de-blocage.md) · [TP5 →](../tp5/README.md)
