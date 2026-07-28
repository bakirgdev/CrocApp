---
sidebar_position: 5
title: Sécurité et confidentialité
description: L'affirmation de sécurité exacte que fait CrocApp, énoncée précisément, ainsi que les données qu'il collecte (aucune) et comment signaler une vulnérabilité.
---

# Sécurité et confidentialité

## L'affirmation, énoncée précisément

Les transferts sont chiffrés de bout en bout, la phrase de code authentifie les deux côtés, et le relais ne voit jamais que du texte chiffré. C'est toute l'affirmation.

:::warning
Il n'y a eu **aucun audit de sécurité tiers formel** de croc, et CrocApp ne prétend pas en avoir un. Ne considérez pas CrocApp comme audité, certifié ou vérifié en zero-knowledge.
:::

## Fonctionnement

- **Un code, un transfert.** Chaque transfert utilise une courte phrase de code à usage unique. Quiconque a le code est le partenaire du transfert ; partagez-le via un canal de confiance, et il expire avec le transfert.
- **Des clés fortes à partir de codes courts.** Les deux appareils exécutent PAKE (échange de clé authentifié par mot de passe) pour transformer la phrase de code en une clé de chiffrement forte. Le code lui-même ne traverse jamais le réseau, et un code erroné échoue immédiatement.
- **Chiffré de bout en bout.** Tout est chiffré sur votre appareil et déchiffré uniquement sur l'autre. Rien entre les deux ne peut le lire.
- **Le relais n'est qu'un tuyau.** Quand les appareils ne peuvent pas se connecter directement, un relais internet achemine le flux chiffré. Le relais n'a jamais la clé, il ne voit que du texte chiffré. Vous pouvez aussi exécuter votre propre relais et le définir dans les réglages.
- **Réseau local quand c'est possible.** Les appareils sur le même réseau transfèrent directement ; les données ne quittent jamais votre réseau. La voie locale et le relais sont en course, et le plus rapide gagne.
- **Vous gardez le contrôle.** Rien n'est enregistré sans votre accord : les transferts entrants affichent un aperçu des fichiers que vous acceptez ou refusez. L'acceptation automatique est désactivée sauf si vous l'activez.

## Ce que CrocApp ne fait pas

- Pas de télémétrie, pas d'analytique, pas de publicité, pas de comptes.
- L'historique des transferts est local à l'appareil, voir [Historique](guide/history.md) pour savoir exactement ce qu'il enregistre.
- Vous pouvez pointer CrocApp vers votre propre relais croc plutôt que le relais public par défaut.
- Les dépendances du moteur Go sont analysées par `govulncheck` à chaque exécution de CI et de nouveau selon un calendrier hebdomadaire.

## Signaler une vulnérabilité

Signalez-la en privé via [GitHub Security Advisories](https://github.com/bakirgdev/CrocApp/security/advisories/new). N'ouvrez jamais de ticket public, de discussion ou de pull request pour une vulnérabilité suspectée.

Utile à inclure : ce qu'un attaquant obtient et l'accès dont il aurait besoin, les étapes de reproduction (flux de la phrase de code, relais, plateforme), la version ou le commit de CrocApp ainsi que la version de l'OS et l'appareil, et si le même comportement se reproduit avec le CLI `croc` amont.

Politique complète, périmètre, et ce qui est hors périmètre (le protocole de transfert lui-même appartient à croc amont) : [`SECURITY.md`](https://github.com/bakirgdev/CrocApp/blob/main/SECURITY.md) sur GitHub.
