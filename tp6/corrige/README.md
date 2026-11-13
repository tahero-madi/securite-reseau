# Corrigé du TP6

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

**Préparation.** Rien à installer : `cloud-gw` est un conteneur privilégié avec strongSwan (`swanctl`, service `strongswan`), nftables et ulogd2. `fw` (203.0.113.11) et `cloud-gw` (203.0.113.21) sont sur le même segment « Internet » : pas de NAT entre eux, donc pas de NAT-T. Côté pfSense, la règle *IPsec* doit autoriser srv-int → 10.101.1.1, et le WAN doit accepter UDP 500/4500 + ESP depuis 203.0.113.21. La PSK doit être identique des deux côtés (source d'erreur n°1).

**Parties A/B.** Erreurs classiques : propositions crypto non symétriques entre pfSense et strongSwan (la P1/P2 doit correspondre : `aes256gcm16-sha256-ecp256` ↔ AES-256-GCM / SHA-256 / DH19) ; sélecteurs de trafic inversés (local/remote) ; ports IKE non ouverts sur WAN ; PSK différente. `swanctl --list-sas` et *Status → IPsec* doivent montrer ESTABLISHED. Si NAT entre les deux, NAT-T (4500) prend le relais.

**Partie C.** La capture ne doit montrer que ISAKMP (500/4500) + ESP (proto 50). C'est la preuve visuelle du chiffrement. Bien faire comparer avec un flux direct non tunnelé (lisible). Rappeler que les sélecteurs limitent la portée et que le filtrage reste nécessaire.

**Partie D.** Le parallèle nftables ↔ Security Groups est le cœur pédagogique du module 6 : refus par défaut, autorisations explicites par rôle/source, à états. Les journaux de refus préfigurent les Flow Logs.

**Partie E.** Vérifier que les apprenants ne confondent pas SG (à états, par instance) et NACL (sans état, par sous-réseau), et qu'ils notent le piège Azure `AllowVnetInBound`. Pour SSH, valoriser les accès sans exposition (SSM / Bastion).

**Questions.** 1 : IKEv2, AES-256-GCM, SHA-256, DH groupe 19, PFS activée, PSK forte (ou certificats), durées de vie raisonnables. 2 : ESP encapsule et chiffre le paquet IP d'origine ; sur le lien intermédiaire on ne voit que l'enveloppe ESP, pas la charge applicative. 3 : une référence entre groupes suit automatiquement l'élasticité (ajout/retrait d'instances) sans réécrire les règles, et exprime l'intention (rôle→rôle) plutôt qu'une topologie d'adresses figée.

---

[← TP5](../../tp5/README.md) · [Sommaire](../../README.md) · [Énoncé](../README.md) · [En cas de blocage](../../en-cas-de-blocage.md) · [TP7 →](../../tp7/README.md)
