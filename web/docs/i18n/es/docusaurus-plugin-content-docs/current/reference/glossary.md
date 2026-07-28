---
sidebar_position: 3
title: Glosario
description: Términos de cara al usuario empleados en toda la documentación de CrocApp.
---

# Glosario

| Término | Significado |
|---|---|
| Frase código / secreto | La cadena `NNNN-palabra-palabra-palabra` que ambos lados usan para encontrarse y derivar la clave de sesión. Los códigos personalizados tienen al menos 6 caracteres. |
| PAKE | Password-Authenticated Key Exchange (intercambio de claves autenticado por contraseña). Convierte la frase código débil en una clave de cifrado fuerte sin que el relay la conozca nunca. |
| Relay | El servidor al que ambos lados se conectan cuando no hay disponible una ruta directa de red local. Solo ve texto cifrado, nunca la clave. |
| Sala | El canal de encuentro en el relay, derivado de los primeros 4 caracteres de la frase código. Dos códigos que comparten esos caracteres pueden colisionar en la misma sala. |
| Curva | La curva elíptica sobre la que se ejecuta PAKE. CrocApp usa la predeterminada de croc. |
| Algoritmo de hash | La comprobación de integridad usada en los archivos transferidos. |
| Descubrimiento de pares en LAN | El mecanismo que permite a las transferencias en la misma red omitir el relay por completo; no está garantizado que funcione en todas las redes. |
| Solo local | Un ajuste que obliga a una transferencia a permanecer en la red local, rechazando el relay si no hay disponible una ruta directa. |
| Compresión | Los datos de archivo se comprimen por defecto en tránsito; se puede desactivar. |
| Insignia de confianza | El indicador en pantalla que muestra que una transferencia está cifrada de extremo a extremo y qué ruta de relay está usando. |
| Historial de transferencias | El registro local de CrocApp, solo en el dispositivo, de transferencias pasadas. |

Para el glosario completo de colaboradores e internals (internals del protocolo croc, el puente Go/gomobile, la arquitectura de la app y las convenciones del repositorio), consulte [`docs/GLOSSARY.md`](https://github.com/bakirgdev/CrocApp/blob/main/docs/GLOSSARY.md) en GitHub.
