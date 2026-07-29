---
sidebar_position: 5
title: Réglages et confiance
description: Où se trouvent les réglages de CrocApp, pourquoi vous pourriez exécuter votre propre relais, et ce que vous indique le badge de confiance.
---

# Réglages et confiance

![Les réglages de CrocApp sur macOS montrant le dossier de réception et les champs d'adresse du relais](/img/screenshots/mac-settings-light.png#gh-light-mode-only)![Les réglages de CrocApp sur macOS montrant le dossier de réception et les champs d'adresse du relais](/img/screenshots/mac-settings-dark.png#gh-dark-mode-only)

## Où se trouvent les réglages

Sur macOS, les réglages sont dans la scène Réglages (⌘,), avec une section **Receive** (dossier de destination, plus un bouton **Show in Finder**) au-dessus des [options avancées](power-options.md). Sur iOS, l'écran de réglages (accessible depuis la barre d'outils de l'accueil) contient les options avancées ; le dossier de destination de réception se change plutôt depuis l'écran **Receive** lui-même.

Les réglages persistent localement sur l'appareil. Il n'y a ni synchronisation ni compte auquel se connecter.

## Relais personnalisé

Par défaut, CrocApp utilise le relais public de croc. Vous pouvez plutôt le pointer vers un relais que vous exécutez vous-même, via l'[option avancée de relais](power-options.md). Raisons d'exécuter le vôtre :

- Vous voulez que les transferts passent par une infrastructure que vous contrôlez plutôt que par le relais public partagé.
- Vous êtes sur un réseau où vous préférez ne pas dépendre d'un service externe.

Exécuter `croc relay` sur une machine que vous contrôlez suffit ; saisissez ensuite son adresse (et son mot de passe, si vous en avez défini un) dans les champs de relais de CrocApp.

## Le badge de confiance

Pendant un écran d'attente, de confirmation ou de transfert, CrocApp affiche un badge de confiance : un libellé **End-to-end encrypted** ainsi qu'une ligne décrivant la voie de relais réellement utilisée pour ce transfert :

- "Local network only — nothing leaves your network"
- "Via custom relay `<address>` — it sees only encrypted data"
- "Via the public croc relay — it sees only encrypted data"

Ceci est capturé au moment où le transfert démarre, si bien que modifier les réglages en cours de transfert ne peut pas faire dire au badge quelque chose qui ne serait pas vrai pour le transfert en cours.

## Ce qui est stocké

Les réglages (adresse du relais, mot de passe du relais, local uniquement, compression, zip, motifs d'exclusion, gitignore, confirmation des deux côtés, acceptation automatique) sont stockés localement sur l'appareil. Aucun réglage, contenu de transfert ou phrase de code n'est envoyé où que ce soit, sauf dans le cadre d'un transfert réel que vous initiez.
