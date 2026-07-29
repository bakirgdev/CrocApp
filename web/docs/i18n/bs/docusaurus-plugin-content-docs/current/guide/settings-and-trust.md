---
sidebar_position: 5
title: Postavke i povjerenje
description: Gdje se nalaze CrocApp-ove postavke, zašto biste možda pokrenuli vlastiti relej, i šta vam govori značka povjerenja.
---

# Postavke i povjerenje

![CrocApp postavke na macOS-u prikazuju odredišni folder i polja za adresu relaya](/img/screenshots/mac-settings-light.png#gh-light-mode-only)![CrocApp postavke na macOS-u prikazuju odredišni folder i polja za adresu relaya](/img/screenshots/mac-settings-dark.png#gh-dark-mode-only)

## Gdje se nalaze postavke

Na macOS-u, postavke su u Settings sceni (⌘,), sa sekcijom **Receive** (odredišni folder, plus dugme **Show in Finder**) iznad [naprednih opcija](power-options.md). Na iOS-u, ekran postavki (dostupan iz alatne trake na početnom ekranu) sadrži napredne opcije; odredišni folder za prijem se umjesto toga mijenja sa samog ekrana **Receive**.

Postavke se čuvaju lokalno na uređaju. Nema sinhronizacije i nema naloga za prijavu.

## Prilagođeni relej

Po zadanom, CrocApp koristi croc-ov javni relej. Umjesto toga možete ga usmjeriti na relej koji sami pokrećete, pod [naprednom opcijom releja](power-options.md). Razlozi da pokrenete vlastiti:

- Želite da prenosi idu kroz infrastrukturu koju kontrolišete umjesto zajedničkog javnog releja.
- Radite na mreži gdje radije ne biste zavisili od eksternog servisa.

Dovoljno je pokrenuti `croc relay` na mašini koju kontrolišete; zatim unesite njenu adresu (i lozinku, ako ste je postavili) u CrocApp-ova polja releja.

## Značka povjerenja

Tokom ekrana čekanja, potvrđivanja ili prenosa, CrocApp prikazuje značku povjerenja: oznaku **End-to-end encrypted** plus liniju koja opisuje relejni put koji se stvarno koristi za taj prenos:

- "Local network only — nothing leaves your network"
- "Via custom relay `<address>` — it sees only encrypted data"
- "Via the public croc relay — it sees only encrypted data"

Ovo se snima u trenutku kada prenos počne, tako da promjena postavki usred prenosa ne može učiniti da značka kaže nešto što nije tačno za prenos koji je u toku.

## Šta se čuva

Postavke (adresa releja, lozinka releja, samo lokalno, kompresija, zip, isključni obrasci, gitignore, potvrda na obje strane, automatsko prihvatanje) čuvaju se lokalno na uređaju. Nikakve postavke, sadržaj prenosa ili kodne fraze se ne šalju nikuda osim kao dio stvarnog prenosa koji vi pokrenete.
