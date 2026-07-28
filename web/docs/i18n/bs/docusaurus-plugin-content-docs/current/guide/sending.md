---
sidebar_position: 1
title: Slanje fajlova
description: Kako slati fajlove, foldere i tekst u CrocApp-u, uključujući ekstenziju za dijeljenje i pravilo jednog aktivnog prenosa.
---

# Slanje fajlova

Otvorite **Send** sa početnog ekrana. Birač **What to send** prebacuje između dva načina rada:

## Files (F1, F2)

- **Add Files** otvara birač fajlova; možete odabrati više fajlova odjednom.
- **Add Folder** bira cijeli folder za slanje.
- Na macOS-u, fajlove ili foldere možete i prevući na područje za ispuštanje.
- Odabrane stavke se pojavljuju u listi, svaka uklonjiva svojim dugmetom **x**.

## Text (F3)

Unesite ili zalijepite u tekstualno polje, ili koristite dugme **Paste** da direktno povučete trenutni sadržaj clipboarda (ovo je eksplicitna radnja, ne tiho čitanje u pozadini).

## Custom code (F5)

Polje **Custom code** je opcionalno. Ostavite ga praznim za generisani kod, ili unesite svoj (najmanje 6 znakova) kako bi mogao biti podijeljen preko kanala kojem već vjerujete: na primjer, diktiranjem tokom poziva.

## Pokretanje slanja

Dodirnite **Send**. CrocApp prikazuje generisanu (ili prilagođenu) kodnu frazu, dugme **Copy Code**, i QR kod (F6) koji primalac može skenirati. Ekran takođe prikazuje značku povjerenja koja opisuje koji relejni put je u upotrebi.

## Jedan aktivan prenos u isto vrijeme

CrocApp dozvoljava tačno jedan aktivan prenos u isto vrijeme, u skladu sa ograničenjem u osnovnom engine-u. Ne možete pokrenuti drugo slanje ili prijem dok je jedno u toku; prvo završite ili otkažite trenutni prenos.

## Ekstenzija za dijeljenje (samo iOS, F30)

Na iOS-u, fajlove možete podijeliti u CrocApp iz share sheet-a bilo koje druge aplikacije. Podijeljene stavke se pripremaju, i list **Shared files** se pojavljuje sa dugmadima **Discard** i **Send** kada sljedeći put otvorite CrocApp. Odabir **Send** prenosi pripremljene fajlove u uobičajeni tok slanja.

## List pripremljenih fajlova

List pripremljenih fajlova prikazuje svaku stavku koja je podijeljena, tako da možete pregledati šta će biti poslano prije nego što se na to obavežete.

## Šta pošiljalac vidi tokom prenosa

Kada se primalac poveže, CrocApp prikazuje **Ready to send** i čeka. Ako je [potvrda na obje strane](power-options.md) uključena, dobijate upit **Receiver connected** sa dugmadima **Send** / **Cancel** prije nego što se bilo šta pomjeri. Tokom prenosa, CrocApp prikazuje napredak po fajlu i ukupan napredak sa brzinom, plus dugme **Cancel**.
