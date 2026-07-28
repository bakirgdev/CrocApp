---
sidebar_position: 4
title: Options avancées
description: Les réglages avancés publiés (F13 à F19) et l'indicateur du CLI croc auquel chacun correspond.
---

# Options avancées

CrocApp expose un ensemble d'options avancées avec des valeurs par défaut sensées. Sur macOS, elles se trouvent dans la scène Réglages (⌘,) ; sur iOS, elles sont sous l'écran de réglages accessible depuis la barre d'outils de l'accueil. Les sept options ci-dessous sont toutes publiées.

| # | Option | Contrôle | Équivalent croc |
|---|---|---|---|
| F13 | Relais, mot de passe, IPv6 personnalisés | Champs **Address**, **IPv6 address**, **Password** sous Relay | `--relay --relay6 --pass` |
| F14 | Forcer les transferts locaux uniquement | Bascule **Local network only** | `--local` |
| F15 | Désactiver la compression | Bascule **Disable compression** | `--no-compress` |
| F16 | Compresser un dossier en zip avant l'envoi | Bascule **Zip folders before sending** | `--zip` |
| F17 | Motifs d'exclusion, respect de `.gitignore` | Champ **Patterns, one per line**, bascule **Respect .gitignore** | `--exclude --git` |
| F18 | Acceptation automatique des fichiers entrants, désactivée par défaut | Bascule **Auto-accept incoming files** | `--yes` |
| F19 | Exiger une confirmation des deux côtés | Bascule **Confirm on both sides** | `--ask` |

## Relais (F13)

Les champs **Address** et **IPv6 address** affichent les valeurs par défaut de croc comme texte indicatif ; laissez-les vides pour utiliser le relais par défaut de croc. Laissez **Password** vide pour utiliser le mot de passe par défaut du relais de croc.

## Local network only (F14)

Une fois activé, les transferts ne touchent jamais un relais sur internet : CrocApp n'utilise que le réseau local. Si une connexion locale directe ne peut pas être établie, le transfert échoue plutôt que de se rabattre sur un relais.

## Motifs d'exclusion (F17)

Les motifs vont un par ligne dans le champ **Patterns, one per line**. **Respect .gitignore** exclut en plus tout ce que votre `.gitignore` exclurait.

## Acceptation automatique (F18)

L'acceptation automatique est désactivée par défaut. Une fois activée, CrocApp affiche cet avertissement : "Files from anyone who has your code are saved without preview or confirmation. Unsafe file names still cancel the transfer. Both-sides confirm overrides auto-accept." Une fois désactivée : "Auto-accept skips the incoming-files preview. Leave it off unless you fully trust the sender."

## Confirm on both sides (F19)

Une fois activé, l'expéditeur doit lui aussi approuver le transfert (via une invite **Receiver connected**) avant qu'il ne démarre, en plus de l'étape d'acceptation normale du destinataire.

## Pas encore implémenté

Un ensemble supplémentaire de capacités de croc (proxy SOCKS5/Tor, proxy HTTP, limitation du débit d'envoi, choix de la courbe et de l'algorithme de hachage, connexion IP directe, adresse multicast personnalisée, ajustement des ports/transferts, un résolveur DNS interne, et l'exécution de votre propre relais depuis l'app Mac) est prévu pour une version ultérieure mais n'a pas encore été commencé.
