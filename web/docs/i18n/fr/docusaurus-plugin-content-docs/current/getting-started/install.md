---
sidebar_position: 1
title: Installation
description: CrocApp n'a pas encore été publié. Voici le statut actuel de chaque canal de distribution prévu et comment compiler depuis les sources dès aujourd'hui.
---

# Installation

:::warning
**Pas encore publié.** Aucun téléchargement n'existe sur aucun canal aujourd'hui. Les sources sont publiques et compilables dès maintenant ; voir [Compiler depuis les sources](#build-from-source) ci-dessous.
:::

## Canaux de distribution

CrocApp est prévu pour trois canaux. Aucun n'est encore actif.

| Canal | État |
|---|---|
| iOS / iPadOS App Store | Prévu |
| Mac App Store | Prévu |
| Téléchargement direct macOS (DMG notarisé) | Prévu |

Notes sur les blocages :

- **La notarisation n'est pas encore réelle.** Le script de notarisation du projet s'arrête actuellement à une vérification à blanc (`syspolicy_check distribution`) et ne soumet ni n'agrafe de véritable ticket de notarisation.
- Une bêta TestFlight est également prévue, pour quand il y aura une compilation à distribuer.
- Il n'y a aucun canal via gestionnaire de paquets, et aucun n'est prévu pour l'instant.

Toutes les fonctionnalités V1 sont implémentées ; ce qui sépare encore l'app d'une publication est suivi dans les [problèmes connus](https://github.com/bakirgdev/CrocApp/blob/main/docs/known-issues.md) du projet, sous "Blocking release".

## Compiler depuis les sources {#build-from-source}

Nécessite :

- **macOS 26**
- **Xcode 26.6**
- **Go 1.26.5** ou une version plus récente (`gomobile` et `gobind` s'installent eux-mêmes au premier lancement)

```bash
git clone https://github.com/bakirgdev/CrocApp.git
cd CrocApp
scripts/build-xcframework.sh   # Go engine -> CrocKit/Croc.xcframework
open app/CrocApp.xcodeproj
```

:::warning
Un clone fraîchement récupéré ne compile rien tant que le xcframework n'existe pas. La cible binaire de `CrocKit` pointe vers un artefact ignoré par git, donc `scripts/build-xcframework.sh` n'est pas optionnel.
:::

L'app elle-même nécessite **iOS 26**, **iPadOS 26** ou **macOS 26** pour s'exécuter.

Référence complète de la chaîne d'outils, paramètres de compilation et dépannage : [`docs/BUILDING.md`](https://github.com/bakirgdev/CrocApp/blob/main/docs/BUILDING.md) sur GitHub.
