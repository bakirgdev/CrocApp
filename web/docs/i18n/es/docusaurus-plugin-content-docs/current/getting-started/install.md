---
sidebar_position: 1
title: Instalación
description: CrocApp aún no se ha publicado. Aquí está el estado actual de cada canal de distribución planificado y cómo compilar desde el código fuente hoy.
---

# Instalación

:::warning
**Aún no publicada.** Hoy no existe descarga en ningún canal. El código fuente es público y compilable ahora mismo; consulte [Compilar desde el código fuente](#build-from-source) más abajo.
:::

## Canales de distribución

CrocApp está planificada para cuatro canales. Ninguno está activo todavía.

| Canal | Estado |
|---|---|
| iOS / iPadOS App Store | Planificado |
| Mac App Store | Planificado |
| Descarga directa para macOS (DMG notarizado) | Planificado |
| Cask de Homebrew | Bloqueado por la notarización |

Notas sobre los bloqueos:

- **La notarización todavía no es real.** El script de notarización del proyecto actualmente se detiene en una comprobación en seco (`syspolicy_check distribution`) y no envía ni sella un ticket de notarización real.
- **Homebrew exige firma de código y notarización para casks oficiales** desde el 2026-09-01, así que el canal del cask permanece bloqueado hasta que llegue la notarización real.
- También está planificada una beta de TestFlight, para cuando haya una compilación que distribuir.

Todas las funciones de V1 están implementadas; lo que falta entre la app y un lanzamiento se rastrea en los [problemas conocidos](https://github.com/bakirgdev/CrocApp/blob/main/docs/known-issues.md) del proyecto bajo "Blocking release".

## Compilar desde el código fuente {#build-from-source}

Requiere:

- **macOS 26**
- **Xcode 26.6**
- **Go 1.26.5** o más reciente (`gomobile` y `gobind` se instalan solos en la primera ejecución)

```bash
git clone https://github.com/bakirgdev/CrocApp.git
cd CrocApp
scripts/build-xcframework.sh   # Go engine -> CrocKit/Croc.xcframework
open app/CrocApp.xcodeproj
```

:::warning
Un clon nuevo no compila nada hasta que exista el xcframework. El target binario de `CrocKit` apunta a un artefacto excluido de git, así que `scripts/build-xcframework.sh` no es opcional.
:::

La app en sí requiere **iOS 26**, **iPadOS 26** o **macOS 26** para ejecutarse.

Referencia completa del toolchain, ajustes de compilación y solución de problemas: [`docs/BUILDING.md`](https://github.com/bakirgdev/CrocApp/blob/main/docs/BUILDING.md) en GitHub.
