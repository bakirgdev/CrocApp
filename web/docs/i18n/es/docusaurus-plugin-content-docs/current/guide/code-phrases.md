---
sidebar_position: 3
title: Frases código
description: Qué es una frase código de CrocApp, por qué funciona a la vez como dirección y contraseña, y las formas seguras de compartir una.
---

# Frases código

Una frase código tiene el aspecto de `8412-mirage-cobalt-fresco`: un PIN corto seguido de unas palabras. Se genera de nuevo para cada transferencia, salvo que configure una personalizada en la [pantalla de envío](sending.md).

## Es a la vez la dirección y la contraseña

Introducir el código en el otro dispositivo es todo lo necesario: es simultáneamente la forma en que los dos dispositivos se encuentran y el secreto que protege la transferencia. No hay nada más que configurar para una transferencia normal.

## Cómo protege la transferencia

Ambos dispositivos ejecutan **PAKE** (intercambio de claves autenticado por contraseña) sobre la frase código para convertirla en una clave de cifrado fuerte:

- El código en sí nunca cruza la red en claro.
- Un código incorrecto falla de inmediato, antes de que se mueva ningún dato de archivo.
- Todo se cifra en el dispositivo emisor y se descifra solo en el receptor; nada en el medio puede leerlo.

## De un solo uso y con expiración

Cada transferencia usa una frase código de un solo uso. Quien tenga el código se trata como el interlocutor de esa transferencia, y el código expira junto con ella: no es reutilizable para una transferencia posterior.

## Compartirla: código QR y pegar

CrocApp muestra el código como texto y como código QR (F6). El contenido del QR es `croc://<code>`, así que escanearlo también funciona con otras herramientas que entiendan la misma forma de enlace profundo.

Para introducir un código en el campo **Receive**, hay dos opciones explícitas: usar el botón **Paste**, o (en iOS) tocar **Scan QR Code**. CrocApp no lee el portapapeles de forma silenciosa; pegar es siempre algo que usted mismo activa. El texto pegado o escaneado puede incluir el prefijo `croc://` o ser un código simple: ambos se aceptan, siempre que lo que quede tenga al menos 6 caracteres sin espacios en blanco.

## Códigos personalizados

Un código personalizado debe tener al menos 6 caracteres. Configúrelo en el campo **Custom code** de la pantalla de envío para poder compartirlo por un canal en el que ya confía (una llamada telefónica, un chat cifrado existente) en lugar de depender del generado.

## Compartir un código de forma segura

Compártalo por un canal de confianza, de la misma forma en que compartiría un código de un solo uso: dígalo en voz alta, envíelo por un chat en el que ya confía, o deje que el destinatario escanee el código QR directamente desde su pantalla. Como el código es a la vez dirección y contraseña, cualquiera que lo obtenga antes de que la transferencia termine puede unirse a ella.
