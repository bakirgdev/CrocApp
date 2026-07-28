---
sidebar_position: 2
title: Recevoir des fichiers
description: Comment recevoir un transfert dans CrocApp, vérifier la liste des fichiers entrants et gérer les conflits.
---

# Recevoir des fichiers

Ouvrez **Receive** depuis l'écran d'accueil.

## Saisir un code (F4)

Tapez la **Code phrase** dans le champ, collez-la avec le bouton **Paste**, ou (iOS uniquement) appuyez sur **Scan QR Code** pour scanner le QR code de l'expéditeur. Le bouton **Receive** reste désactivé tant que le code saisi ne fait pas au moins 6 caractères.

## Choisir où les fichiers arrivent (F7)

Sous le champ de code, CrocApp affiche le dossier de destination actuel. Appuyez sur **Change** pour en choisir un autre, ou sur **Reset** pour revenir à celui par défaut.

Les valeurs par défaut diffèrent selon la plateforme :

- **macOS** : `Downloads/CrocApp`
- **iOS** : le dossier Documents de l'app, visible dans l'app Fichiers

## Accepter ou refuser (F9)

Après avoir appuyé sur **Receive** et vous être connecté à l'expéditeur, CrocApp affiche **Incoming transfer** : la liste complète des fichiers avec leurs tailles et un total. À partir de là :

- **Accept** démarre le transfert.
- **Decline** le refuse. C'est le seul moyen de refuser une fois la liste vue, il n'y a pas de bouton d'annulation à ce stade.

Si l'expéditeur a activé [Confirm on both sides](power-options.md), l'expéditeur doit aussi confirmer avant que le transfert ne se poursuive.

## Écrasement et conflits (F8)

CrocApp autorise toujours l'écrasement à la réception. Si un fichier entrant existe déjà à la destination, l'écran d'acceptation ajoute un avertissement : les éléments concernés seront remplacés, et tout fichier partiellement reçu reprend plutôt que de recommencer. Les fichiers dont le nom n'est pas sûr (par exemple, ceux qui tentent d'échapper au dossier de destination) bloquent entièrement **Accept**, comme mesure de sécurité en plus de l'assainissement des noms propre à croc.

## Acceptation automatique (F18)

L'acceptation automatique est **désactivée par défaut**. Quand elle est désactivée, vous voyez toujours l'aperçu de la liste des fichiers ci-dessus avant que quoi que ce soit ne soit enregistré. L'activer (dans les [options avancées](power-options.md)) supprime cet aperçu : voir cette page pour l'avertissement exact que CrocApp affiche lorsqu'elle est activée.

## Après le transfert

Une fois terminé, CrocApp affiche **Transfer complete** (ou un message en cas de problème) avec un bouton pour ouvrir la destination : **Open in Files** sur iOS, **Show in Finder** sur macOS.
