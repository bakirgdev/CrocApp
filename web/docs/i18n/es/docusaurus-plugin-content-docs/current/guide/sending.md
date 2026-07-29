---
sidebar_position: 1
title: Envío de archivos
description: Cómo enviar archivos, carpetas y texto en CrocApp, incluida la extensión de compartir y la regla de una sola transferencia activa.
---

# Envío de archivos

![La pantalla Send de CrocApp en macOS con tres archivos preparados y el botón Send listo](/img/screenshots/mac-send-files-light.png#gh-light-mode-only)![La pantalla Send de CrocApp en macOS con tres archivos preparados y el botón Send listo](/img/screenshots/mac-send-files-dark.png#gh-dark-mode-only)

Abra **Send** desde la pantalla de inicio. El selector **What to send** cambia entre dos modos:

## Archivos (F1, F2)

- **Add Files** abre un selector de archivos; puede seleccionar varios a la vez.
- **Add Folder** elige una carpeta completa para enviar.
- En macOS, también puede arrastrar archivos o carpetas al área de destino.
- Los elementos elegidos aparecen en una lista, cada uno eliminable con su botón **x**.

## Texto (F3)

Escriba o pegue en el cuadro de texto, o use el botón **Paste** para traer directamente el contenido actual del portapapeles (esta es una acción explícita, no una lectura silenciosa en segundo plano).

## Código personalizado (F5)

El campo **Custom code** es opcional. Déjelo en blanco para un código generado, o introduzca el suyo (mínimo 6 caracteres) para poder compartirlo por un canal en el que ya confía, por ejemplo, dictándolo por una llamada.

## Iniciar el envío

Toque **Send**. CrocApp muestra la frase código generada (o personalizada), un botón **Copy Code** y un código QR (F6) que el destinatario puede escanear. La pantalla también muestra una insignia de confianza que describe qué ruta de relay está en uso.

## Una sola transferencia activa a la vez

CrocApp permite exactamente una transferencia activa a la vez, siguiendo un límite del motor subyacente. No puede iniciar un segundo envío o recepción mientras uno está en curso; termine o cancele la transferencia actual primero.

## Extensión de compartir (solo iOS, F30)

En iOS, puede compartir archivos a CrocApp desde la hoja de compartir de cualquier otra app. Los elementos compartidos quedan preparados, y aparece una hoja **Shared files** con los botones **Discard** y **Send** la próxima vez que abra CrocApp. Elegir **Send** lleva los archivos preparados al flujo normal de envío.

## Hoja de archivos preparados

La hoja de archivos preparados enumera cada elemento que se compartió, para que pueda revisar qué se enviará antes de confirmarlo.

## Qué ve el remitente durante la transferencia

Una vez que el destinatario conecta, CrocApp muestra **Ready to send** y espera. Si [both-sides confirm](power-options.md) está activado, recibe un aviso **Receiver connected** con **Send** / **Cancel** antes de que se mueva nada. Durante la transferencia, CrocApp muestra el progreso por archivo y general con la velocidad, además de un botón **Cancel**.
