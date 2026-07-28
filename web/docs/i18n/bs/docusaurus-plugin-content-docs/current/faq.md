---
sidebar_position: 7
title: Često postavljana pitanja
description: Često postavljana pitanja o CrocApp-u, cijeni, sigurnosti, nalozima i podršci za platforme.
---

# Često postavljana pitanja

## Koliko to košta?

Ništa. Nema kupovine, nema pretplate, nema reklama i nema analitike. CrocApp je besplatan, licenciran pod MIT licencom, i tako će i ostati. Monetizacija je ograničena na opcionalno sponzorstvo.

## Da li je zaista siguran?

Prenosi su enkriptovani od kraja do kraja, kodna fraza autentifikuje obje strane, a relej uvijek vidi samo šifrovani tekst. To je cijela tvrdnja, i to je croc-ov dizajn, a ne nešto što CrocApp dodaje. Nije bilo formalne nezavisne revizije croc-a, i CrocApp to ne tvrdi. Kod na obje strane je otvoren ako želite pogledati.

## Da li mi treba nalog?

Ne. Nema ničega za registraciju i nema identiteta vezanog za prenos.

## Da li moj fajl prolazi kroz server?

Obično da: relej, koji prosljeđuje saobraćaj između dva uređaja koja se ne mogu direktno dosegnuti. On vidi samo šifrovani tekst i ništa više, i ne čuva vaš fajl. Umjesto toga možete usmjeriti CrocApp na vlastiti relej.

## Šta ako smo na istom Wi-Fi-ju?

Onda prenos ide direktno između dva uređaja i u potpunosti preskače relej. CrocApp istovremeno pokušava oba puta i koristi onaj koji se prvi poveže.

## Po čemu se ovo razlikuje od AirDrop-a?

AirDrop zahtijeva dva Apple uređaja u fizičkoj blizini. CrocApp radi između bilo koja dva uređaja koji pokreću croc ili CrocApp, na bilo kojoj mreži, na bilo kojoj udaljenosti, uključujući sa Mac-a na Linux server na drugom kraju svijeta.

## Da li radi sa croc alatom za komandnu liniju?

Da, u oba smjera. CrocApp ugrađuje croc v10.5.0 kao biblioteku, tako da govori isti protokol. `croc send` na laptopu, prijem u aplikaciji na telefonu, i obrnuto.

## Mogu li pokrenuti vlastiti relej?

Da. Usmjerite CrocApp na bilo koji croc relej, sa lozinkom i IPv6 ako ih želite. Dovoljno je pokrenuti `croc relay` na mašini koju kontrolišete.

## Zašto samo iOS 26 i macOS 26?

CrocApp je potpuno nova aplikacija bez postojećih korisnika. Podrška starijim izdanjima značila bi provjere dostupnosti svuda i odricanje od trenutnih SwiftUI API-ja i Liquid Glass dizajn jezika. Minimalna verzija je `26.0`, a svaka novija radi. Donja granica je fiksirana na `26.0`, a ne na kasniju manju verziju, upravo zato da niko sa verzijama od 26.0 do 26.4 ne ostane zaključan.

## Da li je besplatan? Hoće li ikada imati plaćeni nivo?

Besplatan je, licenciran pod MIT licencom, i tako će i ostati. Monetizacija je ograničena na opcionalno [sponzorstvo](https://github.com/sponsors/bakirgdev).

## Hoće li postojati Windows, Linux ili Android verzija?

Ne. CrocApp je namjerno isključivo za Apple platforme. Za ostalo koristite [croc CLI](https://github.com/schollz/croc), on je interoperabilan sa ovom aplikacijom.
