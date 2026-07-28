---
sidebar_position: 5
title: Sigurnost i privatnost
description: Tačna sigurnosna tvrdnja koju CrocApp iznosi, precizno formulisana, plus koje podatke prikuplja (nijedan) i kako prijaviti ranjivost.
---

# Sigurnost i privatnost

## Tvrdnja, precizno formulisana

Prenosi su enkriptovani od kraja do kraja, kodna fraza autentifikuje obje strane, a relej uvijek vidi samo šifrovani tekst. To je cijela tvrdnja.

:::warning
Nije bilo **formalne nezavisne sigurnosne revizije** croc-a, i CrocApp to ne tvrdi. Ne tretirajte CrocApp kao revidiran, sertifikovan ili provjeren po principu nultog znanja.
:::

## Kako funkcioniše

- **Jedan kod, jedan prenos.** Svaki prenos koristi kratku jednokratnu kodnu frazu. Ko god ima kod je partner u prenosu; podijelite ga preko kanala kojem vjerujete, i on ističe zajedno sa prenosom.
- **Jaki ključevi iz kratkih kodova.** Oba uređaja pokreću PAKE (razmjena ključeva autentifikovana lozinkom) kako bi kodnu frazu pretvorili u jak enkripcijski ključ. Sam kod nikada ne prelazi mrežu, a pogrešan kod odmah propada.
- **Enkriptovano od kraja do kraja.** Sve se enkriptuje na vašem uređaju i dekriptuje samo na drugom. Ništa između to ne može pročitati.
- **Relej je samo cijev.** Kada se uređaji ne mogu direktno povezati, internet relej prosljeđuje enkriptovani tok podataka. Relej nikada nema ključ: vidi samo šifrovani tekst. Možete i pokrenuti vlastiti relej i postaviti ga u postavkama.
- **Lokalna mreža kad je moguće.** Uređaji na istoj mreži prenose direktno; podaci nikada ne napuštaju vašu mrežu. Lokalni put i relej se utrkuju, a brži pobjeđuje.
- **Vi ostajete u kontroli.** Ništa se ne čuva bez vaše potvrde: dolazni prenosi prikazuju pregled fajlova koji prihvatate ili odbijate. Automatsko prihvatanje je isključeno osim ako ga sami ne uključite.

## Šta CrocApp ne radi

- Nema telemetrije, nema analitike, nema reklama, nema naloga.
- Historija prenosa je lokalna na uređaju, pogledajte [Historija](guide/history.md) za tačno ono što se bilježi.
- Umjesto zadanog javnog releja, CrocApp možete usmjeriti na vlastiti croc relej.
- Zavisnosti u Go engine-u se skeniraju pomoću `govulncheck` pri svakom CI pokretanju i ponovo na sedmičnoj osnovi.

## Prijavljivanje ranjivosti

Prijavite privatno putem [GitHub Security Advisories](https://github.com/bakirgdev/CrocApp/security/advisories/new). Nikada ne otvarajte javnu prijavu problema, diskusiju ili pull request za sumnjivu ranjivost.

Korisno je uključiti: šta napadač dobija i kakav pristup bi mu bio potreban, korake za reprodukciju (tok kodne fraze, relej, platforma), verziju ili commit CrocApp-a plus verziju OS-a i uređaj, te da li se isto ponašanje reproducira sa upstream `croc` CLI-jem.

Potpuna politika, opseg i šta nije obuhvaćeno (sam protokol prenosa pripada croc upstream-u): [`SECURITY.md`](https://github.com/bakirgdev/CrocApp/blob/main/SECURITY.md) na GitHubu.
