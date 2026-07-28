---
sidebar_position: 1
title: Instalacija
description: CrocApp još nije objavljen. Evo trenutnog statusa svakog planiranog kanala distribucije i kako danas izgraditi iz izvornog koda.
---

# Instalacija

:::warning
**Još nije objavljen.** Danas ne postoji preuzimanje ni na jednom kanalu. Izvorni kod je javan i može se izgraditi već sada; pogledajte [Izgradnja iz izvornog koda](#build-from-source) ispod.
:::

## Kanali distribucije

CrocApp je planiran za četiri kanala. Nijedan još nije aktivan.

| Kanal | Status |
|---|---|
| iOS / iPadOS App Store | Planirano |
| Mac App Store | Planirano |
| macOS direktno preuzimanje (notarizovani DMG) | Planirano |
| Homebrew cask | Blokirano na notarizaciji |

Napomene o blokadama:

- **Notarizacija još nije stvarna.** Skripta za notarizaciju projekta trenutno staje na dry-run provjeri (`syspolicy_check distribution`) i ne podnosi zahtjev niti pribavlja pravu notarizacijsku potvrdu.
- **Homebrew zahtijeva potpisivanje koda i notarizaciju za zvanične caskove** od 2026-09-01, tako da kanal caska ostaje blokiran dok prava notarizacija ne bude dostupna.
- Planirana je i TestFlight beta verzija, za kada bude postojala verzija za distribuciju.

Svaka V1 funkcija je implementirana; ono što stoji između aplikacije i izdanja prati se u projektovim [poznatim problemima](https://github.com/bakirgdev/CrocApp/blob/main/docs/known-issues.md) pod "Blocking release".

## Izgradnja iz izvornog koda {#build-from-source}

Potrebno je:

- **macOS 26**
- **Xcode 26.6**
- **Go 1.26.5** ili noviji (`gomobile` i `gobind` se sami instaliraju pri prvom pokretanju)

```bash
git clone https://github.com/bakirgdev/CrocApp.git
cd CrocApp
scripts/build-xcframework.sh   # Go engine -> CrocKit/Croc.xcframework
open app/CrocApp.xcodeproj
```

:::warning
Svježi klon ne izgrađuje ništa dok xcframework ne postoji. Binarni cilj `CrocKit`-a pokazuje na artefakt izuzet iz git-a, tako da `scripts/build-xcframework.sh` nije opcionalan.
:::

Sama aplikacija zahtijeva **iOS 26**, **iPadOS 26** ili **macOS 26** za pokretanje.

Potpuna referenca alatnog lanca, postavke izgradnje i rješavanje problema: [`docs/BUILDING.md`](https://github.com/bakirgdev/CrocApp/blob/main/docs/BUILDING.md) na GitHubu.
