---
sidebar_position: 3
title: Kodne fraze
description: Šta je CrocApp kodna fraza, zašto istovremeno služi kao adresa i lozinka, i sigurni načini da je podijelite.
---

# Kodne fraze

Kodna fraza izgleda kao `8412-mirage-cobalt-fresco`: kratak PIN praćen sa nekoliko riječi. Generiše se iznova za svaki prenos, osim ako ne postavite prilagođenu na [ekranu za slanje](sending.md).

## Ona je istovremeno adresa i lozinka

Unos koda na drugom uređaju je sve što je potrebno: to je istovremeno način na koji se dva uređaja pronalaze i tajna koja osigurava prenos. Za običan prenos nema ništa drugo za podešavanje.

## Kako osigurava prenos

Oba uređaja pokreću **PAKE** (razmjena ključeva autentifikovana lozinkom) preko kodne fraze kako bi je pretvorili u jak enkripcijski ključ:

- Sam kod nikada ne prelazi mrežu u čistom obliku.
- Pogrešan kod odmah propada, prije nego što se pomjeri bilo kakav podatak fajla.
- Sve se enkriptuje na uređaju koji šalje i dekriptuje samo na uređaju koji prima; ništa između to ne može pročitati.

## Jednokratna i ističe

Svaki prenos koristi jednokratnu kodnu frazu. Ko god ima kod tretira se kao partner za taj prenos, i kod ističe zajedno sa njim: nije ponovo upotrebljiv za kasniji prenos.

## Dijeljenje: QR kod i lijepljenje

CrocApp prikazuje kod kao tekst i kao QR kod (F6). QR sadržaj je `croc://<code>`, tako da skeniranje radi i sa drugim alatima koji razumiju isti oblik deeplinka.

Da biste unijeli kod u polje **Receive**, imate dvije eksplicitne opcije: koristite dugme **Paste**, ili (na iOS-u) dodirnite **Scan QR Code**. CrocApp nikad tiho ne čita clipboard; lijepljenje je uvijek nešto što sami pokrećete. Zalijepljeni ili skenirani tekst može sadržavati prefiks `croc://` ili biti goli kod: oba se prihvataju, sve dok je ono što ostane najmanje 6 znakova bez razmaka.

## Prilagođeni kodovi

Prilagođeni kod mora imati najmanje 6 znakova. Postavite ga u polje **Custom code** na ekranu za slanje kako biste ga mogli podijeliti preko kanala kojem već vjerujete (telefonski poziv, postojeći enkriptovani chat) umjesto da se oslanjate na generisani.

## Sigurno dijeljenje koda

Podijelite ga preko kanala kojem vjerujete, na isti način na koji biste podijelili jednokratnu lozinku: izgovorite ga, pošaljite kroz chat kojem već vjerujete, ili pustite primaoca da skenira QR kod direktno sa vašeg ekrana. Pošto je kod istovremeno adresa i lozinka, svako ko ga pribavi prije nego što se prenos završi može mu se pridružiti.
