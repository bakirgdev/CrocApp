---
sidebar_position: 1
title: croc-CLI-Interoperabilität
description: CrocApp bettet croc v10.5.0 als Go-Bibliothek ein, sodass eine mit der CLI erzeugte Code-Phrase in der App funktioniert und umgekehrt.
---

# croc-CLI-Interoperabilität

CrocApp bettet **croc v10.5.0** als Go-Bibliothek ein (über ein mit `gomobile` gebautes Framework), statt das `croc`-Binary aufzurufen. Das bedeutet, es spricht in beide Richtungen exakt dasselbe Protokoll wie die CLI.

:::note
Upstream-croc hat v10.6.0 veröffentlicht, nachdem diese Version festgelegt wurde; CrocApp ist noch nicht darauf umgestiegen.
:::

## Beispiel: CLI sendet, App empfängt

Auf einem Laptop, mit der croc-CLI:

```bash
croc send file.txt
# -> prints something like 9822-word-word-word
```

Öffnen Sie auf Ihrem Telefon oder Mac **Receive** in CrocApp und geben Sie den angezeigten Code ein. Die Datei kommt genauso an, als hätte der Sender ebenfalls CrocApp verwendet.

## Beispiel: App sendet, CLI empfängt

Starten Sie einen Sendevorgang in CrocApp, holen Sie sich die angezeigte Code-Phrase, dann auf einer anderen Maschine:

```bash
croc 9822-word-word-word
```

## Selbst gehosteter Relay

Beide Seiten müssen sich auf den Relay einigen. Über die CLI:

```bash
croc --relay myserver:9009 send file.txt
```

Legen Sie in CrocApp dieselbe Adresse unter der [Relay-Option](../guide/power-options.md) fest.

## Zuordnung von Feature zu Flag

| # | Feature | croc-Flag / Ursprung |
|---|---|---|
| F1 | Dateien senden (mehrere) | Positionsargumente |
| F2 | Ordner senden | Positionsargumente |
| F3 | Text/Zwischenablage senden | `--text` |
| F4 | Über Code empfangen | Positionsargumente |
| F5 | Benutzerdefinierte Code-Phrase (mind. 6 Zeichen) | `--code` |
| F6 | QR-Anzeige beim Senden / Scan beim Empfangen | `--qrcode` |
| F7 | Ausgabeordner wählen | `--out` |
| F8 | Überschreiben-/Fortsetzen-Handling | `--overwrite` |
| F9 | Vorschau der eingehenden Dateiliste, annehmen/ablehnen | interaktive Aufforderung |
| F10 | Fortschritt, Geschwindigkeit, Abbrechen | — |
| F11 | Automatisches Wettrennen LAN + Relay | croc-Standard |
| F12 | Übertragungsverlauf | — |
| F13 | Benutzerdefinierter Relay, Passwort, IPv6 | `--relay --relay6 --pass` |
| F14 | Nur lokal erzwingen | `--local` |
| F15 | Kompression deaktivieren | `--no-compress` |
| F16 | Ordner vor dem Senden zippen | `--zip` |
| F17 | Muster ausschließen / `.gitignore` | `--exclude --git` |
| F18 | Umschalter für Auto-Accept | `--yes` |
| F19 | Beidseitige Bestätigung | `--ask` |

## Versions- und Relay-Kompatibilität

Da CrocApp crocs eigenen Bibliothekscode einbindet, statt das Protokoll neu zu implementieren, folgen Relay- und Protokollkompatibilität dem, was croc selbst in der festgelegten Version unterstützt. Eine aktuelle, nicht allzu alte `croc`-CLI-Version auf der Gegenseite zu verwenden, ist die sicherste Wahl.
