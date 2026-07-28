---
sidebar_position: 5
title: Seguridad y privacidad
description: La afirmación exacta de seguridad que hace CrocApp, expresada con precisión, más qué datos recopila (ninguno) y cómo reportar una vulnerabilidad.
---

# Seguridad y privacidad

## La afirmación, expresada con precisión

Las transferencias están cifradas de extremo a extremo, la frase código autentica a ambos lados, y el relay solo ve texto cifrado. Esa es toda la afirmación.

:::warning
No ha habido **ninguna auditoría de seguridad formal de terceros** sobre croc, y CrocApp no afirma tenerla. No trate a CrocApp como auditada, certificada o verificada con conocimiento cero.
:::

## Cómo funciona

- **Un código, una transferencia.** Cada transferencia usa una frase código corta de un solo uso. Quien tenga el código es el interlocutor de la transferencia; compártalo por un canal de confianza, y expira junto con la transferencia.
- **Claves fuertes a partir de códigos cortos.** Ambos dispositivos ejecutan PAKE (intercambio de claves autenticado por contraseña) para convertir la frase código en una clave de cifrado fuerte. El código en sí nunca cruza la red, y un código incorrecto falla de inmediato.
- **Cifrado de extremo a extremo.** Todo se cifra en su dispositivo y se descifra solo en el otro. Nada en el medio puede leerlo.
- **El relay es solo una tubería.** Cuando los dispositivos no pueden conectar directamente, un relay de internet reenvía el flujo cifrado. El relay nunca tiene la clave: solo ve texto cifrado. También puede ejecutar su propio relay y configurarlo en los ajustes.
- **Red local cuando es posible.** Los dispositivos en la misma red transfieren directamente; los datos nunca salen de su red. La ruta local y el relay compiten, y gana el más rápido.
- **Usted mantiene el control.** Nada se guarda sin su aprobación: las transferencias entrantes muestran una vista previa de archivos que usted acepta o rechaza. La aceptación automática está desactivada salvo que la active.

## Lo que CrocApp no hace

- Sin telemetría, sin analítica, sin anuncios, sin cuentas.
- El historial de transferencias es local al dispositivo; consulte [Historial](guide/history.md) para saber exactamente qué registra.
- Puede configurar CrocApp para usar su propio relay de croc en lugar del público predeterminado.
- Las dependencias del motor en Go se escanean con `govulncheck` en cada ejecución de CI y de nuevo semanalmente.

## Reportar una vulnerabilidad

Repórtela en privado a través de [GitHub Security Advisories](https://github.com/bakirgdev/CrocApp/security/advisories/new). Nunca abra una incidencia pública, un debate o una pull request para una posible vulnerabilidad.

Es útil incluir: qué obtiene un atacante y qué acceso necesitaría, pasos de reproducción (flujo de la frase código, relay, plataforma), la versión o commit de CrocApp más la versión del sistema operativo y el dispositivo, y si el mismo comportamiento se reproduce con la CLI `croc` original.

Política completa, alcance y qué queda fuera de alcance (el propio protocolo de transferencia pertenece a croc en origen): [`SECURITY.md`](https://github.com/bakirgdev/CrocApp/blob/main/SECURITY.md) en GitHub.
