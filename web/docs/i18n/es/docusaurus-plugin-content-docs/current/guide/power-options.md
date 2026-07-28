---
sidebar_position: 4
title: Opciones avanzadas
description: Los ajustes avanzados publicados (F13 a F19) y el flag de la CLI de croc al que corresponde cada uno.
---

# Opciones avanzadas

CrocApp expone un conjunto de opciones avanzadas con valores predeterminados razonables. En macOS viven en la escena Settings (⌘,); en iOS están en la pantalla de ajustes accesible desde la barra de herramientas de inicio. Las siete siguientes ya están publicadas.

| # | Opción | Control | Equivalente en croc |
|---|---|---|---|
| F13 | Relay personalizado, contraseña, IPv6 | Campos **Address**, **IPv6 address**, **Password** bajo Relay | `--relay --relay6 --pass` |
| F14 | Forzar transferencias solo locales | Interruptor **Local network only** | `--local` |
| F15 | Desactivar compresión | Interruptor **Disable compression** | `--no-compress` |
| F16 | Comprimir una carpeta en zip antes de enviar | Interruptor **Zip folders before sending** | `--zip` |
| F17 | Excluir patrones, respetar `.gitignore` | Campo **Patterns, one per line**, interruptor **Respect .gitignore** | `--exclude --git` |
| F18 | Aceptación automática de entrantes, desactivada por defecto | Interruptor **Auto-accept incoming files** | `--yes` |
| F19 | Exigir confirmación en ambos lados | Interruptor **Confirm on both sides** | `--ask` |

## Relay (F13)

Los campos **Address** y **IPv6 address** muestran los valores predeterminados propios de croc como texto de marcador de posición; déjelos en blanco para usar el relay predeterminado de croc. Deje **Password** en blanco para usar la contraseña predeterminada del relay de croc.

## Local network only (F14)

Cuando está activado, las transferencias nunca tocan un relay en internet: CrocApp solo usa la red local. Si no se puede establecer una conexión local directa, la transferencia falla en lugar de recurrir a un relay.

## Exclude patterns (F17)

Los patrones van uno por línea en el campo **Patterns, one per line**. **Respect .gitignore** excluye adicionalmente cualquier cosa que su `.gitignore` excluiría.

## Auto-accept (F18)

La aceptación automática está desactivada por defecto. Con ella activada, CrocApp muestra este aviso: "Files from anyone who has your code are saved without preview or confirmation. Unsafe file names still cancel the transfer. Both-sides confirm overrides auto-accept." Con ella desactivada: "Auto-accept skips the incoming-files preview. Leave it off unless you fully trust the sender."

## Confirm on both sides (F19)

Cuando está activado, el remitente también tiene que aprobar la transferencia (mediante un aviso **Receiver connected**) antes de que empiece, además del paso normal de aceptación del destinatario.

## Aún no construido

Un conjunto adicional de capacidades de croc (proxy SOCKS5/Tor, proxy HTTP, limitación de velocidad de subida, elección de curva y algoritmo de hash, conexión directa por IP, dirección de multidifusión personalizada, ajuste de puertos/transferencias, un resolutor DNS interno, y ejecutar su propio relay desde la app de Mac) está planificado para una versión posterior pero todavía no se ha empezado.
