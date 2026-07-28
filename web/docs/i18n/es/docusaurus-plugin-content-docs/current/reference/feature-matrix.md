---
sidebar_position: 2
title: Matriz de funciones
description: Cada función planificada de CrocApp, numerada, agrupada y marcada con su estado real de publicación.
---

# Matriz de funciones

Los números de función (`F1`…) son identificadores estables usados en todo el proyecto. "Shipped" significa que la función existe y funciona en la app hoy; el proyecto todavía no ha publicado una compilación (consulte [Instalación](../getting-started/install.md)).

## Núcleo (publicado)

| # | Función | Flag de croc / origen |
|---|---|---|
| F1 | Enviar archivos (múltiples) | argumentos posicionales, arrastrar y soltar + selector de archivos |
| F2 | Enviar carpetas | argumentos posicionales |
| F3 | Enviar texto/portapapeles | `--text` |
| F4 | Recibir mediante código | argumentos posicionales |
| F5 | Frase código personalizada (mín. 6 caracteres) | `--code` |
| F6 | Mostrar QR al enviar + escanear QR al recibir | `--qrcode` + nativo de la GUI |
| F7 | Elegir carpeta de salida; en iOS por defecto es una carpeta de la app visible en Files | `--out` |
| F8 | Gestión de sobrescritura/reanudación mediante hojas de confirmación | `--overwrite` + reanudación |
| F9 | Vista previa de lista de archivos entrantes + aceptar/rechazar | equivalente al aviso interactivo |
| F10 | Progreso, velocidad, cancelar; Live Activity en iOS | consultado periódicamente al motor |
| F11 | Competencia automática entre LAN y relay | predeterminado de croc |
| F12 | Historial de transferencias (solo local) | nativo de la GUI |

## Opciones avanzadas (publicado)

| # | Función | Flag de croc |
|---|---|---|
| F13 | Relay personalizado + contraseña + IPv6 | `--relay --relay6 --pass` |
| F14 | Forzar solo local | `--local` |
| F15 | Desactivar compresión | `--no-compress` |
| F16 | Comprimir carpeta en zip antes de enviar | `--zip` |
| F17 | Excluir patrones / respetar `.gitignore` | `--exclude --git` |
| F18 | Interruptor de aceptación automática (desactivado por defecto, se muestra aviso) | `--yes` |
| F19 | Confirmación en ambos lados | `--ask` |

## Nativo de la GUI (publicado)

| # | Función | Estado |
|---|---|---|
| F30 | Extensión de compartir (enviar desde cualquier app) | publicado, solo iOS |
| F36 | UI de confianza: insignia de extremo a extremo, "cómo funciona", indicador de relay activo | publicado |

## Planificado, no iniciado (V1.x)

Ninguna de estas está construida todavía.

| # | Función | Flag de croc / origen |
|---|---|---|
| F20 | Proxy SOCKS5 / Tor | `--socks5` |
| F21 | Proxy HTTP | `--connect` |
| F22 | Limitación de subida | `--throttleUpload` |
| F23 | Elección de curva | `--curve` |
| F24 | Elección de algoritmo de hash | `--hash` |
| F25 | Conexión directa por IP | `--ip` |
| F26 | Dirección de multidifusión personalizada | `--multicast` |
| F27 | Ajuste de puertos/transferencias, desactivar multiplexado | `--port --transfers --no-multi` |
| F28 | Resolutor DNS interno | `--internal-dns` |
| F29 | Ejecutar el propio relay desde la app de Mac (servidor de relay en la barra de menú) | `croc relay` |
| F31 | Envío rápido desde la barra de menú de macOS (arrastrar y soltar) | nativo de la GUI |
| F32 | Enlace profundo `croc://code` + universal links | nativo de la GUI |
| F33 | Códigos guardados / pares favoritos | nativo de la GUI |
| F34 | App Intents / Atajos ("Send via croc") | nativo de la GUI |
| F35 | Comprobación de estado del relay + pantalla de diagnóstico | nativo de la GUI |

## Más adelante

| # | Función | Nota |
|---|---|---|
| F37 | Ruta directa Wi-Fi Aware | solo iOS/iPadOS 26, ausente en macOS 26; ruta rápida app a app |

## Deliberadamente no planificado

| # | Función | Motivo |
|---|---|---|
| F38 | Redirección `--stdout` | concepto exclusivo de la CLI |
| F39 | Modo `--classic` | inseguro por diseño |
| F40 | `--remember` | la configuración de la GUI ya persiste de todos modos |
