---
sidebar_position: 2
title: Dateien empfangen
description: Wie Sie eine Übertragung in CrocApp empfangen, die eingehende Dateiliste prüfen und mit Konflikten umgehen.
---

# Dateien empfangen

![CrocApp unter iOS zeigt eine eingehende Übertragung mit drei Dateien und den Schaltflächen Decline und Accept](/img/screenshots/ios-receive-light.png#gh-light-mode-only)![CrocApp unter iOS zeigt eine eingehende Übertragung mit drei Dateien und den Schaltflächen Decline und Accept](/img/screenshots/ios-receive-dark.png#gh-dark-mode-only)

Öffnen Sie **Receive** über den Startbildschirm.

## Einen Code eingeben (F4)

Geben Sie die **Code phrase** in das Feld ein, fügen Sie sie über die Schaltfläche **Paste** ein, oder tippen Sie (nur unter iOS) auf **Scan QR Code**, um den QR-Code des Senders zu scannen. Die Schaltfläche **Receive** bleibt deaktiviert, bis der eingegebene Code mindestens 6 Zeichen lang ist.

## Auswählen, wo Dateien landen (F7)

Unter dem Codefeld zeigt CrocApp den aktuellen Zielordner. Tippen Sie auf **Change**, um einen anderen zu wählen, oder auf **Reset**, um zum Standard zurückzukehren.

Die Standardwerte unterscheiden sich je Plattform:

- **macOS**: `Downloads/CrocApp`
- **iOS**: der Documents-Ordner der App, der in der Files-App sichtbar ist

## Annehmen oder ablehnen (F9)

Nachdem Sie auf **Receive** getippt und sich mit dem Sender verbunden haben, zeigt CrocApp **Incoming transfer**: die vollständige Dateiliste mit Größen und einer Gesamtsumme. Von hier aus:

- **Accept** startet die Übertragung.
- **Decline** lehnt sie ab. Dies ist die einzige Möglichkeit, abzulehnen, sobald Sie die Liste gesehen haben: in dieser Phase gibt es keine Abbrechen-Schaltfläche.

Hat der Sender [Confirm on both sides](power-options.md) aktiviert, muss der Sender die Übertragung ebenfalls bestätigen, bevor sie fortgesetzt wird.

## Überschreiben und Konflikte (F8)

CrocApp erlaubt beim Empfang immer das Überschreiben. Existiert eine eingehende Datei bereits am Ziel, fügt der Annahmebildschirm eine Warnung hinzu: Die betroffenen Elemente werden ersetzt, und eine teilweise empfangene Datei wird fortgesetzt statt neu gestartet. Dateien mit unsicheren Namen (zum Beispiel solche, die versuchen, den Zielordner zu verlassen) blockieren **Accept** vollständig, als Sicherheitsmaßnahme zusätzlich zur eigenen Namensbereinigung von croc.

## Auto-Accept (F18)

Auto-Accept ist **standardmäßig deaktiviert**. Ist es deaktiviert, sehen Sie immer zuerst die Dateilisten-Vorschau, bevor etwas gespeichert wird. Es zu aktivieren (in den [Leistungsoptionen](power-options.md)) überspringt diese Vorschau: siehe diese Seite für den genauen Warnhinweis, den CrocApp anzeigt, wenn es aktiviert ist.

## Nach der Übertragung

Ist sie abgeschlossen, zeigt CrocApp **Transfer complete** (oder eine Meldung, falls etwas schiefgegangen ist) mit einer Schaltfläche zum Öffnen des Ziels: **Open in Files** unter iOS, **Show in Finder** unter macOS.
