---
sidebar_position: 6
title: Solución de problemas
description: "Soluciones reales y verificadas para problemas comunes de CrocApp: transferencias detenidas, códigos rechazados, límites de segundo plano y problemas de permisos."
---

# Solución de problemas

## La transferencia se detiene o nunca conecta

CrocApp hace competir una conexión directa de red local contra el relay y usa la que conecte primero. El descubrimiento de pares en red local usa multidifusión UDP, y no está garantizado que funcione en todas las redes: algunas redes (por ejemplo, Wi-Fi con aislamiento de clientes) no devuelven ningún par local, aunque la ruta del relay siga funcionando bien. Si una transferencia se detiene en "Waiting" o "Connecting":

- Compruebe que ambos dispositivos tienen acceso a internet en funcionamiento, para que la ruta del relay pueda funcionar aunque la ruta local no pueda.
- Compruebe el [permiso de red local](#local-network-permission-prompt) más abajo.
- No hay una solución dentro de la app para una red que bloquea el descubrimiento por multidifusión por completo; la transferencia debería completarse igualmente a través del relay.

## El código es rechazado o el botón de recepción permanece desactivado

- Una frase código debe tener al menos 6 caracteres. El botón **Receive** permanece desactivado hasta que se ha introducido suficiente.
- Un código incorrecto falla de inmediato en lugar de quedarse colgado.
- Si usa un código personalizado que también emplea para pruebas o scripts, tenga en cuenta que los códigos que comparten sus primeros 4 caracteres pueden colisionar en la misma sala del relay. Los códigos generados no tienen este problema.

## El otro lado usa una versión diferente de croc

CrocApp integra croc v10.5.0 como motor. Está construida para interoperar con la CLI `croc` en ambas direcciones. Si el otro lado ejecuta una versión de `croc` muy antigua o inusualmente nueva, use una versión razonablemente actual de la CLI para evitar incompatibilidades de protocolo.

## Límites de segundo plano en iOS

iOS no permite que las transferencias TCP en bruto sigan ejecutándose arbitrariamente en segundo plano. CrocApp usa `BGContinuedProcessingTask` (iOS 26+) para mantener una transferencia en curso y mostrar una Live Activity del sistema, pero es un mejor esfuerzo: el sistema puede finalizarla bajo presión de memoria, y una transferencia con poco progreso tiene más probabilidad de ser terminada que una casi completa. Para una transferencia que no quiera que se interrumpa, mantenga CrocApp en primer plano hasta que termine. Si se corta de todos modos, el propio comportamiento de reanudación de croc hace que reiniciar la misma transferencia continúe desde donde se quedó en lugar de empezar de nuevo.

## Aviso de permiso de red local {#local-network-permission-prompt}

En el primer uso de red local, iOS muestra un aviso del sistema pidiendo permiso para que CrocApp encuentre dispositivos en su red local. Si lo deniega, o la concesión queda "atascada" (una peculiaridad conocida de iOS en la que un permiso concedido no funciona realmente hasta que se alterna o se reinicia), CrocApp recurre solo al relay. Si ve el banner "Local network access is off — transfers use the relay only", use su botón **Open Settings** para revisar Ajustes › Privacidad › Red local.

## Los archivos recibidos no están visibles donde se esperaba

- En iOS, los archivos recibidos llegan a la carpeta Documents de la app, visible en la app Files por defecto.
- Si el destino de recepción se configuró en una carpeta elegida a través de un proveedor de almacenamiento en la nube (en lugar de una ubicación local), el botón **Open in Files** tras una recepción puede no abrirla correctamente: esta es una limitación conocida. Navegue a la carpeta manualmente en la app Files en su lugar.

## Relay inalcanzable

CrocApp usa el relay público de croc por defecto. Si no es alcanzable desde su red, puede configurar un [relay personalizado](guide/settings-and-trust.md) que usted controle en su lugar, o activar **Local network only** si ambos dispositivos están en la misma red y no necesita el relay en absoluto.

## Aceptación automática y remitentes con `--ask`

Si tiene la aceptación automática activada y el remitente usa el indicador de confirmación `--ask` de croc, la transferencia puede rechazarse automáticamente, y el mensaje de CrocApp actualmente culpa al lado equivocado ("the other side declined") en lugar de explicar que su propio ajuste de aceptación automática lo causó. Este es un problema conocido sin solución todavía; desactivar la aceptación automática lo evita.

## Sin botón de cancelar mientras se revisa una transferencia entrante

Una vez que está viendo la lista de archivos entrantes, **Decline** es la única salida: no hay un botón de cancelar independiente en esa etapa, y la notificación de fin de transferencia puede retrasarse ligeramente mientras croc termina los intentos de reconexión por debajo. Este es el comportamiento esperado, no un error.
