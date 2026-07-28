---
sidebar_position: 1
title: Dateien senden
description: Wie Sie Dateien, Ordner und Text in CrocApp senden, einschließlich der Share Extension und der Regel für eine aktive Übertragung.
---

# Dateien senden

Öffnen Sie **Send** über den Startbildschirm. Die Auswahl **What to send** wechselt zwischen zwei Modi:

## Files (F1, F2)

- **Add Files** öffnet eine Dateiauswahl; Sie können mehrere Dateien gleichzeitig auswählen.
- **Add Folder** wählt einen ganzen Ordner zum Senden aus.
- Unter macOS können Sie Dateien oder Ordner auch auf den Ablagebereich ziehen.
- Ausgewählte Elemente erscheinen in einer Liste, jedes über seine **x**-Schaltfläche entfernbar.

## Text (F3)

Tippen oder fügen Sie Text in das Textfeld ein, oder verwenden Sie die Schaltfläche **Paste**, um den aktuellen Zwischenablageinhalt direkt zu übernehmen (dies ist eine ausdrückliche Aktion, kein stilles Lesen im Hintergrund).

## Custom code (F5)

Das Feld **Custom code** ist optional. Lassen Sie es für einen erzeugten Code leer, oder geben Sie Ihren eigenen ein (mindestens 6 Zeichen), damit er über einen Kanal geteilt werden kann, dem Sie bereits vertrauen, zum Beispiel indem Sie ihn während eines Anrufs diktieren.

## Den Versand starten

Tippen Sie auf **Send**. CrocApp zeigt die erzeugte (oder benutzerdefinierte) Code-Phrase, eine Schaltfläche **Copy Code** und einen QR-Code (F6), den der Empfänger scannen kann. Der Bildschirm zeigt außerdem ein Vertrauens-Badge, das anzeigt, welcher Relay-Pfad verwendet wird.

## Immer nur eine aktive Übertragung

CrocApp erlaubt genau eine aktive Übertragung gleichzeitig, entsprechend einer Begrenzung in der zugrunde liegenden Engine. Sie können keinen zweiten Sende- oder Empfangsvorgang starten, während einer läuft; beenden oder brechen Sie zuerst die aktuelle Übertragung ab.

## Share Extension (nur iOS, F30)

Unter iOS können Sie Dateien aus dem Teilen-Menü jeder anderen App an CrocApp weitergeben. Geteilte Elemente werden zwischengespeichert, und beim nächsten Öffnen von CrocApp erscheint ein Sheet **Shared files** mit den Schaltflächen **Discard** und **Send**. Die Wahl von **Send** überführt die zwischengespeicherten Dateien in den normalen Send-Ablauf.

## Sheet für zwischengespeicherte Dateien

Das Sheet für zwischengespeicherte Dateien listet jedes Element auf, das hereingeteilt wurde, damit Sie prüfen können, was gesendet wird, bevor Sie sich dafür entscheiden.

## Was der Sender während der Übertragung sieht

Sobald der Empfänger sich verbindet, zeigt CrocApp **Ready to send** und wartet. Ist [both-sides confirm](power-options.md) aktiviert, erhalten Sie eine Aufforderung **Receiver connected** mit **Send** / **Cancel**, bevor sich irgendetwas bewegt. Während der Übertragung zeigt CrocApp Fortschritt pro Datei und insgesamt mit Geschwindigkeit, plus einer Schaltfläche **Cancel**.
