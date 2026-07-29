---
sidebar_position: 2
title: Primanje fajlova
description: Kako primiti prenos u CrocApp-u, pregledati listu dolaznih fajlova i riješiti sukobe.
---

# Primanje fajlova

![CrocApp na iOS-u prikazuje dolaznu razmjenu od tri datoteke s dugmadima Decline i Accept](/img/screenshots/ios-receive-light.png#gh-light-mode-only)![CrocApp na iOS-u prikazuje dolaznu razmjenu od tri datoteke s dugmadima Decline i Accept](/img/screenshots/ios-receive-dark.png#gh-dark-mode-only)

Otvorite **Receive** sa početnog ekrana.

## Unos koda (F4)

Unesite **Code phrase** u polje, zalijepite je dugmetom **Paste**, ili (samo na iOS-u) dodirnite **Scan QR Code** kako biste skenirali QR kod pošiljaoca. Dugme **Receive** ostaje onemogućeno dok unesen kod nema najmanje 6 znakova.

## Biranje gdje fajlovi završavaju (F7)

Ispod polja za kod, CrocApp prikazuje trenutni odredišni folder. Dodirnite **Change** da odaberete drugi, ili **Reset** da se vratite na zadani.

Zadane vrijednosti razlikuju se po platformi:

- **macOS**: `Downloads/CrocApp`
- **iOS**: Documents folder aplikacije, koji je vidljiv u aplikaciji Files

## Prihvatanje ili odbijanje (F9)

Nakon što dodirnete **Receive** i povežete se sa pošiljaocem, CrocApp prikazuje **Incoming transfer**: potpunu listu fajlova sa veličinama i ukupnim zbirom. Odavde:

- **Accept** pokreće prenos.
- **Decline** ga odbija. Ovo je jedini način da ga odbijete nakon što ste vidjeli listu: na ovom koraku nema dugmeta za otkazivanje.

Ako je pošiljalac uključio [Confirm on both sides](power-options.md), pošiljalac takođe mora potvrditi prije nego što prenos nastavi.

## Prepisivanje i sukobi (F8)

CrocApp uvijek dozvoljava prepisivanje pri prijemu. Ako neki dolazni fajl već postoji na odredištu, ekran za prihvatanje dodaje upozorenje: pogođene stavke će biti zamijenjene, a bilo koji djelimično primljen fajl nastavlja se umjesto da počne ispočetka. Fajlovi sa nesigurnim imenima (na primjer, oni koji pokušavaju izaći iz odredišnog foldera) u potpunosti blokiraju **Accept**, kao sigurnosnu mjeru pored croc-ove vlastite sanitizacije imena.

## Automatsko prihvatanje (F18)

Automatsko prihvatanje je **isključeno po zadanom**. Kada je isključeno, uvijek vidite pregled liste fajlova prije nego što se bilo šta sačuva. Njegovo uključivanje (u [naprednim opcijama](power-options.md)) preskače taj pregled: pogledajte tu stranicu za tačno upozorenje koje CrocApp prikazuje kada je uključeno.

## Nakon prenosa

Kada se završi, CrocApp prikazuje **Transfer complete** (ili poruku ako je nešto pošlo po zlu) sa dugmetom za otvaranje odredišta: **Open in Files** na iOS-u, **Show in Finder** na macOS-u.
