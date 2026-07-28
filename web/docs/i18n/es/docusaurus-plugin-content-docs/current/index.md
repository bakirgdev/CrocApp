---
slug: /
sidebar_position: 1
title: Documentación de CrocApp
description: CrocApp es una aplicación nativa SwiftUI gratuita y de código abierto para iPhone, iPad y Mac que envía archivos con una frase código hablada.
---

:::warning
Esta traducción es un borrador asistido por máquina. Todavía no ha sido revisada por un hablante nativo. Si algo se lee mal, las correcciones son bienvenidas [en GitHub](https://github.com/bakirgdev/CrocApp/issues).

This translation is an unreviewed draft. The English version is authoritative.
:::

# Documentación de CrocApp

CrocApp envía archivos, carpetas y texto entre dos dispositivos en cualquier parte del mundo, cifrados de extremo a extremo, mediante una frase código corta como `8412-mirage-cobalt-fresco`. Sin cuenta, sin subida a la nube de terceros, sin necesidad de que ambos dispositivos compartan una red.

Es una interfaz gráfica para [croc](https://github.com/schollz/croc), la herramienta de transferencia de archivos por línea de comandos de Zack Scholl. CrocApp integra la librería Go de croc en lugar de invocar el binario externamente, de modo que una frase código generada por la CLI de croc funciona en la app, y una frase código generada por la app funciona en la CLI.

:::note
CrocApp no es oficial y no está afiliado. Nada aquí implica respaldo por parte del autor de croc.
:::

## Cómo funciona, en resumen

El remitente elige archivos, una carpeta o un fragmento de texto. CrocApp genera una frase código, que puede hablarse, enviarse por mensaje o mostrarse como código QR. El destinatario introduce la frase, ve la lista de archivos y acepta. Ambos lados ejecutan PAKE (intercambio de claves autenticado por contraseña) sobre la frase código para derivar una clave de sesión, de modo que la frase en sí nunca cruza la red en claro y el relay nunca la conoce. Cuando ambos dispositivos están en la misma red, CrocApp conecta directamente y omite el relay.

## Requisitos de plataforma

CrocApp requiere **iOS 26**, **iPadOS 26** o **macOS 26** (exactamente `26.0`, no una versión menor posterior). Es exclusivo de plataformas Apple; no hay cliente para Windows, Linux ni Android.

:::warning
CrocApp aún no se ha publicado. Hoy no hay nada disponible para descargar en ningún canal. Consulte [Instalación](getting-started/install.md) para el estado actual y cómo compilar desde el código fuente.
:::

## A dónde ir a continuación

- [Instalación](getting-started/install.md): estado del lanzamiento y cómo compilar desde el código fuente hoy
- [Primera transferencia](getting-started/first-transfer.md): un recorrido por un envío y una recepción
- [Envío de archivos](guide/sending.md), [Recepción de archivos](guide/receiving.md), [Frases código](guide/code-phrases.md)
- [Opciones avanzadas](guide/power-options.md), [Configuración y confianza](guide/settings-and-trust.md), [Historial](guide/history.md)
- [Interoperabilidad con la CLI de croc](reference/croc-cli-interop.md) y la [matriz de funciones](reference/feature-matrix.md)
- [Seguridad y privacidad](security-and-privacy.md), [Solución de problemas](troubleshooting.md), [Preguntas frecuentes](faq.md)
- [Contribuir](contribute.md)
