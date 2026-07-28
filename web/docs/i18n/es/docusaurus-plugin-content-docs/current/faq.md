---
sidebar_position: 7
title: Preguntas frecuentes
description: Preguntas frecuentes sobre CrocApp, coste, seguridad, cuentas y compatibilidad de plataformas.
---

# Preguntas frecuentes

## ¿Qué cuesta?

Nada. Sin compra, sin suscripción, sin publicidad y sin analítica. CrocApp es gratuita, tiene licencia MIT y seguirá siéndolo. La monetización se limita a patrocinio opcional.

## ¿Es realmente segura?

Las transferencias están cifradas de extremo a extremo, la frase código autentica a ambos lados, y el relay solo ve texto cifrado. Esa es toda la afirmación, y es el diseño de croc, no algo que CrocApp añada. No ha habido ninguna auditoría formal de terceros sobre croc, y CrocApp no afirma tenerla. El código de ambos lados es abierto si desea revisarlo.

## ¿Necesito una cuenta?

No. No hay nada que registrar y ninguna identidad asociada a una transferencia.

## ¿Mi archivo pasa por un servidor?

Normalmente sí: un relay, que reenvía el tráfico entre dos dispositivos que no pueden alcanzarse directamente. Solo ve texto cifrado y nada más, y no almacena el archivo. Puede configurar CrocApp para usar su propio relay en su lugar.

## ¿Y si estamos en la misma red Wi-Fi?

Entonces la transferencia va directamente entre los dos dispositivos y omite el relay por completo. CrocApp prueba ambas rutas a la vez y usa la que conecte primero.

## ¿En qué se diferencia de AirDrop?

AirDrop necesita dos dispositivos Apple en proximidad física. CrocApp funciona entre dos dispositivos cualesquiera que ejecuten croc o CrocApp, en cualquier red, a cualquier distancia, incluso de un Mac a un servidor Linux al otro lado del mundo.

## ¿Funciona con la herramienta de línea de comandos croc?

Sí, en ambas direcciones. CrocApp integra croc v10.5.0 como librería, así que habla el mismo protocolo. `croc send` en un portátil, recepción en la app en un teléfono, y a la inversa.

## ¿Puedo ejecutar mi propio relay?

Sí. Configure CrocApp para apuntar a cualquier relay de croc, con contraseña e IPv6 si lo desea. Basta con ejecutar `croc relay` en una máquina que usted controle.

## ¿Por qué solo iOS 26 y macOS 26?

CrocApp es una app nueva sin usuarios existentes. Dar soporte a versiones anteriores implicaría comprobaciones de disponibilidad por todas partes y renunciar a las API actuales de SwiftUI y al lenguaje de diseño Liquid Glass. La versión mínima es `26.0`, y cualquier versión posterior funciona. El umbral se fija en `26.0` y no en una versión menor posterior, precisamente para que nadie con 26.0 a 26.4 quede excluido.

## ¿Es gratis? ¿Tendrá algún día un nivel de pago?

Gratis, con licencia MIT, y seguirá siéndolo. La monetización se limita a [patrocinio](https://github.com/sponsors/bakirgdev) opcional.

## ¿Habrá una versión para Windows, Linux o Android?

No. CrocApp es exclusiva de plataformas Apple por diseño. Use la [CLI de croc](https://github.com/schollz/croc) en otras plataformas: interopera con esta app.
