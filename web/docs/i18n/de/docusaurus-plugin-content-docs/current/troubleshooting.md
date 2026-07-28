---
sidebar_position: 6
title: Fehlerbehebung
description: "Echte, belegte Lösungen für häufige CrocApp-Probleme: stockende Übertragungen, abgelehnte Codes, Hintergrund-Beschränkungen und Berechtigungsprobleme."
---

# Fehlerbehebung

## Übertragung stockt oder verbindet sich nie

CrocApp lässt eine direkte lokale Netzwerkverbindung gegen den Relay antreten und nutzt, welche zuerst verbindet. Die Peer-Erkennung im lokalen Netzwerk nutzt UDP-Multicast, und es ist nicht garantiert, dass dies in jedem Netzwerk funktioniert: manche Netzwerke (zum Beispiel WLANs mit Client-Isolation) liefern überhaupt keine lokalen Peers, obwohl der Relay-Pfad trotzdem einwandfrei funktioniert. Stockt eine Übertragung bei "Waiting" oder "Connecting":

- Prüfen Sie, dass beide Geräte über funktionierenden Internetzugang verfügen, damit der Relay-Pfad funktionieren kann, selbst wenn der lokale nicht kann.
- Prüfen Sie die [Berechtigung für das lokale Netzwerk](#local-network-permission-prompt) unten.
- Es gibt keine In-App-Lösung für ein Netzwerk, das Multicast-Erkennung grundsätzlich blockiert; die Übertragung sollte trotzdem über den Relay abgeschlossen werden.

## Code abgelehnt oder die Receive-Schaltfläche bleibt deaktiviert

- Eine Code-Phrase muss mindestens 6 Zeichen haben. Die Schaltfläche **Receive** bleibt deaktiviert, bis Sie genug eingegeben haben.
- Ein falscher Code schlägt sofort fehl, statt hängen zu bleiben.
- Verwenden Sie einen benutzerdefinierten Code, den Sie auch zum Testen oder Skripten nutzen, beachten Sie: Codes, die sich ihre ersten 4 Zeichen teilen, können in denselben Relay-Room kollidieren. Erzeugte Codes haben dieses Problem nicht.

## Die Gegenseite verwendet eine andere croc-Version

CrocApp bettet croc v10.5.0 als Engine ein. Es ist darauf ausgelegt, in beide Richtungen mit der `croc`-CLI zu interoperieren. Läuft auf der Gegenseite ein sehr alter oder ungewöhnlich neuer `croc`-Build, verwenden Sie eine einigermaßen aktuelle CLI-Version, um Protokoll-Inkompatibilitäten zu vermeiden.

## Hintergrund-Beschränkungen unter iOS

iOS erlaubt es rohen TCP-Übertragungen nicht, beliebig lange im Hintergrund weiterzulaufen. CrocApp verwendet `BGContinuedProcessingTask` (iOS 26+), um eine Übertragung am Laufen zu halten und eine System-Live-Activity anzuzeigen, aber das ist Best-Effort: das System kann sie unter Speicherdruck beenden, und eine Übertragung mit geringem Fortschritt wird eher beendet als eine fast fertige. Für eine Übertragung, die nicht unterbrochen werden soll, halten Sie CrocApp im Vordergrund, bis sie abgeschlossen ist. Wird sie doch unterbrochen, sorgt crocs eigenes Fortsetzungsverhalten dafür, dass ein Neustart derselben Übertragung dort weitermacht, wo sie aufgehört hat, statt von vorn zu beginnen.

## Berechtigungsabfrage für das lokale Netzwerk {#local-network-permission-prompt}

Bei der ersten Nutzung des lokalen Netzwerks zeigt iOS eine Systemabfrage, ob CrocApp erlaubt werden soll, Geräte in Ihrem lokalen Netzwerk zu finden. Lehnen Sie sie ab, oder bleibt die Erteilung "hängen" (eine bekannte iOS-Eigenart, bei der eine erteilte Berechtigung erst funktioniert, nachdem man sie umschaltet oder neu startet), fällt CrocApp allein auf den Relay zurück. Sehen Sie das Banner "Local network access is off — transfers use the relay only," verwenden Sie dessen Schaltfläche **Open Settings**, um Einstellungen › Datenschutz › Lokales Netzwerk zu prüfen.

## Empfangene Dateien nicht dort sichtbar, wo erwartet

- Unter iOS landen empfangene Dateien im Documents-Ordner der App, der standardmäßig in der Files-App sichtbar ist.
- War Ihr Empfangsziel auf einen über einen Cloud-Speicher-Anbieter ausgewählten Ordner gesetzt (statt auf einen lokalen Ort), öffnet die Schaltfläche **Open in Files** nach einem Empfang ihn möglicherweise nicht korrekt: dies ist eine bekannte Einschränkung. Navigieren Sie stattdessen manuell in der Files-App zum Ordner.

## Relay nicht erreichbar

CrocApp verwendet standardmäßig crocs öffentlichen Relay. Ist er von Ihrem Netzwerk aus nicht erreichbar, können Sie stattdessen einen [benutzerdefinierten Relay](guide/settings-and-trust.md) festlegen, den Sie kontrollieren, oder **Local network only** aktivieren, wenn beide Geräte im selben Netzwerk sind und Sie den Relay überhaupt nicht brauchen.

## Auto-Accept und Sender mit `--ask`

Haben Sie Auto-Accept aktiviert und der Sender verwendet crocs Bestätigungs-Flag `--ask`, kann die Übertragung automatisch abgelehnt werden, und die Meldung von CrocApp gibt derzeit fälschlich der anderen Seite die Schuld ("the other side declined"), statt zu erklären, dass Ihre eigene Auto-Accept-Einstellung dies verursacht hat. Dies ist ein bekanntes Problem ohne bisherige Lösung; Auto-Accept zu deaktivieren umgeht es.

## Keine Abbrechen-Schaltfläche beim Prüfen einer eingehenden Übertragung

Sobald Sie die eingehende Dateiliste betrachten, ist **Decline** der einzige Ausweg: es gibt in dieser Phase keine separate Abbrechen-Schaltfläche, und die Benachrichtigung über das Ende der Übertragung kann leicht verzögert eintreffen, während croc im Hintergrund noch Wiederverbindungsversuche abschließt. Dies ist erwartetes Verhalten, kein Fehler.
