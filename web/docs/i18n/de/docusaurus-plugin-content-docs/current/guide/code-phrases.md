---
sidebar_position: 3
title: Code-Phrasen
description: Was eine CrocApp-Code-Phrase ist, warum sie zugleich als Adresse und Passwort dient, und die sicheren Wege, eine zu teilen.
---

# Code-Phrasen

Eine Code-Phrase sieht aus wie `8412-mirage-cobalt-fresco`: eine kurze PIN gefolgt von ein paar Wörtern. Sie wird für jede Übertragung neu erzeugt, sofern Sie nicht eine eigene auf dem [Send-Bildschirm](sending.md) festlegen.

## Sie ist zugleich Adresse und Passwort

Die Eingabe des Codes auf dem anderen Gerät ist alles, was nötig ist: er ist gleichzeitig der Weg, wie die beiden Geräte sich finden, und das Geheimnis, das die Übertragung sichert. Für eine normale Übertragung gibt es sonst nichts zu konfigurieren.

## Wie sie die Übertragung sichert

Beide Geräte führen **PAKE** (passwortauthentifizierter Schlüsselaustausch) über die Code-Phrase aus, um sie in einen starken Verschlüsselungsschlüssel zu verwandeln:

- Der Code selbst geht nie unverschlüsselt über das Netzwerk.
- Ein falscher Code schlägt sofort fehl, bevor irgendwelche Dateidaten bewegt werden.
- Alles wird auf dem sendenden Gerät verschlüsselt und erst auf dem empfangenden entschlüsselt; nichts dazwischen kann es lesen.

## Einmalig und ablaufend

Jede Übertragung verwendet eine einmalige Code-Phrase. Wer auch immer den Code hat, gilt als Übertragungspartner für diese Übertragung, und der Code läuft mit ihr ab: er ist für eine spätere Übertragung nicht wiederverwendbar.

## Teilen: QR-Code und Einfügen

CrocApp zeigt den Code als Text und als QR-Code (F6). Die QR-Nutzlast ist `croc://<code>`, sodass das Scannen auch mit anderen Tools funktioniert, die dieselbe Deeplink-Form verstehen.

Um einen Code in das Feld **Receive** zu bringen, haben Sie zwei ausdrückliche Optionen: die Schaltfläche **Paste** verwenden, oder (unter iOS) auf **Scan QR Code** tippen. CrocApp liest die Zwischenablage nicht heimlich; Einfügen ist immer etwas, das Sie selbst auslösen. Eingefügter oder gescannter Text kann das Präfix `croc://` enthalten oder ein reiner Code sein: beides wird akzeptiert, solange das, was übrig bleibt, mindestens 6 Zeichen ohne Leerraum hat.

## Benutzerdefinierte Codes

Ein benutzerdefinierter Code muss mindestens 6 Zeichen haben. Legen Sie ihn im Feld **Custom code** auf dem Send-Bildschirm fest, damit Sie ihn über einen Kanal teilen können, dem Sie bereits vertrauen (ein Telefonanruf, ein bestehender verschlüsselter Chat), statt sich auf den erzeugten zu verlassen.

## Einen Code sicher teilen

Teilen Sie ihn über einen Kanal, dem Sie vertrauen, genauso wie Sie einen Einmal-Zugangscode teilen würden: sprechen Sie ihn aus, senden Sie ihn über einen Chat, dem Sie bereits vertrauen, oder lassen Sie den Empfänger den QR-Code direkt von Ihrem Bildschirm scannen. Da der Code zugleich Adresse und Passwort ist, kann jeder, der ihn vor Abschluss der Übertragung erhält, ihr beitreten.
