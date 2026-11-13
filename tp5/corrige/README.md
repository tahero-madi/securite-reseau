# Corrigé du TP5

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

**Préparation.** Vérifier que l'interface WAN de pfSense supporte netmap pour le mode inline (sinon utiliser Legacy, qui bloque par ajout dynamique de l'IP source à une table — moins précis, basé sur l'IP et non le paquet). La première mise à jour des règles ET Open peut être volumineuse : la faire au provisioning si la bande passante est limitée. Le rôle « extérieur » est tenu par `ext` (10.10.0.40) ; une fois bloqué en mode IPS, son adresse apparaît dans *Blocks* (la débloquer pour la suite). Rappeler de retirer la publication du port 80 en fin de TP.

**Le piège de ce laboratoire : `HOME_NET`.** Le WAN est en adresses privées (10.10.0.0/24). Par défaut, Suricata sur pfSense met dans `HOME_NET` tous les réseaux connectés, WAN compris, et dans la *Pass List* les réseaux locaux et la passerelle. Conséquences : `ext` est « interne », les règles `$EXTERNAL_NET → $HOME_NET` ne se déclenchent pas, et en mode Legacy son adresse ne serait jamais bloquée (elle est dans la Pass List). D'où la Pass List `lab_home` (10.1.0.0/16 seulement) utilisée à la fois comme *Home Net* et comme *Pass List*. Si aucune alerte n'arrive, vérifier ce point en premier : c'est aussi l'occasion de montrer qu'une variable mal définie rend un IDS aveugle sans aucun message d'erreur.

**Partie B.** Les actions doivent générer des alertes ET Open (scan, et selon les catégories, tentative web). Si aucune alerte ET ne matche l'injection, ce n'est pas grave : la partie C ajoute les règles maison qui, elles, matcheront à coup sûr.

**Partie C.** Erreurs classiques : `sid` en double (Suricata ne démarre pas) ; règle sur la mauvaise interface ; sens du flux incorrect (`to_server`). Vérifier que chaque apprenant utilise bien sa plage `9000X..`. Montrer la structure action/en-tête/options et l'intérêt des *sticky buffers* (`http.uri`) vs `content` brut.

**Partie D.** Le passage en IPS doit produire un blocage **observable** (curl qui échoue, IP dans la liste Blocks). Insister : un faux positif en IPS coupe un flux légitime → d'où le réglage avant blocage généralisé. Le `suppress` cible une règle pour une source précise (on garde la protection ailleurs) ; désactiver la règle la supprime partout. Documenter toute exception.

**Défi.** La sonde WAN ne voit que ce qui traverse le pare-feu ; le trafic est-ouest interne (déplacement latéral) lui échappe → nécessité de sondes internes / entre zones. Bon lien avec la détection du mouvement latéral (modules 1 et 5).

**Questions.** 1 : éviter de bloquer du trafic légitime (faux positifs) tant que les règles ne sont pas réglées ; valider d'abord en observation. 2 : désactiver = la règle ne s'applique plus nulle part (perte de couverture) ; `suppress` = la règle reste active mais on ignore les correspondances pour une source identifiée comme légitime. 3 : le trafic intra-VLAN est commuté localement et ne passe pas par le routeur/pare-feu où est la sonde.

---

[← TP4](../../tp4/README.md) · [Sommaire](../../README.md) · [Énoncé](../README.md) · [En cas de blocage](../../en-cas-de-blocage.md) · [TP6 →](../../tp6/README.md)
