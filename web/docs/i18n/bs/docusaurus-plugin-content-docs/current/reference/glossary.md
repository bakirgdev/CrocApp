---
sidebar_position: 3
title: Rječnik pojmova
description: Pojmovi za korisnike koji se koriste u cijeloj CrocApp dokumentaciji.
---

# Rječnik pojmova

| Pojam | Značenje |
|---|---|
| Kodna fraza / tajna | Niz oblika `NNNN-word-word-word` koji obje strane koriste da se pronađu i izvedu sesijski ključ. Prilagođeni kodovi imaju najmanje 6 znakova. |
| PAKE | Password-Authenticated Key Exchange (razmjena ključeva autentifikovana lozinkom). Pretvara slabu kodnu frazu u jak enkripcijski ključ, a da to relej nikada ne sazna. |
| Relay (relej) | Server na koji se obje strane povezuju kada direktan put preko lokalne mreže nije dostupan. Vidi samo šifrovani tekst, nikada ključ. |
| Room (soba) | Kanal za susret na releju, izveden iz prva 4 znaka kodne fraze. Dva koda koja dijele te znakove mogu kolidirati u istu sobu. |
| Curve (kriva) | Eliptička kriva preko koje se izvodi PAKE. CrocApp koristi croc-ovu zadanu. |
| Hash algoritam | Provjera integriteta koja se koristi na prenesenim fajlovima. |
| LAN otkrivanje uređaja | Mehanizam koji omogućava prenosima na istoj mreži da u potpunosti preskoče relej; nije zagarantovano da radi na svakoj mreži. |
| Local-only (samo lokalno) | Postavka koja prisiljava prenos da ostane na lokalnoj mreži, odbijajući relej ako direktan put nije dostupan. |
| Kompresija | Podaci fajla se po zadanom kompresuju tokom prenosa; može se isključiti. |
| Značka povjerenja | Indikator na ekranu koji pokazuje da je prenos enkriptovan od kraja do kraja i koji relejni put koristi. |
| Historija prenosa | CrocApp-ov lokalni zapis prošlih prenosa, dostupan samo na uređaju. |

Za potpuni rječnik pojmova za saradnike i internu upotrebu (interni protokol croc-a, Go/gomobile most, arhitektura aplikacije i konvencije repozitorija), pogledajte [`docs/GLOSSARY.md`](https://github.com/bakirgdev/CrocApp/blob/main/docs/GLOSSARY.md) na GitHubu.
