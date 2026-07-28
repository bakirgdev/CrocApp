---
sidebar_position: 6
title: Dépannage
description: "Des correctifs réels et documentés pour les problèmes courants de CrocApp : transferts bloqués, codes rejetés, limites d'arrière-plan et problèmes de permissions."
---

# Dépannage

## Le transfert se bloque ou ne se connecte jamais

CrocApp fait la course entre une connexion directe sur le réseau local et le relais, et utilise celle qui se connecte en premier. La découverte de pairs sur le réseau local utilise la diffusion multicast UDP, et rien ne garantit qu'elle fonctionne sur tous les réseaux, certains réseaux (un Wi-Fi de type isolation-client, par exemple) ne renvoient aucun pair local, même si la voie du relais fonctionne toujours correctement. Si un transfert reste bloqué sur "Waiting" ou "Connecting" :

- Vérifiez que les deux appareils ont un accès internet fonctionnel, pour que la voie du relais fonctionne même si la voie locale ne le peut pas.
- Vérifiez la [permission réseau local](#local-network-permission-prompt) ci-dessous.
- Il n'y a pas de correctif intégré à l'app pour un réseau qui bloque totalement la découverte multicast ; le transfert devrait tout de même aboutir via le relais.

## Code rejeté ou le bouton de réception reste désactivé

- Une phrase de code doit comporter au moins 6 caractères. Le bouton **Receive** reste désactivé tant que vous n'en avez pas saisi assez.
- Un code erroné échoue immédiatement plutôt que de rester bloqué.
- Si vous utilisez un code personnalisé également utilisé pour des tests ou des scripts, notez que des codes partageant leurs 4 premiers caractères peuvent entrer en collision dans le même salon de relais. Les codes générés n'ont pas ce problème.

## L'autre côté utilise une version différente de croc

CrocApp intègre croc v10.5.0 comme moteur. Il est conçu pour être interopérable avec le CLI `croc` dans les deux sens. Si l'autre côté exécute une version de `croc` très ancienne ou inhabituellement récente, utilisez une version du CLI raisonnablement à jour pour éviter les incompatibilités de protocole.

## Limites d'arrière-plan sur iOS

iOS ne permet pas aux transferts TCP bruts de continuer à s'exécuter indéfiniment en arrière-plan. CrocApp utilise `BGContinuedProcessingTask` (iOS 26+) pour maintenir un transfert en cours et afficher une Live Activity système, mais c'est du best-effort : le système peut l'arrêter en cas de pression mémoire, et un transfert peu avancé a plus de risques d'être interrompu qu'un transfert presque terminé. Pour un transfert que vous ne voulez pas voir interrompu, gardez CrocApp au premier plan jusqu'à la fin. S'il est tout de même coupé, le comportement de reprise propre à croc fait que relancer le même transfert reprend là où il s'est arrêté plutôt que de tout recommencer.

## Invite de permission réseau local {#local-network-permission-prompt}

Lors de la première utilisation du réseau local, iOS affiche une invite système demandant d'autoriser CrocApp à trouver des appareils sur votre réseau local. Si vous la refusez, ou si l'autorisation reste « bloquée » (un défaut connu d'iOS où une permission accordée ne fonctionne pas réellement tant que vous ne la basculez pas ou ne redémarrez pas), CrocApp se rabat uniquement sur le relais. Si vous voyez la bannière "Local network access is off — transfers use the relay only", utilisez son bouton **Open Settings** pour vérifier Réglages › Confidentialité › Réseau local.

## Fichiers reçus non visibles à l'endroit attendu

- Sur iOS, les fichiers reçus arrivent dans le dossier Documents de l'app, visible par défaut dans l'app Fichiers.
- Si votre destination de réception était réglée sur un dossier choisi via un fournisseur de stockage cloud (plutôt qu'un emplacement local), le bouton **Open in Files** après une réception peut ne pas l'ouvrir correctement, c'est une limitation connue. Accédez plutôt au dossier manuellement dans l'app Fichiers.

## Relais inaccessible

CrocApp utilise par défaut le relais public de croc. S'il est inaccessible depuis votre réseau, vous pouvez définir un [relais personnalisé](guide/settings-and-trust.md) que vous contrôlez à la place, ou activer **Local network only** si les deux appareils sont sur le même réseau et que vous n'avez pas du tout besoin du relais.

## Acceptation automatique et expéditeurs `--ask`

Si vous avez activé l'acceptation automatique et que l'expéditeur utilise l'indicateur de confirmation `--ask` de croc, le transfert peut être automatiquement refusé, et le message actuel de CrocApp accuse à tort l'autre côté ("the other side declined") au lieu d'expliquer que c'est votre propre réglage d'acceptation automatique qui en est la cause. C'est un problème connu, sans correctif pour le moment ; désactiver l'acceptation automatique permet de l'éviter.

## Pas de bouton d'annulation pendant l'examen d'un transfert entrant

Une fois que vous consultez la liste des fichiers entrants, **Decline** est le seul moyen d'en sortir, il n'y a pas de bouton d'annulation séparé à ce stade, et la notification de fin de transfert peut accuser un léger retard pendant que croc termine ses tentatives de reconnexion en coulisses. C'est un comportement attendu, pas un bug.
