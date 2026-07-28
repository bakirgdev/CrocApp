---
sidebar_position: 5
title: Sicherheit und Datenschutz
description: Die exakte Sicherheitsaussage, die CrocApp trifft, präzise formuliert, plus welche Daten es sammelt (keine) und wie man eine Sicherheitslücke meldet.
---

# Sicherheit und Datenschutz

## Die Aussage, präzise formuliert

Übertragungen sind Ende-zu-Ende-verschlüsselt, die Code-Phrase authentifiziert beide Seiten, und der Relay sieht immer nur Chiffretext. Das ist die gesamte Aussage.

:::warning
Es gab **kein formelles Sicherheitsaudit durch Dritte** für croc, und CrocApp behauptet auch keines. Behandeln Sie CrocApp nicht als geprüft, zertifiziert oder als zero-knowledge-verifiziert.
:::

## Wie es funktioniert

- **Ein Code, eine Übertragung.** Jede Übertragung verwendet eine kurze, einmalige Code-Phrase. Wer auch immer den Code hat, ist der Übertragungspartner; teilen Sie ihn über einen Kanal, dem Sie vertrauen, und er läuft mit der Übertragung ab.
- **Starke Schlüssel aus kurzen Codes.** Beide Geräte führen PAKE (passwortauthentifizierter Schlüsselaustausch) aus, um die Code-Phrase in einen starken Verschlüsselungsschlüssel zu verwandeln. Der Code selbst geht nie über das Netzwerk, und ein falscher Code schlägt sofort fehl.
- **Ende-zu-Ende-verschlüsselt.** Alles wird auf Ihrem Gerät verschlüsselt und erst auf dem anderen entschlüsselt. Nichts dazwischen kann es lesen.
- **Der Relay ist nur eine Leitung.** Können sich Geräte nicht direkt verbinden, leitet ein Internet-Relay den verschlüsselten Datenstrom weiter. Der Relay hat nie den Schlüssel: er sieht nur Chiffretext. Sie können auch Ihren eigenen Relay betreiben und ihn in den Einstellungen festlegen.
- **Lokales Netzwerk, wo möglich.** Geräte im selben Netzwerk übertragen direkt; die Daten verlassen Ihr Netzwerk nie. Der lokale Pfad und der Relay treten gegeneinander an, und der schnellere gewinnt.
- **Sie behalten die Kontrolle.** Nichts wird ohne Ihr Okay gespeichert: eingehende Übertragungen zeigen eine Dateivorschau, die Sie annehmen oder ablehnen. Auto-Accept ist deaktiviert, sofern Sie es nicht selbst aktivieren.

## Was CrocApp nicht tut

- Keine Telemetrie, keine Analytics, keine Werbung, keine Konten.
- Der Übertragungsverlauf ist lokal auf dem Gerät: siehe [Verlauf](guide/history.md) für genau das, was er aufzeichnet.
- Sie können CrocApp auf Ihren eigenen croc-Relay statt auf den öffentlichen Standard-Relay ausrichten.
- Abhängigkeiten in der Go-Engine werden bei jedem CI-Lauf und zusätzlich wöchentlich von `govulncheck` gescannt.

## Eine Sicherheitslücke melden

Melden Sie sie privat über [GitHub Security Advisories](https://github.com/bakirgdev/CrocApp/security/advisories/new). Öffnen Sie niemals ein öffentliches Issue, eine Diskussion oder einen Pull Request für eine vermutete Sicherheitslücke.

Nützlich anzugeben: was ein Angreifer gewinnt und welchen Zugriff er dafür bräuchte, Schritte zur Reproduktion (Code-Phrase-Ablauf, Relay, Plattform), die CrocApp-Version oder den Commit plus OS-Version und Gerät, sowie ob sich dasselbe Verhalten mit der Upstream-`croc`-CLI reproduzieren lässt.

Vollständige Richtlinie, Umfang und was nicht dazugehört (das Übertragungsprotokoll selbst gehört zu croc upstream): [`SECURITY.md`](https://github.com/bakirgdev/CrocApp/blob/main/SECURITY.md) auf GitHub.
