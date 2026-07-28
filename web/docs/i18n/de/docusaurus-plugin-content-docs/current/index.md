---
slug: /
sidebar_position: 1
title: CrocApp-Dokumentation
description: CrocApp ist eine kostenlose Open-Source-App mit nativem SwiftUI für iPhone, iPad und Mac, die Dateien mit einer gesprochenen Code-Phrase versendet.
---

:::warning
Diese Übersetzung ist ein maschinell unterstützter Entwurf. Sie wurde noch nicht von einem
Muttersprachler geprüft. Korrekturen sind über [GitHub](https://github.com/bakirgdev/CrocApp/issues) willkommen.

This translation is an unreviewed draft. The English version is authoritative.
:::

# CrocApp-Dokumentation

CrocApp sendet Dateien, Ordner und Text zwischen zwei Geräten, egal wo auf der Welt, Ende-zu-Ende-verschlüsselt, mit einer kurzen Code-Phrase wie `8412-mirage-cobalt-fresco`. Kein Konto, kein Upload in die Cloud eines Dritten, keine Anforderung, dass beide Geräte im selben Netzwerk sind.

CrocApp ist eine grafische Oberfläche für [croc](https://github.com/schollz/croc), das Kommandozeilen-Tool für Dateiübertragung von Zack Scholl. CrocApp bettet croc's Go-Bibliothek ein, statt das Binary aufzurufen; eine mit der croc-CLI erzeugte Code-Phrase funktioniert also in der App, und eine in der App erzeugte Code-Phrase funktioniert in der CLI.

:::note
CrocApp ist inoffiziell und nicht mit croc verbunden. Nichts hier impliziert eine Befürwortung durch den Autor von croc.
:::

## So funktioniert es, kurz gefasst

Der Sender wählt Dateien, einen Ordner oder einen Textausschnitt. CrocApp erzeugt eine Code-Phrase, die gesprochen, per Nachricht verschickt oder als QR-Code angezeigt werden kann. Der Empfänger gibt die Phrase ein, sieht die Dateiliste und nimmt an. Beide Seiten führen PAKE (passwortauthentifizierter Schlüsselaustausch) über die Code-Phrase aus, um einen Sitzungsschlüssel abzuleiten, sodass die Phrase selbst nie unverschlüsselt über das Netzwerk geht und der Relay sie nie erfährt. Sind beide Geräte im selben Netzwerk, verbindet sich CrocApp direkt und überspringt den Relay.

## Plattformanforderungen

CrocApp benötigt **iOS 26**, **iPadOS 26** oder **macOS 26** (exakt `26.0`, keine spätere Nebenversion). Es ist ausschließlich für Apple-Plattformen; es gibt keinen Windows-, Linux- oder Android-Client.

:::warning
CrocApp wurde noch nicht veröffentlicht. Heute steht auf keinem Kanal ein Download zur Verfügung. Siehe [Installation](getting-started/install.md) für den aktuellen Status und wie man aus dem Quellcode baut.
:::

## Wie es weitergeht

- [Installation](getting-started/install.md): Release-Status und wie man heute aus dem Quellcode baut
- [Ihre erste Übertragung](getting-started/first-transfer.md): eine Anleitung für einen Sende- und einen Empfangsvorgang
- [Dateien senden](guide/sending.md), [Dateien empfangen](guide/receiving.md), [Code-Phrasen](guide/code-phrases.md)
- [Leistungsoptionen](guide/power-options.md), [Einstellungen und Vertrauen](guide/settings-and-trust.md), [Verlauf](guide/history.md)
- [Interoperabilität mit der croc-CLI](reference/croc-cli-interop.md) und die [Feature-Matrix](reference/feature-matrix.md)
- [Sicherheit und Datenschutz](security-and-privacy.md), [Fehlerbehebung](troubleshooting.md), [FAQ](faq.md)
- [Mitwirken](contribute.md)
