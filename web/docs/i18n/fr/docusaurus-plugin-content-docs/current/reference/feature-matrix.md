---
sidebar_position: 2
title: Matrice de fonctionnalités
description: Chaque fonctionnalité prévue de CrocApp, numérotée, groupée et marquée de son statut de publication réel.
---

# Matrice de fonctionnalités

Les numéros de fonctionnalité (`F1`…) sont des identifiants stables utilisés dans tout le projet. « Publiée » signifie que la fonctionnalité existe et fonctionne dans l'app aujourd'hui ; le projet n'a pas encore publié de version (voir [Installation](../getting-started/install.md)).

## Cœur (publiées)

| # | Fonctionnalité | Indicateur croc / origine |
|---|---|---|
| F1 | Envoi de fichiers (multiple) | arguments positionnels, glisser-déposer + sélecteur de fichiers |
| F2 | Envoi de dossiers | arguments positionnels |
| F3 | Envoi de texte/presse-papiers | `--text` |
| F4 | Réception via code | arguments positionnels |
| F5 | Phrase de code personnalisée (6 caractères min) | `--code` |
| F6 | Affichage QR à l'envoi + scan QR à la réception | `--qrcode` + natif GUI |
| F7 | Choix du dossier de sortie ; par défaut sur iOS, un dossier d'app visible dans Fichiers | `--out` |
| F8 | Gestion de l'écrasement/reprise via des feuilles de confirmation | `--overwrite` + reprise |
| F9 | Aperçu de la liste des fichiers entrants + accepter/refuser | équivalent d'invite interactive |
| F10 | Progression, vitesse, annulation ; Live Activity sur iOS | interrogé depuis le moteur |
| F11 | Course automatique LAN + relais | par défaut croc |
| F12 | Historique des transferts (local uniquement) | natif GUI |

## Options avancées (publiées)

| # | Fonctionnalité | Indicateur croc |
|---|---|---|
| F13 | Relais + mot de passe + IPv6 personnalisés | `--relay --relay6 --pass` |
| F14 | Forcer le local uniquement | `--local` |
| F15 | Désactiver la compression | `--no-compress` |
| F16 | Compresser le dossier en zip avant l'envoi | `--zip` |
| F17 | Motifs d'exclusion / respect de `.gitignore` | `--exclude --git` |
| F18 | Bascule d'acceptation automatique (désactivée par défaut, avertissement affiché) | `--yes` |
| F19 | Confirmation des deux côtés | `--ask` |

## Natif GUI (publiées)

| # | Fonctionnalité | Statut |
|---|---|---|
| F30 | Extension de partage (envoi depuis n'importe quelle app) | publiée, iOS uniquement |
| F36 | UI de confiance : badge de bout en bout, "how it works", indicateur de relais actif | publiée |

## Prévues, non commencées (V1.x)

Aucune de ces fonctionnalités n'est encore construite.

| # | Fonctionnalité | Indicateur croc / origine |
|---|---|---|
| F20 | Proxy SOCKS5 / Tor | `--socks5` |
| F21 | Proxy HTTP | `--connect` |
| F22 | Limitation du débit d'envoi | `--throttleUpload` |
| F23 | Choix de la courbe | `--curve` |
| F24 | Choix de l'algorithme de hachage | `--hash` |
| F25 | Connexion IP directe | `--ip` |
| F26 | Adresse multicast personnalisée | `--multicast` |
| F27 | Ajustement des ports/transferts, désactivation du multiplexage | `--port --transfers --no-multi` |
| F28 | Résolveur DNS interne | `--internal-dns` |
| F29 | Exécuter son propre relais depuis l'app Mac (serveur de relais dans la barre de menu) | `croc relay` |
| F31 | Envoi rapide depuis la barre de menu macOS (glisser-déposer) | natif GUI |
| F32 | Lien profond `croc://code` + liens universels | natif GUI |
| F33 | Codes enregistrés / pairs favoris | natif GUI |
| F34 | App Intents / Shortcuts ("Send via croc") | natif GUI |
| F35 | Vérification de l'état du relais + écran de diagnostics | natif GUI |

## Plus tard

| # | Fonctionnalité | Remarque |
|---|---|---|
| F37 | Voie directe Wi-Fi Aware | iOS/iPadOS 26 uniquement, absent sur macOS 26 ; voie rapide app-à-app |

## Volontairement non prévues

| # | Fonctionnalité | Raison |
|---|---|---|
| F38 | Redirection `--stdout` | concept propre au CLI |
| F39 | Mode `--classic` | non sécurisé par conception |
| F40 | `--remember` | les réglages du GUI persistent de toute façon |
