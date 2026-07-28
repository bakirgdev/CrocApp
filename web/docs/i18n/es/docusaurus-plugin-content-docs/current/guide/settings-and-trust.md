---
sidebar_position: 5
title: Configuración y confianza
description: Dónde vive la configuración de CrocApp, por qué podría ejecutar su propio relay, y qué le indica la insignia de confianza.
---

# Configuración y confianza

## Dónde vive la configuración

En macOS, la configuración está en la escena Settings (⌘,), con una sección **Receive** (carpeta de destino, más un botón **Show in Finder**) por encima de las [opciones avanzadas](power-options.md). En iOS, la pantalla de ajustes (accesible desde la barra de herramientas de inicio) contiene las opciones avanzadas; la carpeta de destino de recepción se cambia en su lugar desde la propia pantalla **Receive**.

La configuración persiste localmente en el dispositivo. No hay sincronización ni cuenta en la que iniciar sesión.

## Relay personalizado

Por defecto, CrocApp usa el relay público de croc. Puede configurarlo para apuntar a un relay que usted mismo ejecute en su lugar, bajo la [opción avanzada de Relay](power-options.md). Razones para ejecutar el suyo propio:

- Quiere que las transferencias pasen por infraestructura que usted controla en lugar del relay público compartido.
- Está operando en una red donde prefiere no depender de un servicio externo.

Basta con ejecutar `croc relay` en una máquina que usted controle; luego introduzca su dirección (y contraseña, si configuró una) en los campos de relay de CrocApp.

## La insignia de confianza

Durante una pantalla de espera, confirmación o transferencia, CrocApp muestra una insignia de confianza: una etiqueta **End-to-end encrypted** más una línea que describe la ruta de relay realmente en uso para esa transferencia:

- "Local network only — nothing leaves your network"
- "Via custom relay `<address>` — it sees only encrypted data"
- "Via the public croc relay — it sees only encrypted data"

Esto se captura en el momento en que empieza la transferencia, de modo que cambiar la configuración a mitad de la transferencia no puede hacer que la insignia diga algo que no sea cierto para la transferencia en curso.

## Qué se almacena

La configuración (dirección de relay, contraseña de relay, solo local, compresión, zip, patrones de exclusión, gitignore, confirmación en ambos lados, aceptación automática) se almacena localmente en el dispositivo. Ninguna configuración, contenido de transferencia o frase código se envía a ningún sitio salvo como parte de una transferencia real que usted inicie.
