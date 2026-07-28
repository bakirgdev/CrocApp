---
sidebar_position: 4
title: Leistungsoptionen
description: Die ausgelieferten Power-User-Einstellungen (F13 bis F19) und die croc-CLI-Flag, auf die jede davon abgebildet ist.
---

# Leistungsoptionen

CrocApp bietet eine Reihe von Leistungsoptionen mit sinnvollen Standardwerten. Unter macOS liegen sie in der Settings-Szene (⌘,); unter iOS finden Sie sie über den Einstellungsbildschirm aus der Startbildschirm-Toolbar. Alle sieben unten sind bereits ausgeliefert.

| # | Option | Steuerelement | croc-Entsprechung |
|---|---|---|---|
| F13 | Benutzerdefinierter Relay, Passwort, IPv6 | Felder **Address**, **IPv6 address**, **Password** unter Relay | `--relay --relay6 --pass` |
| F14 | Nur lokale Übertragungen erzwingen | Umschalter **Local network only** | `--local` |
| F15 | Kompression deaktivieren | Umschalter **Disable compression** | `--no-compress` |
| F16 | Ordner vor dem Senden zippen | Umschalter **Zip folders before sending** | `--zip` |
| F17 | Muster ausschließen, `.gitignore` beachten | Feld **Patterns, one per line**, Umschalter **Respect .gitignore** | `--exclude --git` |
| F18 | Eingehendes automatisch annehmen, standardmäßig deaktiviert | Umschalter **Auto-accept incoming files** | `--yes` |
| F19 | Bestätigung auf beiden Seiten erfordern | Umschalter **Confirm on both sides** | `--ask` |

## Relay (F13)

Die Felder **Address** und **IPv6 address** zeigen crocs eigene Standardwerte als Platzhaltertext; lassen Sie sie leer, um crocs Standard-Relay zu verwenden. Lassen Sie **Password** leer, um crocs Standard-Relay-Passwort zu verwenden.

## Local network only (F14)

Ist dies aktiviert, berühren Übertragungen nie einen Relay im Internet: CrocApp nutzt nur das lokale Netzwerk. Kann keine direkte lokale Verbindung hergestellt werden, schlägt die Übertragung fehl, statt auf einen Relay zurückzufallen.

## Exclude patterns (F17)

Muster kommen jeweils eines pro Zeile in das Feld **Patterns, one per line**. **Respect .gitignore** schließt zusätzlich alles aus, was Ihre `.gitignore` ausschließen würde.

## Auto-accept (F18)

Auto-accept ist standardmäßig deaktiviert. Ist es aktiviert, zeigt CrocApp diese Warnung: "Files from anyone who has your code are saved without preview or confirmation. Unsafe file names still cancel the transfer. Both-sides confirm overrides auto-accept." Ist es deaktiviert: "Auto-accept skips the incoming-files preview. Leave it off unless you fully trust the sender."

## Confirm on both sides (F19)

Ist dies aktiviert, muss auch der Sender die Übertragung genehmigen (über eine Aufforderung **Receiver connected**), bevor sie beginnt, zusätzlich zum normalen Annahmeschritt des Empfängers.

## Noch nicht gebaut

Ein weiteres Set an croc-Fähigkeiten (SOCKS5-/Tor-Proxy, HTTP-Proxy, Upload-Drosselung, Wahl von Kurve und Hash-Algorithmus, direkte IP-Verbindung, benutzerdefinierte Multicast-Adresse, Feinabstimmung von Port/Übertragungen, ein interner DNS-Resolver, sowie das Betreiben eines eigenen Relays aus der Mac-App) ist für ein späteres Release geplant, wurde aber noch nicht begonnen.
