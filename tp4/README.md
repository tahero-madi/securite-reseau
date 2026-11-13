# TP4 — Authentification réseau : LDAP, RADIUS, 802.1X

**Jour 2, 13:40 · 2 h 10, pause incluse.** Objectifs : exploiter un annuaire LDAP ; configurer FreeRADIUS adossé à LDAP ; comprendre et préparer 802.1X (EAP) ; durcir RADIUS ; authentifier les administrateurs de pfSense sur RADIUS.

**Prérequis** : module 4, TP 3. **Livrable** : traces de tests `radtest` réussis/échoués, configuration `clients.conf` durcie (extrait), capture d'une authentification pfSense via RADIUS, note sur le choix de méthode EAP.

## Partie A — Explorer l'annuaire LDAP (25 min)

1. Rebondissez en SSH sur `srv-int`. L'annuaire OpenLDAP est préchargé (base `dc=lab,dc=local`, unités `people` et `groups`). Explorez-le :

```bash
ldapsearch -x -H ldap://localhost -b "dc=lab,dc=local" -D "cn=admin,dc=lab,dc=local" -W "(objectClass=inetOrgPerson)" uid cn
```

2. Repérez les groupes (`ou=groups`), par exemple `admins` et `users`. Notez le DN d'un utilisateur de chaque groupe.
3. Vérifiez le chiffrement. Sur le poste, ouvrez Wireshark sur `v-srv-int` (port miroir de srv-int), filtre `ldap`. Depuis un terminal **du poste**, faites un *bind* en clair :

```bash
ldapsearch -x -H ldap://10.1.20.10 -D "uid=alice,ou=people,dc=lab,dc=local" -W -b "dc=lab,dc=local" "(uid=alice)"
```

Constatez que le *bind* simple expose le mot de passe d'alice dans la capture. Refaites le test en **LDAPS** (port 636, certificat signé par l'AC du lab, déjà approuvée par le poste) : la capture ne montre plus que du TLS. Comment **forcer** le chiffrement côté serveur (indice : `olcSecurity` ou suppression de `ldap:///` dans `/etc/default/slapd`) ?

```bash
ldapsearch -x -H ldaps://srv-int.lab.local -b "dc=lab,dc=local" -D "cn=svc-radius,ou=services,dc=lab,dc=local" -W "(uid=alice)"
```

## Partie B — FreeRADIUS adossé à LDAP (40 min)

4. Sur `srv-int`, activez le module LDAP de FreeRADIUS :

```bash
sudo ln -sf /etc/freeradius/3.0/mods-available/ldap /etc/freeradius/3.0/mods-enabled/
```

Éditez `/etc/freeradius/3.0/mods-enabled/ldap` : `server`, `base_dn = "ou=people,dc=lab,dc=local"`, compte de service `identity = "cn=svc-radius,ou=services,dc=lab,dc=local"`, `password`, et `tls { ... }` pour LDAPS. Dans `sites-enabled/default` et `inner-tunnel`, décommentez `ldap` dans `authorize` (et activez la réécriture de `Auth-Type LDAP` pour le bind si nécessaire).

5. Déclarez le NAS dans `/etc/freeradius/3.0/clients.conf` (ici, pfSense) avec un **secret long et unique** :

```text
client fw {
    ipaddr = 10.1.20.1        # adresse de pfSense côté SRV : c'est elle qui émet les requêtes
    secret = <32+ caractères aléatoires>
    require_message_authenticator = yes
    nas_type = other
}
```

6. Lancez FreeRADIUS en mode débogage et testez :

```bash
sudo systemctl stop freeradius
sudo freeradius -X        # observer le démarrage, les erreurs éventuelles
# dans un autre terminal :
radtest alice <motdepasse> localhost 0 testing123
```

Observez l'`Access-Accept`. Testez un mauvais mot de passe → `Access-Reject`. Repérez dans la sortie `-X` l'appel au module LDAP.

> **`require_message_authenticator = yes`** impose la présence de l'attribut qui neutralise BlastRADIUS (module 4). Vérifiez que le NAS (pfSense) sait l'envoyer ; sinon, mettez-le à jour. Ne jamais garder le secret d'exemple `testing123` en production.

## Partie C — Autorisation par groupe (20 min)

7. Faites en sorte que seuls les membres du groupe `admins` reçoivent un attribut d'autorisation spécifique (par exemple une classe ou un VLAN). Utilisez le module LDAP pour récupérer l'appartenance au groupe et, dans `post-auth`, ajoutez l'attribut conditionnel. Testez avec un membre et un non-membre de `admins`.

> **Défi ★ — EAP-TLS.** Générez une PKI de laboratoire (ou utilisez celle fournie), créez un certificat client pour `alice`, configurez le module `eap` en `default_eap_type = tls`, et testez avec `eapol_test` (paquet `wpa_supplicant`) un échange EAP-TLS. Comparez la robustesse avec PEAP-MSCHAPv2 où le certificat serveur n'est pas vérifié.

## Partie D — Authentifier les admins pfSense via RADIUS (25 min)

8. Sur `fw` : *System → User Manager → Authentication Servers → Add*, type RADIUS, hôte `10.1.20.10`, secret identique à `clients.conf`, services « Authentication », port 1812.
9. *Diagnostics → Authentication* : testez avec `alice`. Puis, dans *System → User Manager → Settings*, placez le serveur RADIUS comme source d'authentification de la GUI (en conservant le compte local de secours).
10. Déconnectez-vous et reconnectez-vous à pfSense avec un compte LDAP via RADIUS. Pendant le test, capturez l'échange (Wireshark sur `v-srv-int`, filtre `radius`) : identifiez `Access-Request`, `Access-Accept`, la présence de `Message-Authenticator`.

**Livrable** : traces `radtest` (accept/reject), extrait `clients.conf`, capture RADIUS annotée, note (5 lignes) justifiant le choix EAP-TLS vs PEAP pour un déploiement 802.1X.

## Questions de validation

1. Pourquoi faut-il un compte de service LDAP dédié pour FreeRADIUS plutôt que `cn=admin` ?
2. Quel attribut RADIUS et quelle valeur neutralisent BlastRADIUS ?
3. En PEAP-MSCHAPv2, quel réglage côté poste est indispensable et pourquoi ?

---

[← TP3](../tp3/README.md) · [Sommaire](../README.md) · [Corrigé](corrige/README.md) · [En cas de blocage](../en-cas-de-blocage.md) · [TP5 →](../tp5/README.md)
