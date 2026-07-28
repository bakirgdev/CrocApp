---
sidebar_position: 1
title: Interoperabilnost sa croc CLI-jem
description: CrocApp ugrađuje croc v10.5.0 kao Go biblioteku, tako da kodna fraza generisana CLI-jem radi u aplikaciji i obrnuto.
---

# Interoperabilnost sa croc CLI-jem

CrocApp ugrađuje **croc v10.5.0** kao Go biblioteku (putem framework-a izgrađenog sa `gomobile`) umjesto da poziva binarni fajl `croc`. To znači da govori potpuno isti protokol kao CLI, u oba smjera.

:::note
Upstream croc je objavio v10.6.0 nakon što je ova verzija fiksirana; CrocApp se još nije prebacio na nju.
:::

## Primjer: CLI šalje, aplikacija prima

Na laptopu, koristeći croc CLI:

```bash
croc send file.txt
# -> prints something like 9822-word-word-word
```

Na vašem telefonu ili Mac-u, otvorite **Receive** u CrocApp-u i unesite prikazani kod. Fajl stiže potpuno isto kao da je pošiljalac takođe koristio CrocApp.

## Primjer: aplikacija šalje, CLI prima

Pokrenite slanje u CrocApp-u, dobijte kodnu frazu koju prikazuje, zatim na drugoj mašini:

```bash
croc 9822-word-word-word
```

## Vlastiti relej

Obje strane moraju se dogovoriti oko releja. Iz CLI-ja:

```bash
croc --relay myserver:9009 send file.txt
```

U CrocApp-u, postavite istu adresu pod [naprednom opcijom releja](../guide/power-options.md).

## Mapiranje funkcija na oznake

| # | Funkcija | croc oznaka / porijeklo |
|---|---|---|
| F1 | Slanje fajlova (višestruko) | pozicioni argumenti |
| F2 | Slanje foldera | pozicioni argumenti |
| F3 | Slanje teksta/clipboarda | `--text` |
| F4 | Prijem putem koda | pozicioni argumenti |
| F5 | Prilagođena kodna fraza (min. 6 znakova) | `--code` |
| F6 | Prikaz QR-a pri slanju / skeniranje pri prijemu | `--qrcode` |
| F7 | Odabir izlaznog foldera | `--out` |
| F8 | Rukovanje prepisivanjem/nastavkom | `--overwrite` |
| F9 | Pregled dolazne liste fajlova, prihvatanje/odbijanje | interaktivni upit |
| F10 | Napredak, brzina, otkazivanje | — |
| F11 | Automatska utrka LAN + relej | croc zadano |
| F12 | Historija prenosa | — |
| F13 | Prilagođeni relej, lozinka, IPv6 | `--relay --relay6 --pass` |
| F14 | Prisilno samo lokalno | `--local` |
| F15 | Isključivanje kompresije | `--no-compress` |
| F16 | Zip-ovanje foldera prije slanja | `--zip` |
| F17 | Isključni obrasci / `.gitignore` | `--exclude --git` |
| F18 | Prekidač automatskog prihvatanja | `--yes` |
| F19 | Potvrda na obje strane | `--ask` |

## Kompatibilnost verzija i releja

Pošto CrocApp povezuje croc-ov vlastiti bibliotečki kod umjesto da ponovo implementira protokol, kompatibilnost releja i protokola prati sve što sam croc podržava u fiksiranoj verziji. Korištenje aktuelne, ne prastare `croc` CLI verzije na drugom kraju je najsigurniji izbor.
