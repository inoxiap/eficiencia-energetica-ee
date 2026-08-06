# Decisiones tecnicas

## Evolucion incremental

Se conserva la aplicacion Flutter y sus formulas. No se reescribio el producto.
La extraccion de dominios/servicios se hizo solo para persistencia, seguridad y
el nuevo modulo de bombas.

## Imagenes

Se identifico y conserva Cloudinary:

- Cloud name dovufh5wv.
- Preset ee_evidencias_unsigned.
- Firestore guarda URL segura y public ID.

No se migro a Firebase Storage. storage.rules niega todo uso accidental de
Firebase Storage. El preset unsigned debe limitar formato, tamano y carpeta en
Cloudinary; una mejora futura puede firmar cargas desde backend sin cambiar de
proveedor.

## Colecciones

Se conservan bare_pipe_reports y boiler_consumption_readings. Se agregan:

- steam_trap_sizing_reports.
- pump_energy_surveys.
- users.
- user_private_credentials.
- audit_logs.
- motor_reference_tables.
- leak_reports.
- steam_pressure_readings.

Los lectores mantienen compatibilidad con fechas ISO y campos historicos.

El catalogo de destinos de fugas se genera desde el JSON SISMAC validado. El
asset Flutter conserva codigos y etiquetas en una jerarquia compacta; no
autoselecciona descendientes. La eleccion parcial es valida y la ultima hoja
unica determina `destinationId`.

Firestore sigue siendo la fuente oficial de fugas. El transporte a Excel usa
un lote incremental en un issue privado de GitHub y un Office Script
idempotente por `id`; GitHub no se usa como almacenamiento historico.

## Autenticacion

La cedula+PIN se resuelve directamente con Firebase Authentication usando el
proveedor correo/contrasena. La app deriva una direccion tecnica estable de la
cedula y adapta el PIN al minimo de Firebase sin mostrar correo al operador.
Firebase Auth conserva la sesion y el registro publico siempre crea `operator`.
Esta decision elimina Cloud Functions y mantiene compatibilidad con Spark.

El PIN corto ofrece seguridad limitada por definicion; es una decision
consciente para uso interno de pocos operadores. No se guarda PIN en Firestore
ni almacenamiento local.

## Calderas

Se mantuvieron las tres calderas presentes en codigo y datos. Vapor permanece
habilitado unicamente para Alfa Laval por decision de planta. Distral 900 y
Cleaver Brooks conservan el campo de vapor deshabilitado. Caldera 1100 no se
invento.

Las unidades de agua y bunker se normalizan en galones (`gal`). El vapor de
Alfa Laval se guarda en kilogramos (`kg`). Todas las lecturas nuevas se crean
como `cumulative_meter`. El soporte para `interval_consumption` permanece solo
al leer documentos historicos.

## Presiones de distribuidores

El modulo de consumos usa una navegacion inferior con las vistas Consumos y
Presiones. Las presiones se guardan en `steam_pressure_readings`, siempre en
PSI, separadas en mapas para el distribuidor Cleaver y el distribuidor 900.
Antes de escribir se presenta un resumen y se solicita confirmacion explicita.

## Offline

No se anuncia guardado en nube hasta una lectura Source.server. Tuberia conserva
estado pending_sync cuando Cloudinary termino pero Firestore no confirmo. Los
otros modulos conservan IDs idempotentes para reintento. Una cola general
durable queda como mejora posterior; no se oculto esa limitacion.

## Dashboard

Se separo de Flutter y usa Firebase Admin solo en el servidor. El inicio de
sesion valida la misma cuenta de Firebase Auth y revalida rol/estado contra
Firestore. Las consultas usan rango
temporal, lotes y limite configurable. Los datos historicos ISO y Timestamp se
consultan por separado y se deduplican.

## Sincronizacion con Excel corporativo

Firestore permanece como fuente oficial. El Excel corporativo es una vista
operativa derivada y nunca sustituye la trazabilidad de Firestore.

Se descarto el disparador HTTP de Power Automate porque requiere licencia
Premium. Tambien se descarto Microsoft Graph directo porque exige una
aplicacion Entra y autorizacion administrativa adicional.

La arquitectura sin costo adicional usa:

- Un GitHub Action en el repositorio privado para consultar Firestore y
  calcular un payload incremental.
- Un issue en un repositorio GitHub privado como buzon temporal.
- El conector estandar GitHub de Power Automate para leer el issue.
- Excel Online (Business) y Office Scripts para modificar el mismo maestro.

El repositorio de codigo es publico y no puede contener datos operativos. El
workflow privado usa el `GITHUB_TOKEN` automatico de su propio repositorio con
permiso exclusivo de escritura de issues; no necesita un token personal. El
Office Script usa claves estables para crear o actualizar, conserva un mapa de
filas y no sobrescribe conflictos historicos no administrados.
