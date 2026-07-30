---
sidebar_position: 4
title: Napredne opcije
description: Objavljene napredne postavke (F13 do F19) i croc CLI oznaka na koju se svaka od njih mapira.
---

# Napredne opcije

![CrocApp postavke na iOS-u prikazuju napredne opcije na ekranu postavki](/img/screenshots/ios-settings-light.png#gh-light-mode-only)![CrocApp postavke na iOS-u prikazuju napredne opcije na ekranu postavki](/img/screenshots/ios-settings-dark.png#gh-dark-mode-only)

CrocApp izlaže skup naprednih opcija sa razumnim zadanim vrijednostima. Na macOS-u se nalaze u Settings sceni (⌘,); na iOS-u su pod ekranom postavki iz alatne trake na početnom ekranu. Svih sedam ispod je objavljeno.

| # | Opcija | Kontrola | croc ekvivalent |
|---|---|---|---|
| F13 | Prilagođeni relej, lozinka, IPv6 | Polja **Address**, **IPv6 address**, **Password** pod Relay | `--relay --relay6 --pass` |
| F14 | Prisilno samo lokalni prenosi | Prekidač **Local network only** | `--local` |
| F15 | Isključivanje kompresije | Prekidač **Disable compression** | `--no-compress` |
| F16 | Zip-ovanje foldera prije slanja | Prekidač **Zip folders before sending** | `--zip` |
| F17 | Isključni obrasci, poštovanje `.gitignore` | Polje **Patterns, one per line**, prekidač **Respect .gitignore** | `--exclude --git` |
| F18 | Automatsko prihvatanje dolaznih, isključeno po zadanom | Prekidač **Auto-accept incoming files** | `--yes` |
| F19 | Zahtijevanje potvrde na obje strane | Prekidač **Confirm on both sides** | `--ask` |

## Relej (F13)

Polja **Address** i **IPv6 address** prikazuju croc-ove vlastite zadane vrijednosti kao tekst čuvara mjesta; ostavite ih praznim da koristite croc-ov zadani relej. Ostavite **Password** praznim da koristite croc-ovu zadanu lozinku releja.

## Local network only (F14)

Kada je uključeno, prenosi nikada ne dodiruju relej na internetu: CrocApp koristi samo lokalnu mrežu. Ako se direktna lokalna veza ne može uspostaviti, prenos ne uspijeva umjesto da se vrati na relej.

## Isključni obrasci (F17)

Obrasci idu jedan po liniji u polju **Patterns, one per line**. **Respect .gitignore** dodatno isključuje sve što bi isključio i vaš `.gitignore`.

## Automatsko prihvatanje (F18)

Automatsko prihvatanje je isključeno po zadanom. Kada je uključeno, CrocApp prikazuje ovo upozorenje: "Files from anyone who has your code are saved without preview or confirmation. Unsafe file names still cancel the transfer. Both-sides confirm overrides auto-accept." Kada je isključeno: "Auto-accept skips the incoming-files preview. Leave it off unless you fully trust the sender."

## Confirm on both sides (F19)

Kada je uključeno, pošiljalac takođe mora odobriti prenos (putem upita **Receiver connected**) prije nego što počne, uz uobičajeni korak prihvatanja od strane primaoca.

## Još nije izgrađeno

Dodatni skup croc mogućnosti (SOCKS5/Tor proxy, HTTP proxy, ograničavanje brzine slanja, izbor krive i hash algoritma, direktno IP povezivanje, prilagođena multicast adresa, podešavanje portova/prenosa, interni DNS resolver, i pokretanje vlastitog releja iz Mac aplikacije) planiran je za kasnije izdanje, ali još nije počeo da se razvija.
