---
sidebar_position: 3
title: Glossar
description: Nutzerorientierte Begriffe, die in der gesamten CrocApp-Dokumentation verwendet werden.
---

# Glossar

| Begriff | Bedeutung |
|---|---|
| Code-Phrase / Geheimnis | Die Zeichenfolge `NNNN-word-word-word`, die beide Seiten verwenden, um sich zu finden und den Sitzungsschlüssel abzuleiten. Benutzerdefinierte Codes haben mindestens 6 Zeichen. |
| PAKE | Passwortauthentifizierter Schlüsselaustausch (Password-Authenticated Key Exchange). Verwandelt die schwache Code-Phrase in einen starken Verschlüsselungsschlüssel, ohne dass der Relay ihn je erfährt. |
| Relay | Der Server, mit dem sich beide Seiten verbinden, wenn kein direkter Pfad im lokalen Netzwerk verfügbar ist. Sieht nur Chiffretext, nie den Schlüssel. |
| Room | Der Rendezvous-Kanal auf dem Relay, abgeleitet aus den ersten 4 Zeichen der Code-Phrase. Zwei Codes, die sich diese Zeichen teilen, können in denselben Room kollidieren. |
| Curve | Die elliptische Kurve, über die PAKE läuft. CrocApp verwendet crocs Standard. |
| Hash-Algorithmus | Die Integritätsprüfung, die auf übertragene Dateien angewendet wird. |
| LAN-Peer-Erkennung | Der Mechanismus, der Übertragungen im selben Netzwerk erlaubt, den Relay vollständig zu überspringen; nicht garantiert, in jedem Netzwerk zu funktionieren. |
| Local-only | Eine Einstellung, die eine Übertragung zwingt, im lokalen Netzwerk zu bleiben, und den Relay ablehnt, falls kein direkter Pfad verfügbar ist. |
| Kompression | Dateidaten werden standardmäßig während der Übertragung komprimiert; dies kann deaktiviert werden. |
| Vertrauens-Badge | Die Anzeige auf dem Bildschirm, die zeigt, dass eine Übertragung Ende-zu-Ende-verschlüsselt ist und welchen Relay-Pfad sie nutzt. |
| Übertragungsverlauf | Der lokale, nur auf dem Gerät gespeicherte Log vergangener Übertragungen von CrocApp. |

Für das vollständige Glossar für Mitwirkende und Interna (croc-Protokollinterna, die Go/gomobile-Brücke, App-Architektur und Repo-Konventionen), siehe [`docs/GLOSSARY.md`](https://github.com/bakirgdev/CrocApp/blob/main/docs/GLOSSARY.md) auf GitHub.
