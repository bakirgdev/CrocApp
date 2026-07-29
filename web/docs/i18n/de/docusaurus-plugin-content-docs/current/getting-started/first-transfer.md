---
sidebar_position: 2
title: Ihre erste Übertragung
description: Eine Anleitung für einen Sende- und einen Empfangsvorgang in CrocApp, anhand der tatsächlichen Beschriftungen der App auf dem Bildschirm.
---

# Ihre erste Übertragung

![CrocApp unter macOS zeigt Ready to send mit der Code-Phrase, einer Copy-Code-Schaltfläche und einem QR-Code](/img/screenshots/mac-send-light.png#gh-light-mode-only)![CrocApp unter macOS zeigt Ready to send mit der Code-Phrase, einer Copy-Code-Schaltfläche und einem QR-Code](/img/screenshots/mac-send-dark.png#gh-dark-mode-only)

Der Startbildschirm von CrocApp hat zwei Schaltflächen: **Send** und **Receive**. Alles Weitere ergibt sich aus einem dreistufigen Ablauf:

1. Der Sender wählt Dateien, einen Ordner oder einen Textausschnitt.
2. CrocApp erzeugt eine Code-Phrase. Sprechen Sie sie, verschicken Sie sie per Nachricht, oder zeigen Sie sie als QR-Code.
3. Der Empfänger gibt die Phrase ein, sieht die Dateiliste und nimmt an.

Beide Seiten führen PAKE über die Code-Phrase aus, um einen Sitzungsschlüssel abzuleiten, sodass die Phrase nie unverschlüsselt über das Netzwerk geht und der Relay sie nie erfährt. Dateien werden mit der Code-Phrase verschlüsselt; der Relay sieht immer nur Chiffretext. Gleiches WLAN oder verschiedene Kontinente, CrocApp findet automatisch den schnellsten Weg.

## Senden

1. Tippen oder klicken Sie auf dem Startbildschirm auf **Send**.
2. Wählen Sie unter **What to send** zwischen **Files** oder **Text**.
   - Für Dateien: verwenden Sie **Add Files** oder **Add Folder**, oder ziehen Sie Dateien auf den Ablagebereich (macOS).
   - Für Text: tippen oder fügen Sie Text in das Textfeld ein.
3. Legen Sie optional einen **Custom code** fest (mindestens 6 Zeichen) statt eines erzeugten.
4. Tippen Sie auf **Send**.
5. CrocApp zeigt **Ready to send** mit der Code-Phrase, einer Schaltfläche **Copy Code** und einem QR-Code. Teilen Sie den Code mit dem Empfänger über einen Kanal, dem Sie vertrauen.
6. Sobald der Empfänger sich verbindet und annimmt, beginnt die Übertragung. Ist sie abgeschlossen, zeigt CrocApp **Transfer complete**.

## Empfangen

1. Tippen oder klicken Sie auf dem Startbildschirm auf **Receive**.
2. Geben Sie die **Code phrase** ein, die Ihnen der Sender gegeben hat, fügen Sie sie ein, oder tippen Sie (unter iOS) auf **Scan QR Code**.
3. Prüfen Sie den Zielordner, der unter dem Codefeld angezeigt wird; ändern Sie ihn bei Bedarf mit **Change**.
4. Tippen Sie auf **Receive**.
5. CrocApp zeigt **Incoming transfer** mit der Dateiliste und der Gesamtgröße. Prüfen Sie sie, dann tippen Sie auf **Accept** oder **Decline**.
6. Ist die Übertragung abgeschlossen, zeigt CrocApp **Transfer complete** mit einer Schaltfläche zum Öffnen des Zielordners (**Open in Files** unter iOS, **Show in Finder** unter macOS).

Für alle Details zu jedem Schritt siehe [Dateien senden](../guide/sending.md) und [Dateien empfangen](../guide/receiving.md).
