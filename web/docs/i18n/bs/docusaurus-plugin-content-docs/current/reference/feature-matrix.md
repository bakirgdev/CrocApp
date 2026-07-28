---
sidebar_position: 2
title: Matrica funkcija
description: Svaka planirana CrocApp funkcija, numerisana, grupisana i označena stvarnim statusom objave.
---

# Matrica funkcija

Brojevi funkcija (`F1`…) su stabilni identifikatori koji se koriste u cijelom projektu. "Shipped" znači da funkcija postoji i radi u aplikaciji danas; projekat još nije objavio verziju (pogledajte [Instalacija](../getting-started/install.md)).

## Osnovno (objavljeno)

| # | Funkcija | croc oznaka / porijeklo |
|---|---|---|
| F1 | Slanje fajlova (višestruko) | pozicioni argumenti, prevlačenje + birač fajlova |
| F2 | Slanje foldera | pozicioni argumenti |
| F3 | Slanje teksta/clipboarda | `--text` |
| F4 | Prijem putem koda | pozicioni argumenti |
| F5 | Prilagođena kodna fraza (min. 6 znakova) | `--code` |
| F6 | Prikaz QR-a pri slanju + skeniranje QR-a pri prijemu | `--qrcode` + izvorno u GUI-ju |
| F7 | Odabir izlaznog foldera; iOS zadano je folder aplikacije vidljiv u Files | `--out` |
| F8 | Rukovanje prepisivanjem/nastavkom putem potvrdnih listova | `--overwrite` + nastavak |
| F9 | Pregled dolazne liste fajlova + prihvatanje/odbijanje | ekvivalent interaktivnog upita |
| F10 | Napredak, brzina, otkazivanje; Live Activity na iOS-u | očitava se iz engine-a |
| F11 | Automatska utrka LAN + relej | croc zadano |
| F12 | Historija prenosa (samo lokalno) | izvorno u GUI-ju |

## Napredne opcije (objavljeno)

| # | Funkcija | croc oznaka |
|---|---|---|
| F13 | Prilagođeni relej + lozinka + IPv6 | `--relay --relay6 --pass` |
| F14 | Prisilno samo lokalno | `--local` |
| F15 | Isključivanje kompresije | `--no-compress` |
| F16 | Zip-ovanje foldera prije slanja | `--zip` |
| F17 | Isključni obrasci / poštovanje `.gitignore` | `--exclude --git` |
| F18 | Prekidač automatskog prihvatanja (isključeno po zadanom, prikazano upozorenje) | `--yes` |
| F19 | Potvrda na obje strane | `--ask` |

## Izvorno u GUI-ju (objavljeno)

| # | Funkcija | Status |
|---|---|---|
| F30 | Ekstenzija za dijeljenje (slanje iz bilo koje aplikacije) | objavljeno, samo iOS |
| F36 | Trust UI: end-to-end značka, "how it works", indikator aktivnog releja | objavljeno |

## Planirano, još nije početo (V1.x)

Nijedno od ovoga još nije izgrađeno.

| # | Funkcija | croc oznaka / porijeklo |
|---|---|---|
| F20 | SOCKS5 / Tor proxy | `--socks5` |
| F21 | HTTP proxy | `--connect` |
| F22 | Ograničavanje brzine slanja | `--throttleUpload` |
| F23 | Izbor krive | `--curve` |
| F24 | Izbor hash algoritma | `--hash` |
| F25 | Direktno IP povezivanje | `--ip` |
| F26 | Prilagođena multicast adresa | `--multicast` |
| F27 | Podešavanje portova/prenosa, isključivanje multipleksiranja | `--port --transfers --no-multi` |
| F28 | Interni DNS resolver | `--internal-dns` |
| F29 | Pokretanje vlastitog releja iz Mac aplikacije (relay server u meniju) | `croc relay` |
| F31 | Brzo slanje iz macOS menu bara (prevlačenje) | izvorno u GUI-ju |
| F32 | Deeplink `croc://code` + univerzalni linkovi | izvorno u GUI-ju |
| F33 | Sačuvani kodovi / omiljeni peerovi | izvorno u GUI-ju |
| F34 | App Intents / prečice ("Send via croc") | izvorno u GUI-ju |
| F35 | Provjera stanja releja + ekran dijagnostike | izvorno u GUI-ju |

## Kasnije

| # | Funkcija | Napomena |
|---|---|---|
| F37 | Wi-Fi Aware direktan put | samo iOS/iPadOS 26, odsutno na macOS 26; brzi put aplikacija-do-aplikacije |

## Namjerno neplanirano

| # | Funkcija | Razlog |
|---|---|---|
| F38 | Piping preko `--stdout` | koncept isključivo za CLI |
| F39 | Način `--classic` | po dizajnu nesiguran |
| F40 | `--remember` | GUI postavke se ionako čuvaju trajno |
