---
sidebar_position: 1
title: Interopérabilité avec le CLI croc
description: CrocApp intègre croc v10.5.0 comme bibliothèque Go, si bien qu'une phrase de code générée par le CLI fonctionne dans l'app et inversement.
---

# Interopérabilité avec le CLI croc

CrocApp intègre **croc v10.5.0** comme bibliothèque Go (via un framework construit avec `gomobile`) plutôt que d'appeler le binaire `croc` en sous-processus. Cela signifie qu'il parle exactement le même protocole que le CLI, dans les deux sens.

:::note
croc amont a publié la v10.6.0 après la fixation de cette version ; CrocApp n'y est pas encore passé.
:::

## Exemple : le CLI envoie, l'app reçoit

Sur un ordinateur portable, avec le CLI croc :

```bash
croc send file.txt
# -> prints something like 9822-word-word-word
```

Sur votre téléphone ou votre Mac, ouvrez **Receive** dans CrocApp et saisissez le code affiché. Le fichier arrive exactement comme si l'expéditeur avait aussi utilisé CrocApp.

## Exemple : l'app envoie, le CLI reçoit

Démarrez un envoi dans CrocApp, récupérez la phrase de code qu'il affiche, puis sur une autre machine :

```bash
croc 9822-word-word-word
```

## Relais auto-hébergé

Les deux côtés doivent s'accorder sur le relais. Depuis le CLI :

```bash
croc --relay myserver:9009 send file.txt
```

Dans CrocApp, définissez la même adresse sous l'[option avancée de relais](../guide/power-options.md).

## Correspondance fonctionnalité-indicateur

| # | Fonctionnalité | Indicateur croc / origine |
|---|---|---|
| F1 | Envoi de fichiers (multiple) | arguments positionnels |
| F2 | Envoi de dossiers | arguments positionnels |
| F3 | Envoi de texte/presse-papiers | `--text` |
| F4 | Réception via code | arguments positionnels |
| F5 | Phrase de code personnalisée (6 caractères min) | `--code` |
| F6 | Affichage QR à l'envoi / scan à la réception | `--qrcode` |
| F7 | Choix du dossier de sortie | `--out` |
| F8 | Gestion de l'écrasement/reprise | `--overwrite` |
| F9 | Aperçu de la liste des fichiers entrants, accepter/refuser | invite interactive |
| F10 | Progression, vitesse, annulation | — |
| F11 | Course automatique LAN + relais | par défaut croc |
| F12 | Historique des transferts | — |
| F13 | Relais, mot de passe, IPv6 personnalisés | `--relay --relay6 --pass` |
| F14 | Forcer le local uniquement | `--local` |
| F15 | Désactiver la compression | `--no-compress` |
| F16 | Compresser le dossier en zip avant l'envoi | `--zip` |
| F17 | Motifs d'exclusion / `.gitignore` | `--exclude --git` |
| F18 | Bascule d'acceptation automatique | `--yes` |
| F19 | Confirmation des deux côtés | `--ask` |

## Compatibilité de version et de relais

Comme CrocApp lie le propre code de bibliothèque de croc plutôt que de réimplémenter le protocole, la compatibilité de relais et de protocole suit ce que croc lui-même prend en charge à la version fixée. Utiliser un CLI `croc` récent et non ancien de l'autre côté est le choix le plus sûr.
