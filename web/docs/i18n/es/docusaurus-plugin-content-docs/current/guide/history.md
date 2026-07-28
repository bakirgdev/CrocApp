---
sidebar_position: 6
title: Historial
description: "El historial de transferencias solo local de CrocApp: qué registra, qué deliberadamente nunca registra y cómo borrarlo."
---

# Historial (F12)

CrocApp mantiene una lista local de transferencias pasadas, accesible desde el icono de historial de la pantalla de inicio. Nunca sale del dispositivo: no hay sincronización, no hay exportación y no hay servidor involucrado.

## Qué se registra

Para cada transferencia terminada o fallida:

- Dirección (enviada o recibida) y si fue una transferencia de texto
- Hasta 20 nombres de archivo
- Recuento total de archivos y tamaño total
- Una **pista del código**: solo el primer segmento de la frase código (por ejemplo, "7291-…"), nunca la frase completa
- Fecha y estado (completada, fallida, cancelada o rechazada)
- Para envíos, un conjunto de marcadores de archivo usados para dar soporte a **Send Again**: se capturan todo o nada, y hasta un máximo de 200 elementos; un registro sin marcadores simplemente no ofrece Send Again

## Qué nunca se registra

- El contenido de los archivos
- La frase código completa: solo esa pista del primer segmento
- Cualquier cosa más allá de los límites de 20 nombres y 200 marcadores

## Enviar de nuevo

Para un envío pasado, el menú contextual de la entrada del historial (o la acción de deslizar en iOS) ofrece **Send Again** si se capturaron marcadores para él. Esto vuelve a preparar los mismos archivos en un nuevo envío. Si los archivos originales se movieron o eliminaron desde entonces, CrocApp le indica que ya no están disponibles en lugar de enviar nada silenciosamente.

## Borrar el historial

Toque **Clear** en la barra de herramientas de la pantalla de historial y luego confirme. Esto solo elimina la lista: los archivos que ya recibió permanecen exactamente donde se guardaron.
