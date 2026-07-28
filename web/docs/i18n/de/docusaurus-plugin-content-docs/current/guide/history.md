---
sidebar_position: 6
title: Verlauf
description: "Der rein lokale Übertragungsverlauf von CrocApp: was er aufzeichnet, was er bewusst nie aufzeichnet, und wie man ihn löscht."
---

# Verlauf (F12)

CrocApp führt eine lokale Liste vergangener Übertragungen, erreichbar über das Verlaufssymbol auf dem Startbildschirm. Sie verlässt nie das Gerät: es gibt keine Synchronisierung, keinen Export und keinen beteiligten Server.

## Was aufgezeichnet wird

Für jede abgeschlossene oder fehlgeschlagene Übertragung:

- Richtung (gesendet oder empfangen) und ob es eine Textübertragung war
- Bis zu 20 Dateinamen
- Gesamtzahl der Dateien und Gesamtgröße
- Ein **Code-Hinweis**: nur das erste Segment der Code-Phrase (zum Beispiel "7291-…"), nie die vollständige Phrase
- Datum und Status (abgeschlossen, fehlgeschlagen, abgebrochen oder abgelehnt)
- Bei Sendevorgängen ein Satz an Datei-Lesezeichen zur Unterstützung von **Send Again**: alles-oder-nichts erfasst, und höchstens 200 Elemente; ein Eintrag ohne Lesezeichen bietet **Send Again** einfach nicht an

## Was nie aufgezeichnet wird

- Dateiinhalte
- Die vollständige Code-Phrase: nur dieser Hinweis zum ersten Segment
- Alles über die Obergrenzen von 20 Namen und 200 Lesezeichen hinaus

## Send Again

Für einen vergangenen Sendevorgang bietet das Kontextmenü des Verlaufseintrags (oder die Wischgeste unter iOS) **Send Again** an, falls dafür Lesezeichen erfasst wurden. Dies stellt dieselben Dateien für einen neuen Sendevorgang erneut bereit. Wurden die Originaldateien seither verschoben oder gelöscht, teilt CrocApp Ihnen mit, dass sie nicht mehr verfügbar sind, statt stillschweigend nichts zu senden.

## Verlauf löschen

Tippen Sie in der Toolbar des Verlaufsbildschirms auf **Clear**, dann bestätigen Sie. Dies entfernt nur die Liste: Dateien, die Sie bereits empfangen haben, bleiben genau dort, wo sie gespeichert wurden.
