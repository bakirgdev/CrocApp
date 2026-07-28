---
sidebar_position: 2
title: Feature-Matrix
description: Jedes geplante CrocApp-Feature, nummeriert, gruppiert und mit seinem tatsächlichen Ausliefer-Status markiert.
---

# Feature-Matrix

Feature-Nummern (`F1`…) sind stabile Kennungen, die im gesamten Projekt verwendet werden. "Shipped" bedeutet, dass das Feature existiert und heute in der App funktioniert; das Projekt hat noch keinen Build veröffentlicht (siehe [Installation](../getting-started/install.md)).

## Kern (ausgeliefert)

| # | Feature | croc-Flag / Ursprung |
|---|---|---|
| F1 | Dateien senden (mehrere) | Positionsargumente, Drag-Drop + Dateiauswahl |
| F2 | Ordner senden | Positionsargumente |
| F3 | Text/Zwischenablage senden | `--text` |
| F4 | Über Code empfangen | Positionsargumente |
| F5 | Benutzerdefinierte Code-Phrase (mind. 6 Zeichen) | `--code` |
| F6 | QR-Anzeige beim Senden + QR-Scan beim Empfangen | `--qrcode` + GUI-nativ |
| F7 | Ausgabeordner wählen; iOS-Standard ist ein in Files sichtbarer App-Ordner | `--out` |
| F8 | Überschreiben-/Fortsetzen-Handling über Bestätigungs-Sheets | `--overwrite` + Fortsetzen |
| F9 | Vorschau der eingehenden Dateiliste + annehmen/ablehnen | Entsprechung der interaktiven Aufforderung |
| F10 | Fortschritt, Geschwindigkeit, Abbrechen; Live Activity unter iOS | von der Engine abgefragt |
| F11 | Automatisches Wettrennen LAN + Relay | croc-Standard |
| F12 | Übertragungsverlauf (nur lokal) | GUI-nativ |

## Leistungsoptionen (ausgeliefert)

| # | Feature | croc-Flag |
|---|---|---|
| F13 | Benutzerdefinierter Relay + Passwort + IPv6 | `--relay --relay6 --pass` |
| F14 | Nur lokal erzwingen | `--local` |
| F15 | Kompression deaktivieren | `--no-compress` |
| F16 | Ordner vor dem Senden zippen | `--zip` |
| F17 | Muster ausschließen / `.gitignore` beachten | `--exclude --git` |
| F18 | Umschalter für Auto-Accept (standardmäßig deaktiviert, Warnung wird angezeigt) | `--yes` |
| F19 | Beidseitige Bestätigung | `--ask` |

## GUI-nativ (ausgeliefert)

| # | Feature | Status |
|---|---|---|
| F30 | Share Extension (Senden aus jeder App) | ausgeliefert, nur iOS |
| F36 | Trust-UI: Ende-zu-Ende-Badge, "how it works", Anzeige des aktiven Relays | ausgeliefert |

## Geplant, noch nicht begonnen (V1.x)

Keines davon ist bisher gebaut.

| # | Feature | croc-Flag / Ursprung |
|---|---|---|
| F20 | SOCKS5-/Tor-Proxy | `--socks5` |
| F21 | HTTP-Proxy | `--connect` |
| F22 | Upload-Drosselung | `--throttleUpload` |
| F23 | Wahl der Kurve | `--curve` |
| F24 | Wahl des Hash-Algorithmus | `--hash` |
| F25 | Direkte IP-Verbindung | `--ip` |
| F26 | Benutzerdefinierte Multicast-Adresse | `--multicast` |
| F27 | Feinabstimmung von Ports/Übertragungen, Multiplexing deaktivieren | `--port --transfers --no-multi` |
| F28 | Interner DNS-Resolver | `--internal-dns` |
| F29 | Eigenen Relay aus der Mac-App betreiben (Menüleisten-Relay-Server) | `croc relay` |
| F31 | Schnellversand aus der macOS-Menüleiste (Drag-Drop) | GUI-nativ |
| F32 | Deeplink `croc://code` + Universal Links | GUI-nativ |
| F33 | Gespeicherte Codes / favorisierte Peers | GUI-nativ |
| F34 | App Intents / Kurzbefehle ("Send via croc") | GUI-nativ |
| F35 | Relay-Gesundheitsprüfung + Diagnosebildschirm | GUI-nativ |

## Später

| # | Feature | Hinweis |
|---|---|---|
| F37 | Direkter Pfad über Wi-Fi Aware | nur iOS/iPadOS 26, fehlt unter macOS 26; schneller App-zu-App-Pfad |

## Bewusst nicht geplant

| # | Feature | Grund |
|---|---|---|
| F38 | `--stdout`-Piping | reines CLI-Konzept |
| F39 | `--classic`-Modus | aus Designgründen unsicher |
| F40 | `--remember` | GUI-Einstellungen bleiben ohnehin erhalten |
