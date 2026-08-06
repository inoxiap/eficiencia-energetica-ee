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
- Libro: `REPORTE DE FUGAS.xlsx`.
- Ubicacion SharePoint: `/MEJORAS/1. SEGUIMIENTO DE LA ENERGIA/` en el sitio
  personal de OneDrive de `rpilco_danec_com`.

El libro local sincronizado se encuentra en
`C:\Users\windo\OneDrive - Grupo Danec\MEJORAS\1. SEGUIMIENTO DE LA ENERGIA\REPORTE DE FUGAS.xlsx`.

## Configuracion de Power Automate

El flujo independiente ya configurado es:

- Nombre: `EE - Sincronizar reportes de fugas con Excel`.
- ID: `d3324d4e-9a20-4842-bd2e-25e90c731d9d`.
- Estado: activo.
- Frecuencia: cada hora.
- Office Script: `EE - Sincronizar reportes de fugas`.

Acciones:

1. `GitHub / Get a particular issue`: repositorio privado e issue `#2`.
2. `Excel Online (Business) / Run script`: ejecutar el script
   `EE - Sincronizar reportes de fugas` con el cuerpo del issue en
   `payloadJson`.
3. `GitHub / Update an issue`: reemplazar el cuerpo del issue `#2` por el texto
   devuelto por el Office Script.

Si el lote ya esta `acknowledged`, el Office Script devuelve el mismo cuerpo y
no modifica la tabla. Si esta `ready`, inserta filas nuevas y actualiza por `id`
las existentes antes de emitir el acuse.

## Verificacion real

El 2026-08-05 se ejecuto el flujo manualmente en produccion:

- Power Automate: `Succeeded` en 10 segundos.
- GitHub: issue `#2` en estado `acknowledged`.
- Resultado: `insertedRows: 2`, `updatedRows: 0`.
- Excel: `App_Fugas` contiene cabecera y 2 filas en `tblAppFugas`.
- Fotografias: se conservaron las URLs y el proveedor `cloudinary`.

Las dos filas importadas corresponden a reportes historicos de prueba. El flujo
de calderas `EE - Actualizar Excel maestro desde GitHub` no fue modificado.

No guardar credenciales de Firebase ni tokens de GitHub en este directorio.
