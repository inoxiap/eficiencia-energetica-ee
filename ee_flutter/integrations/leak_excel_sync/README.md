# Sincronizacion de reportes de fugas

Firestore conserva la fuente oficial. GitHub funciona solamente como transito
incremental hacia Power Automate y Excel; el issue privado mantiene un unico
lote pendiente y no acumula archivos ni historiales duplicados.

## Flujo

1. El workflow horario existente consulta `leak_reports` por `updatedAt`.
2. Cada fila incluye fecha, hora y usuario obtenidos automaticamente del
   registro, los codigos del destino, la evidencia y el estado del trabajo.
3. El lote se publica en el issue privado `#2`.
4. Mientras el lote tenga estado `ready`, GitHub Actions no vuelve a consultar
   Firestore ni sobrescribe informacion.
5. Power Automate lee el issue, ejecuta `office_script.ts` sobre el libro de
   OneDrive y reemplaza el cuerpo del issue por el acuse `acknowledged`.
6. La siguiente ejecucion consulta solamente documentos creados o actualizados
   despues del cursor confirmado.

Las filas se actualizan por el `id` estable del reporte. Por eso los cambios de
`workOrderCreated`, `workCompleted` y `status` llegan a la misma fila de Excel
sin crear duplicados.

## Hoja de Excel

El Office Script crea o reutiliza:

- Hoja: `App_Fugas`.
- Tabla: `tblAppFugas`.

La ubicacion y el nombre del libro se seleccionan al configurar la accion
`Excel Online (Business) / Run script` en Power Automate.

## Configuracion de Power Automate

Crear un segundo flujo programado o agregar una rama al flujo existente:

1. `GitHub / Get a particular issue`: repositorio privado e issue `#2`.
2. Condicion: continuar solo si el cuerpo contiene `\"status\":\"ready\"`.
3. `Excel Online (Business) / Run script`: ejecutar el script
   `EE - Sincronizar reportes de fugas` con el cuerpo del issue en
   `payloadJson`.
4. `GitHub / Update an issue`: reemplazar el cuerpo del issue `#2` por el texto
   devuelto por el Office Script.

No guardar credenciales de Firebase ni tokens de GitHub en este directorio.
