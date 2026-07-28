---
slug: /
sidebar_position: 1
title: CrocApp dokumentacija
description: CrocApp je besplatna, open-source nativna SwiftUI aplikacija za iPhone, iPad i Mac koja šalje fajlove pomoću izgovorene kodne fraze.
---

:::warning
Ovaj prijevod je nacrt urađen uz pomoć mašinskog prevođenja. Nije ga još pregledao izvorni govornik. Ako nešto zvuči pogrešno, ispravke su dobrodošle na [GitHubu](https://github.com/bakirgdev/CrocApp/issues).

This translation is an unreviewed draft. The English version is authoritative.
:::

# CrocApp dokumentacija

CrocApp šalje fajlove, foldere i tekst između dva uređaja bilo gdje u svijetu, enkriptovano od kraja do kraja, koristeći kratku kodnu frazu poput `8412-mirage-cobalt-fresco`. Nema naloga, nema otpremanja na tuđi cloud, nema uslova da oba uređaja dijele istu mrežu.

To je grafički interfejs za [croc](https://github.com/schollz/croc), alat za prenos fajlova putem komandne linije koji je napravio Zack Scholl. CrocApp ugrađuje croc-ovu Go biblioteku umjesto da poziva binarni fajl, tako da kodna fraza generisana croc CLI-jem radi u aplikaciji, a kodna fraza generisana u aplikaciji radi u CLI-ju.

:::note
CrocApp je nezvanična aplikacija i nije povezana sa croc-om. Ništa ovdje ne podrazumijeva podršku autora croc-a.
:::

## Kako funkcioniše, ukratko

Pošiljalac bira fajlove, folder ili odlomak teksta. CrocApp generiše kodnu frazu, koja se može izgovoriti, poslati porukom ili prikazati kao QR kod. Primalac unosi frazu, vidi listu fajlova i prihvata je. Obje strane pokreću PAKE (razmjena ključeva autentifikovana lozinkom) preko kodne fraze kako bi izvele sesijski ključ, tako da sama fraza nikada ne prelazi mrežu u čistom obliku, a relej je nikada ne saznaje. Kada su oba uređaja na istoj mreži, CrocApp se povezuje direktno i preskače relej.

## Zahtjevi platforme

CrocApp zahtijeva **iOS 26**, **iPadOS 26** ili **macOS 26**, odnosno verziju `26.0` ili bilo koju noviju. Namijenjen je isključivo Apple platformama; ne postoji Windows, Linux ili Android klijent.

:::warning
CrocApp još nije objavljen. Trenutno ništa nije dostupno za preuzimanje ni na jednom kanalu. Pogledajte [Instalacija](getting-started/install.md) za trenutni status i kako izgraditi iz izvornog koda.
:::

## Šta dalje

- [Instalacija](getting-started/install.md): status izdanja i kako izgraditi iz izvornog koda već danas
- [Vaš prvi prenos](getting-started/first-transfer.md): vodič kroz jedno slanje i jedan prijem
- [Slanje fajlova](guide/sending.md), [Primanje fajlova](guide/receiving.md), [Kodne fraze](guide/code-phrases.md)
- [Napredne opcije](guide/power-options.md), [Postavke i povjerenje](guide/settings-and-trust.md), [Historija](guide/history.md)
- [Interoperabilnost sa croc CLI-jem](reference/croc-cli-interop.md) i [matrica funkcija](reference/feature-matrix.md)
- [Sigurnost i privatnost](security-and-privacy.md), [Rješavanje problema](troubleshooting.md), [Često postavljana pitanja](faq.md)
- [Doprinos](contribute.md)
