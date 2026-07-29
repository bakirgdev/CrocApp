---
sidebar_position: 1
title: Installation
description: CrocApp wurde noch nicht veröffentlicht. Hier ist der aktuelle Status jedes geplanten Vertriebskanals und wie man heute aus dem Quellcode baut.
---

# Installation

:::warning
**Noch nicht veröffentlicht.** Heute steht auf keinem Kanal ein Download zur Verfügung. Der Quellcode ist öffentlich und lässt sich jetzt bauen; siehe [Aus dem Quellcode bauen](#build-from-source) unten.
:::

## Vertriebskanäle

CrocApp ist für drei Kanäle geplant. Keiner ist bisher live.

| Kanal | Status |
|---|---|
| iOS / iPadOS App Store | Geplant |
| Mac App Store | Geplant |
| Direkter Download für macOS (notarisierte DMG) | Geplant |

Hinweise zu den Blockern:

- **Notarisierung ist noch nicht real.** Das Notarisierungsskript des Projekts bricht derzeit bei einer Trockenlaufprüfung (`syspolicy_check distribution`) ab und reicht kein echtes Notarisierungsticket ein oder heftet eines an.
- Eine TestFlight-Beta ist ebenfalls geplant, sobald es einen Build zum Verteilen gibt.
- Es gibt keinen Paketmanager-Kanal, und vorerst ist auch keiner geplant.

Jedes V1-Feature ist implementiert; was zwischen der App und einem Release steht, wird in den [bekannten Problemen](https://github.com/bakirgdev/CrocApp/blob/main/docs/known-issues.md) des Projekts unter "Blocking release" nachgehalten.

## Aus dem Quellcode bauen {#build-from-source}

Erforderlich:

- **macOS 26**
- **Xcode 26.6**
- **Go 1.26.5** oder neuer (`gomobile` und `gobind` installieren sich beim ersten Lauf selbst)

```bash
git clone https://github.com/bakirgdev/CrocApp.git
cd CrocApp
scripts/build-xcframework.sh   # Go engine -> CrocKit/Croc.xcframework
open app/CrocApp.xcodeproj
```

:::warning
Ein frischer Checkout baut nichts, solange das xcframework nicht existiert. Das Binary-Target von `CrocKit` zeigt auf ein gitignoriertes Artefakt, daher ist `scripts/build-xcframework.sh` nicht optional.
:::

Die App selbst benötigt **iOS 26**, **iPadOS 26** oder **macOS 26**, um zu laufen.

Vollständige Toolchain-Referenz, Build-Einstellungen und Fehlerbehebung: [`docs/BUILDING.md`](https://github.com/bakirgdev/CrocApp/blob/main/docs/BUILDING.md) auf GitHub.
