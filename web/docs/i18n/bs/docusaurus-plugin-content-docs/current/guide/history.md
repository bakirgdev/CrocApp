---
sidebar_position: 6
title: Historija
description: "CrocApp-ova historija prenosa, dostupna samo lokalno: šta bilježi, šta namjerno nikada ne bilježi, i kako je obrisati."
---

# Historija (F12)

![Ekran historije CrocApp-a na macOS-u koji prikazuje prethodne prijenose s njihovim smjerom, brojem datoteka i statusom](/img/screenshots/mac-history-light.png#gh-light-mode-only)![Ekran historije CrocApp-a na macOS-u koji prikazuje prethodne prijenose s njihovim smjerom, brojem datoteka i statusom](/img/screenshots/mac-history-dark.png#gh-dark-mode-only)

CrocApp čuva lokalnu listu prošlih prenosa, dostupnu preko ikone historije na početnom ekranu. Nikada ne napušta uređaj: nema sinhronizacije, nema izvoza, i nije uključen nijedan server.

## Šta se bilježi

Za svaki završeni ili neuspješan prenos:

- Smjer (poslano ili primljeno) i da li se radilo o tekstualnom prenosu
- Do 20 imena fajlova
- Ukupan broj fajlova i ukupna veličina
- **Nagovještaj koda**: samo prvi segment kodne fraze (na primjer, "7291-…"), nikada puna fraza
- Datum i status (završeno, neuspješno, otkazano ili odbijeno)
- Za slanja, skup oznaka fajlova koje podržavaju **Send Again**: snimljen sve-ili-ništa, i najviše 200 stavki; zapis bez oznaka jednostavno ne nudi Send Again

## Šta se nikada ne bilježi

- Sadržaj fajlova
- Puna kodna fraza: samo taj nagovještaj prvog segmenta
- Bilo šta iznad granica od 20 imena i 200 oznaka

## Send Again

Za prošlo slanje, kontekstni meni unosa u historiji (ili gest povlačenja na iOS-u) nudi **Send Again** ako su za njega snimljene oznake. Ovo ponovo priprema iste fajlove za novo slanje. Ako su originalni fajlovi u međuvremenu premješteni ili obrisani, CrocApp vam javlja da više nisu dostupni umjesto da tiho ne pošalje ništa.

## Brisanje historije

Dodirnite **Clear** na traci alata ekrana historije, zatim potvrdite. Ovo uklanja samo listu: fajlovi koje ste već primili ostaju tačno tamo gdje su sačuvani.
