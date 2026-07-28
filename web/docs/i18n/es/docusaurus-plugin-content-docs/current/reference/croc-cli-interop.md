---
sidebar_position: 1
title: Interoperabilidad con la CLI de croc
description: CrocApp integra croc v10.5.0 como librería Go, así que una frase código generada por la CLI funciona en la app y viceversa.
---

# Interoperabilidad con la CLI de croc

CrocApp integra **croc v10.5.0** como librería Go (mediante un framework compilado con `gomobile`) en lugar de invocar el binario `croc` externamente. Eso significa que habla exactamente el mismo protocolo que la CLI, en ambas direcciones.

:::note
El proyecto croc en origen publicó v10.6.0 después de fijarse esta versión; CrocApp todavía no ha migrado a ella.
:::

## Ejemplo: la CLI envía, la app recibe

En un portátil, usando la CLI de croc:

```bash
croc send file.txt
# -> prints something like 9822-word-word-word
```

En su teléfono o Mac, abra **Receive** en CrocApp e introduzca el código impreso. El archivo llega exactamente igual que si el remitente también hubiera usado CrocApp.

## Ejemplo: la app envía, la CLI recibe

Inicie un envío en CrocApp, obtenga la frase código que muestra, y luego en otra máquina:

```bash
croc 9822-word-word-word
```

## Relay autoalojado

Ambos lados deben coincidir en el relay. Desde la CLI:

```bash
croc --relay myserver:9009 send file.txt
```

En CrocApp, configure la misma dirección bajo la [opción avanzada de relay](../guide/power-options.md).

## Correspondencia entre funciones y flags

| # | Función | Flag de croc / origen |
|---|---|---|
| F1 | Enviar archivos (múltiples) | argumentos posicionales |
| F2 | Enviar carpetas | argumentos posicionales |
| F3 | Enviar texto/portapapeles | `--text` |
| F4 | Recibir mediante código | argumentos posicionales |
| F5 | Frase código personalizada (mín. 6 caracteres) | `--code` |
| F6 | Mostrar QR al enviar / escanear al recibir | `--qrcode` |
| F7 | Elegir carpeta de salida | `--out` |
| F8 | Gestión de sobrescritura/reanudación | `--overwrite` |
| F9 | Vista previa de lista de archivos entrantes, aceptar/rechazar | aviso interactivo |
| F10 | Progreso, velocidad, cancelar | — |
| F11 | Competencia automática entre LAN y relay | predeterminado de croc |
| F12 | Historial de transferencias | — |
| F13 | Relay personalizado, contraseña, IPv6 | `--relay --relay6 --pass` |
| F14 | Forzar solo local | `--local` |
| F15 | Desactivar compresión | `--no-compress` |
| F16 | Comprimir carpeta en zip antes de enviar | `--zip` |
| F17 | Excluir patrones / `.gitignore` | `--exclude --git` |
| F18 | Interruptor de aceptación automática | `--yes` |
| F19 | Confirmación en ambos lados | `--ask` |

## Compatibilidad de versión y relay

Como CrocApp enlaza el propio código de librería de croc en lugar de reimplementar el protocolo, la compatibilidad de relay y protocolo sigue lo que croc mismo admita en la versión fijada. Usar una CLI `croc` actual y no demasiado antigua en el otro extremo es la apuesta más segura.
