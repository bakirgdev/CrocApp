---
slug: /
sidebar_position: 1
title: Documentation CrocApp
description: CrocApp est une application native SwiftUI gratuite et open source pour iPhone, iPad et Mac qui envoie des fichiers grâce à une phrase de code prononcée à voix haute.
---

:::warning
Cette traduction est un brouillon assisté par une IA. Elle n'a pas encore été relue par un locuteur natif. Si quelque chose semble incorrect, les corrections sont les bienvenues sur [GitHub](https://github.com/bakirgdev/CrocApp/issues).

This translation is an unreviewed draft. The English version is authoritative.
:::

# Documentation CrocApp

CrocApp envoie des fichiers, des dossiers et du texte entre deux appareils n'importe où dans le monde, chiffrés de bout en bout, à l'aide d'une courte phrase de code comme `8412-mirage-cobalt-fresco`. Aucun compte, aucun envoi vers le cloud de quelqu'un d'autre, aucune exigence que les deux appareils partagent un réseau.

C'est une interface graphique pour [croc](https://github.com/schollz/croc), l'outil de transfert de fichiers en ligne de commande de Zack Scholl. CrocApp intègre la bibliothèque Go de croc plutôt que d'appeler le binaire en sous-processus, si bien qu'une phrase de code générée par le CLI croc fonctionne dans l'app, et qu'une phrase de code générée par l'app fonctionne dans le CLI.

:::note
CrocApp n'est pas officiel et n'est pas affilié. Rien ici n'implique une approbation de la part de l'auteur de croc.
:::

## Fonctionnement, en bref

L'expéditeur choisit des fichiers, un dossier ou un extrait de texte. CrocApp génère une phrase de code, qui peut être dite à voix haute, envoyée par message ou affichée sous forme de QR code. Le destinataire saisit la phrase, voit la liste des fichiers et accepte. Les deux appareils exécutent PAKE (échange de clé authentifié par mot de passe) sur la phrase de code pour dériver une clé de session, si bien que la phrase elle-même ne traverse jamais le réseau en clair et que le relais ne l'apprend jamais. Quand les deux appareils sont sur le même réseau, CrocApp se connecte directement et se passe du relais.

## Prérequis de plateforme

CrocApp nécessite **iOS 26**, **iPadOS 26** ou **macOS 26** (exactement `26.0`, pas une version mineure ultérieure). C'est exclusivement pour les plateformes Apple ; il n'existe pas de client Windows, Linux ou Android.

:::warning
CrocApp n'a pas encore été publié. Rien n'est disponible au téléchargement sur aucun canal aujourd'hui. Voir [Installation](getting-started/install.md) pour le statut actuel et comment compiler depuis les sources.
:::

## Pour aller plus loin

- [Installation](getting-started/install.md) : statut de la publication et comment compiler depuis les sources aujourd'hui
- [Votre premier transfert](getting-started/first-transfer.md) : un parcours d'un envoi et d'une réception
- [Envoyer des fichiers](guide/sending.md), [Recevoir des fichiers](guide/receiving.md), [Phrases de code](guide/code-phrases.md)
- [Options avancées](guide/power-options.md), [Réglages et confiance](guide/settings-and-trust.md), [Historique](guide/history.md)
- [Interopérabilité avec le CLI croc](reference/croc-cli-interop.md) et la [matrice de fonctionnalités](reference/feature-matrix.md)
- [Sécurité et confidentialité](security-and-privacy.md), [Dépannage](troubleshooting.md), [FAQ](faq.md)
- [Contribuer](contribute.md)
