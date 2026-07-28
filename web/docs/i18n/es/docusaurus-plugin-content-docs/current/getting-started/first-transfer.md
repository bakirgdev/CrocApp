---
sidebar_position: 2
title: Primera transferencia
description: Un recorrido por un envío y una recepción en CrocApp, usando las etiquetas reales que aparecen en pantalla en la app.
---

# Primera transferencia

La pantalla de inicio de CrocApp tiene dos botones: **Send** y **Receive**. Todo lo demás se deriva de un flujo de tres pasos:

1. El remitente elige archivos, una carpeta o un fragmento de texto.
2. CrocApp genera una frase código. Se puede hablar, enviar por mensaje o mostrar como código QR.
3. El destinatario introduce la frase, ve la lista de archivos y acepta.

Ambos lados ejecutan PAKE sobre la frase código para derivar una clave de sesión, de modo que la frase nunca cruza la red en claro y el relay nunca la conoce. Los archivos se cifran con la frase código; el relay solo ve texto cifrado. Misma Wi-Fi o continentes distintos, CrocApp encuentra la ruta más rápida automáticamente.

## Enviar

1. Desde la pantalla de inicio, toque o haga clic en **Send**.
2. En **What to send**, elija **Files** o **Text**.
   - Para archivos: use **Add Files** o **Add Folder**, o arrastre archivos al área de destino (macOS).
   - Para texto: escriba o pegue en el cuadro de texto.
3. Opcionalmente configure un **Custom code** (al menos 6 caracteres) en lugar de uno generado.
4. Toque **Send**.
5. CrocApp muestra **Ready to send** con la frase código, un botón **Copy Code** y un código QR. Comparta el código con el destinatario por un canal de confianza.
6. Una vez que el destinatario conecta y acepta, la transferencia empieza. Cuando termina, CrocApp muestra **Transfer complete**.

## Recibir

1. Desde la pantalla de inicio, toque o haga clic en **Receive**.
2. Introduzca la **Code phrase** que le dio el remitente, péguela, o (en iOS) toque **Scan QR Code**.
3. Compruebe la carpeta de destino mostrada debajo del campo de código; cámbiela con **Change** si es necesario.
4. Toque **Receive**.
5. CrocApp muestra **Incoming transfer** con la lista de archivos y el tamaño total. Revísela y luego toque **Accept** o **Decline**.
6. Cuando la transferencia termina, CrocApp muestra **Transfer complete** con un botón para abrir la carpeta de destino (**Open in Files** en iOS, **Show in Finder** en macOS).

Para el detalle completo de cada paso, consulte [Envío de archivos](../guide/sending.md) y [Recepción de archivos](../guide/receiving.md).
