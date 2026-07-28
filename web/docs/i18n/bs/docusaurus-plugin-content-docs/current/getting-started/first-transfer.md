---
sidebar_position: 2
title: Vaš prvi prenos
description: Vodič kroz jedno slanje i jedan prijem u CrocApp-u, koristeći stvarne oznake na ekranu aplikacije.
---

# Vaš prvi prenos

Početni ekran CrocApp-a ima dva dugmeta: **Send** i **Receive**. Sve ostalo proizlazi iz procesa u tri koraka:

1. Pošiljalac bira fajlove, folder ili odlomak teksta.
2. CrocApp generiše kodnu frazu. Izgovorite je, pošaljite porukom, ili je prikažite kao QR kod.
3. Primalac unosi frazu, vidi listu fajlova i prihvata je.

Obje strane pokreću PAKE preko kodne fraze kako bi izvele sesijski ključ, tako da fraza nikada ne prelazi mrežu u čistom obliku, a relej je nikada ne saznaje. Fajlovi su enkriptovani kodnom frazom; relej uvijek vidi samo šifrovani tekst. Isti Wi-Fi ili različiti kontinenti, CrocApp automatski pronalazi najbrži put.

## Slanje

1. Sa početnog ekrana, dodirnite ili kliknite **Send**.
2. Pod **What to send**, odaberite **Files** ili **Text**.
   - Za fajlove: koristite **Add Files** ili **Add Folder**, ili prevucite fajlove na područje za ispuštanje (macOS).
   - Za tekst: unesite ili zalijepite u tekstualno polje.
3. Opcionalno postavite **Custom code** (najmanje 6 znakova) umjesto generisanog.
4. Dodirnite **Send**.
5. CrocApp prikazuje **Ready to send** sa kodnom frazom, dugmetom **Copy Code** i QR kodom. Podijelite kod sa primaocem preko kanala kojem vjerujete.
6. Kada se primalac poveže i prihvati, prenos počinje. Kada se završi, CrocApp prikazuje **Transfer complete**.

## Primanje

1. Sa početnog ekrana, dodirnite ili kliknite **Receive**.
2. Unesite **Code phrase** koju vam je pošiljalac dao, zalijepite je, ili (na iOS-u) dodirnite **Scan QR Code**.
3. Provjerite odredišni folder prikazan ispod polja za kod; promijenite ga sa **Change** ako je potrebno.
4. Dodirnite **Receive**.
5. CrocApp prikazuje **Incoming transfer** sa listom fajlova i ukupnom veličinom. Pregledajte je, zatim dodirnite **Accept** ili **Decline**.
6. Kada se prenos završi, CrocApp prikazuje **Transfer complete** sa dugmetom za otvaranje odredišnog foldera (**Open in Files** na iOS-u, **Show in Finder** na macOS-u).

Za potpune detalje o svakom koraku, pogledajte [Slanje fajlova](../guide/sending.md) i [Primanje fajlova](../guide/receiving.md).
