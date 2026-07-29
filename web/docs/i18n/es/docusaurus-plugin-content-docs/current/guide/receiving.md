---
sidebar_position: 2
title: Recepción de archivos
description: Cómo recibir una transferencia en CrocApp, revisar la lista de archivos entrantes y gestionar conflictos.
---

# Recepción de archivos

![CrocApp en iOS mostrando una transferencia entrante de tres archivos con los botones Decline y Accept](/img/screenshots/ios-receive-light.png#gh-light-mode-only)![CrocApp en iOS mostrando una transferencia entrante de tres archivos con los botones Decline y Accept](/img/screenshots/ios-receive-dark.png#gh-dark-mode-only)

Abra **Receive** desde la pantalla de inicio.

## Introducir un código (F4)

Escriba la **Code phrase** en el campo, péguela con el botón **Paste**, o (solo en iOS) toque **Scan QR Code** para escanear el código QR del remitente. El botón **Receive** permanece desactivado hasta que el código introducido tiene al menos 6 caracteres.

## Elegir dónde llegan los archivos (F7)

Debajo del campo de código, CrocApp muestra la carpeta de destino actual. Toque **Change** para elegir una diferente, o **Reset** para volver a la predeterminada.

Los valores predeterminados difieren según la plataforma:

- **macOS**: `Downloads/CrocApp`
- **iOS**: la carpeta Documents de la app, visible en la app Files

## Aceptar o rechazar (F9)

Después de tocar **Receive** y conectar con el remitente, CrocApp muestra **Incoming transfer**: la lista completa de archivos con tamaños y un total. Desde aquí:

- **Accept** inicia la transferencia.
- **Decline** la rechaza. Esta es la única forma de rechazarla una vez vista la lista: no hay botón de cancelar en esta etapa.

Si el remitente tiene activado [Confirm on both sides](power-options.md), el remitente también debe confirmar antes de que la transferencia continúe.

## Sobrescritura y conflictos (F8)

CrocApp siempre permite sobrescribir al recibir. Si algún archivo entrante ya existe en el destino, la pantalla de aceptación añade un aviso: los elementos afectados se reemplazarán, y cualquier archivo recibido parcialmente se reanuda en lugar de reiniciarse. Los archivos con nombres inseguros (por ejemplo, los que intentan escapar de la carpeta de destino) bloquean **Accept** por completo, como medida de seguridad adicional sobre la propia sanitización de nombres de croc.

## Auto-accept (F18)

La aceptación automática está **desactivada por defecto**. Cuando está desactivada, siempre ve la vista previa de la lista de archivos antes de que se guarde nada. Activarla (en [opciones avanzadas](power-options.md)) omite esa vista previa; consulte esa página para el aviso exacto que muestra CrocApp cuando está activada.

## Después de la transferencia

Cuando termina, CrocApp muestra **Transfer complete** (o un mensaje si algo salió mal) con un botón para abrir el destino: **Open in Files** en iOS, **Show in Finder** en macOS.
