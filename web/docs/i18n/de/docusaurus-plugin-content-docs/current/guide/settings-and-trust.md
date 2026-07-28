---
sidebar_position: 5
title: Einstellungen und Vertrauen
description: Wo die Einstellungen von CrocApp liegen, warum Sie eventuell einen eigenen Relay betreiben möchten, und was das Vertrauens-Badge Ihnen sagt.
---

# Einstellungen und Vertrauen

## Wo Einstellungen liegen

Unter macOS liegen die Einstellungen in der Settings-Szene (⌘,), mit einem Bereich **Receive** (Zielordner, plus einer Schaltfläche **Show in Finder**) über den [Leistungsoptionen](power-options.md). Unter iOS enthält der Einstellungsbildschirm (erreichbar über die Startbildschirm-Toolbar) die Leistungsoptionen; der Zielordner für den Empfang wird stattdessen direkt über den **Receive**-Bildschirm geändert.

Einstellungen bleiben lokal auf dem Gerät erhalten. Es gibt keine Synchronisierung und kein Konto, in das man sich einloggen müsste.

## Benutzerdefinierter Relay

Standardmäßig verwendet CrocApp crocs öffentlichen Relay. Sie können es stattdessen auf einen selbst betriebenen Relay ausrichten, über die [Relay-Option](power-options.md). Gründe, einen eigenen zu betreiben:

- Sie möchten, dass Übertragungen über Infrastruktur laufen, die Sie kontrollieren, statt über den geteilten öffentlichen Relay.
- Sie arbeiten in einem Netzwerk, in dem Sie sich lieber nicht auf einen externen Dienst verlassen möchten.

Es genügt, `croc relay` auf einer Maschine laufen zu lassen, die Sie kontrollieren; geben Sie dann deren Adresse (und Passwort, falls gesetzt) in die Relay-Felder von CrocApp ein.

## Das Vertrauens-Badge

Während eines Warte-, Bestätigungs- oder Übertragungsbildschirms zeigt CrocApp ein Vertrauens-Badge: eine Beschriftung **End-to-end encrypted** plus eine Zeile, die den tatsächlich verwendeten Relay-Pfad für diese Übertragung beschreibt:

- "Local network only — nothing leaves your network"
- "Via custom relay `<address>` — it sees only encrypted data"
- "Via the public croc relay — it sees only encrypted data"

Dies wird im Moment des Übertragungsstarts festgehalten, sodass eine Änderung der Einstellungen mitten in der Übertragung das Badge nicht etwas sagen lassen kann, das für die laufende Übertragung nicht zutrifft.

## Was gespeichert wird

Einstellungen (Relay-Adresse, Relay-Passwort, "nur lokal", Kompression, Zip, Ausschlussmuster, Gitignore, beidseitige Bestätigung, Auto-Accept) werden lokal auf dem Gerät gespeichert. Keine Einstellungen, Übertragungsinhalte oder Code-Phrasen werden irgendwohin gesendet, außer als Teil einer tatsächlichen Übertragung, die Sie selbst starten.
