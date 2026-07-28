---
sidebar_position: 7
title: FAQ
description: Häufig gestellte Fragen zu CrocApp, Kosten, Sicherheit, Konten und Plattformunterstützung.
---

# FAQ

## Was kostet es?

Nichts. Kein Kauf, kein Abo, keine Werbung und keine Analytics. CrocApp ist kostenlos, MIT-lizenziert, und das bleibt so. Monetarisierung beschränkt sich auf optionales Sponsoring.

## Ist es wirklich sicher?

Übertragungen sind Ende-zu-Ende-verschlüsselt, die Code-Phrase authentifiziert beide Seiten, und der Relay sieht immer nur Chiffretext. Das ist die gesamte Behauptung, und sie stammt aus dem Design von croc, nicht von etwas, das CrocApp hinzufügt. Es gab kein formelles Audit von croc durch Dritte, und CrocApp behauptet auch keines. Der Code auf beiden Seiten ist offen, wenn Sie nachsehen möchten.

## Brauche ich ein Konto?

Nein. Es gibt nichts, wofür man sich anmelden müsste, und keine Identität, die an eine Übertragung geknüpft ist.

## Geht meine Datei über einen Server?

Meist ja: über einen Relay, der Datenverkehr zwischen zwei Geräten weiterleitet, die sich nicht direkt erreichen können. Er sieht nur Chiffretext und sonst nichts, und er speichert Ihre Datei nicht. Sie können CrocApp stattdessen auf Ihren eigenen Relay zeigen lassen.

## Was, wenn wir im selben WLAN sind?

Dann geht die Übertragung direkt zwischen den beiden Geräten und überspringt den Relay vollständig. CrocApp versucht beide Wege gleichzeitig und nutzt, welcher zuerst verbindet.

## Wie unterscheidet sich das von AirDrop?

AirDrop braucht zwei Apple-Geräte in physischer Nähe. CrocApp funktioniert zwischen zwei beliebigen Geräten, auf denen croc oder CrocApp läuft, in jedem Netzwerk, über jede Entfernung, auch von einem Mac zu einem Linux-Server auf der anderen Seite der Welt.

## Funktioniert es mit dem croc-Kommandozeilentool?

Ja, in beide Richtungen. CrocApp bettet croc v10.5.0 als Bibliothek ein und spricht damit dasselbe Protokoll. `croc send` auf einem Laptop, Empfang in der App auf einem Telefon, und umgekehrt.

## Kann ich meinen eigenen Relay betreiben?

Ja. Weisen Sie CrocApp auf einen beliebigen croc-Relay hin, mit Passwort und IPv6, falls gewünscht. Es genügt, `croc relay` auf einer Maschine laufen zu lassen, die Sie kontrollieren.

## Warum nur iOS 26 und macOS 26?

CrocApp ist eine Neuentwicklung ohne bestehende Nutzer. Ältere Versionen zu unterstützen würde überall Verfügbarkeitsprüfungen bedeuten und den Verzicht auf aktuelle SwiftUI-APIs und die Liquid-Glass-Designsprache. Die Mindestversion ist `26.0`, und jede neuere Version funktioniert. Die Untergrenze ist bewusst auf `26.0` festgelegt und nicht auf eine spätere Nebenversion, damit niemand mit 26.0 bis 26.4 ausgesperrt wird.

## Ist es kostenlos? Wird es je eine bezahlte Stufe geben?

Kostenlos, MIT-lizenziert, und das bleibt so. Monetarisierung beschränkt sich auf optionales [Sponsoring](https://github.com/sponsors/bakirgdev).

## Wird es eine Windows-, Linux- oder Android-Version geben?

Nein. CrocApp ist bewusst ausschließlich für Apple-Plattformen. Nutzen Sie anderswo die [croc-CLI](https://github.com/schollz/croc): sie interoperiert mit dieser App.
