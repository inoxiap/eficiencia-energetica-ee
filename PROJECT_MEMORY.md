# Memoria del proyecto: Eficiencia Energetica EE

Ultima actualizacion: 2026-07-27

Este documento es la memoria operativa persistente del proyecto. Debe leerse
completo al iniciar o retomar cualquier tarea y actualizarse al terminar cambios
o descubrir informacion relevante. No guardar secretos ni credenciales aqui.

## Identidad y ubicacion

- Usuario del proyecto: Jeff.
- Nombre usado para el asistente: Phanto.
- Repositorio canonico:
  `C:\Users\windo\Documents\Codex\2026-05-12\phanto-puedes-hacer-una-aplicaci-n`
- Repositorio remoto:
  `https://github.com/inoxiap/eficiencia-energetica-ee.git`
- Rama principal: `main`.
- Aplicacion activa: `ee_flutter/`.
- Version Flutter registrada: `1.1.2+5`.
- La raiz contiene una app Android nativa y una PWA antiguas. Son respaldo
  historico; no usarlas para implementar funciones nuevas sin solicitud expresa.

## Regla de trabajo

Al retomar:

1. Leer este archivo.
2. Ejecutar `git status --short --branch`.
3. Revisar el codigo y la documentacion relacionados con la solicitud.
4. Conservar cambios existentes que no pertenezcan a la tarea.
5. Implementar y probar en pasos verificables.
6. Antes de responder, agregar una entrada a la bitacora de este archivo si hubo
   cambios, despliegues, pruebas relevantes, decisiones o hallazgos.

Si este documento contradice al codigo o a Firebase, comprobar el estado real y
actualizar esta memoria. No asumir que un informe antiguo sigue vigente.

## Objetivo del producto

Aplicacion sencilla para operadores de una planta de procesamiento de aceite de
palma. Permite capturar datos de eficiencia energetica, calcular resultados,
guardar evidencia y dar seguimiento operativo desde Android y web.

La interfaz debe priorizar pocos pasos, textos claros, unidades visibles,
selectores faciles y confirmacion antes de guardar. Los operadores no deben
necesitar criterio tecnico avanzado para completar un levantamiento.

## Arquitectura actual

- Flutter/Dart: una base para Android y web/PWA.
- Firebase Authentication: sesion de operadores.
- Cloud Firestore: informacion estructurada.
- Cloudinary: fotografias y evidencias.
- FastAPI, Jinja2 y Plotly.js: dashboard administrador independiente en
  `ee_flutter/energy_dashboard/`.
- Estado Flutter: principalmente estado local de widgets y servicios/repositorios;
  no hay un framework global de estado.
- Configuracion Firebase Flutter:
  `ee_flutter/lib/firebase_options.dart`.
- Reglas e indices:
  `ee_flutter/firestore.rules` y `ee_flutter/firestore.indexes.json`.

## Produccion

- Proyecto Firebase: `eficiencia-energetica-ee`.
- Plan Firebase: Spark.
- Web/PWA:
  `https://eficiencia-energetica-ee.web.app`
- Firebase Hosting publica `ee_flutter/build/web`.
- El proveedor Firebase Authentication Email/Password fue habilitado y probado
  en produccion el 2026-07-16.
- El operador usa cedula y PIN en pantalla. Internamente la app deriva un correo
  tecnico y usa Firebase Email/Password. El PIN no se guarda en Firestore,
  SharedPreferences ni localStorage.
- El registro publico siempre crea rol `operator`. El rol `admin` debe asignarse
  desde un entorno administrativo confiable.
- El dashboard FastAPI aun no esta desplegado como servicio HTTPS. Su ejecucion
  conocida es local en `http://127.0.0.1:8080`.
- No trabajar con Firebase Emulator Suite salvo que Jeff lo solicite. Durante el
  desarrollo inicial Jeff decidio que las validaciones funcionales se realicen
  directamente sobre produccion porque aun no hay usuarios operativos reales.
  Los datos de prueba deben quedar claramente identificados.

## Proveedor de imagenes

El proveedor existente es Cloudinary y debe reutilizarse:

- Cloud name publico: `dovufh5wv`.
- Upload preset unsigned: `ee_evidencias_unsigned`.
- Servicio: `ee_flutter/lib/services/cloudinary_service.dart`.

No migrar imagenes ni cambiar el proveedor sin una razon tecnica documentada.
No almacenar secretos de Cloudinary en Git.

## Modulos funcionales

1. Dimensionamiento de trampas de vapor.
2. Reporte de tuberia desnuda con fotografia.
3. Reporte de fugas de vapor, aceite, agua y aire con fotografia.
4. Seguimiento de fugas y tuberias con estados `OT generada` y
   `Trabajo ejecutado`.
5. Ingreso horario de consumos de calderas.
6. Registro e inicio de sesion de operadores.
7. Levantamiento electrico de bombas.
8. Panel administrador legado dentro de Flutter.
9. Dashboard administrador independiente en Python/HTML.
10. Actualizacion semiautomatica Android mediante `app_config`.

## Colecciones Firestore conocidas

- `users`
- `steam_trap_sizing_reports`
- `bare_pipe_reports`
- `leak_reports`
- `boiler_consumption_readings`
- `pump_energy_surveys`
- `motor_reference_tables`
- `app_config`

Los registros nuevos deben conservar entradas originales, unidades, resultado,
usuario, timestamps de servidor, plataforma, version de app, version de esquema,
estado y trazabilidad. No usar cedula, nombre o PIN como ID publico.

## Catalogo de secciones

El catalogo comun usa identificadores estables y etiquetas:

- Refineria
- Confiteria y Galleteria
- Desodorizacion
- Fraccionamiento
- Manteca
- Aceites
- Hidrogenacion
- Jaboneria
- Recepcion
- DEX
- Servicios Industriales
- Margarina

La fuente de codigo esta en
`ee_flutter/lib/domain/section_catalog.dart`.

## Reglas funcionales importantes

- `Calcular` no guarda automaticamente. Primero muestra el resultado y luego
  solicita confirmacion para guardar.
- En trampas se conservan los caminos de condensado conocido e indirecto.
- Condensado directo se ingresa en L/min.
- Factor de seguridad de trampas: `1.2`.
- Tracing no solicita calculo indirecto y recomienda directamente la trampa
  configurada.
- No modificar formulas sin documentar el motivo y conservar resultados previos
  con pruebas.
- Consumos de agua, bunker y vapor se guardan actualmente en galones (`gal`).
- No sumar lecturas acumuladas; calcular deltas validados.
- Todas las lecturas nuevas se ingresan como lectura acumulada.
- Solo Alfa Laval debe solicitar vapor. Distral 900 y Cleaver Brooks lo
  mantienen deshabilitado.
- El modulo Ingresar consumos tiene dos pestanas inferiores: Consumos y
  Presiones.
- Las presiones de los distribuidores Cleaver y 900 se ingresan en PSI y se
  guardan en `steam_pressure_readings`.
- Bombas debe diferenciar kW de kWh y no afirmar sobredimensionamiento sin
  revision hidraulica.
- Fotografias de fugas y tuberia se suben antes de confirmar el documento; los
  fallos deben dejar un estado explicito y permitir reintento.
- `Trabajo ejecutado` solo se habilita despues de `OT generada`.

## Formulas y supuestos que deben conservarse

- Aceite o grasa: calor especifico aproximado `2.0 kJ/(kg C)`.
- Densidad aproximada de aceite de palma: `0.89 kg/L`.
- Condensado: densidad aproximada `1.0 kg/L` para convertir L/min a kg/h.
- Vapor: propiedades interpoladas desde tabla interna.
- Distribuidor principal de caldero: constante conservadora de 12% sobre agua
  consumida, comparada con perdida superficial.
- Distribuidor secundario: estimacion por diametro, presion y velocidad de
  referencia, con drenaje tipico de linea y comparacion superficial.
- Tuberia desnuda: conservar la formula y flujo existentes.

Detalle y fuentes:
`ee_flutter/docs/FORMULAS_Y_UNIDADES.md` y la documentacion tecnica existente.

## Autenticacion

- Implementacion:
  `ee_flutter/lib/services/operator_auth_service.dart`.
- Sesion:
  `ee_flutter/lib/services/operator_session.dart`.
- Firebase Auth Email/Password esta habilitado en produccion.
- La sesion persistente fue comprobada en web y Android.
- No guardar el PIN, ni siquiera en esta memoria.
- Un PIN de 4 a 6 digitos se acepta por decision de uso interno, aunque su
  seguridad es limitada.

## Pruebas y estado verificado

Ultima bateria amplia conocida:

- `flutter analyze`: aprobado.
- `flutter test`: 41 pruebas aprobadas el 2026-07-26.
- Reglas Firestore: 7 pruebas aprobadas en la bateria anterior; las reglas
  nuevas compilaron y se publicaron correctamente el 2026-07-24, pero no se
  repitio Emulator Suite por la decision de no trabajar con emuladores Firebase.
- Dashboard: 7 pruebas aprobadas.
- `flutter build apk --release`: aprobado el 2026-07-24, 52.7 MB.
- `flutter build web --release`: aprobado el 2026-07-24.
- `flutter build web`: aprobado el 2026-07-26.
- `flutter build apk --debug`: aprobado el 2026-07-26.
- Pixel 8 API 35: instalacion y revision visual aprobadas.
- Registro, ingreso y persistencia con Firebase Auth real: aprobados.
- Carga de fuga real de prueba desde Pixel 8: aprobada.
- La fuga de prueba aparecio en Seguimiento con fotografia, fecha, operador y
  estados de OT.

No repetir estos resultados como actuales despues de cambiar codigo sin volver a
ejecutar las pruebas correspondientes.

## Emulador Android

- AVD usado: `EE_Pixel_8_API_35_x64`.
- Dispositivo ADB habitual: `emulator-5554`.
- Se habilito el teclado fisico en:
  `C:\Users\windo\.android\avd\EE_Pixel_8_API_35_x64.avd\config.ini`
  con `hw.keyboard = yes`.
- Android tiene `show_ime_with_hard_keyboard = 1`.
- Se comprobo escritura desde el teclado de Windows.
- Si el emulador pierde Internet, un arranque limpio puede ser necesario.

## Comandos frecuentes

Desde `ee_flutter/`:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --release
flutter build web --release
firebase deploy --only firestore:rules,firestore:indexes,hosting
```

Dashboard:

```powershell
cd energy_dashboard
.venv\Scripts\python.exe -m pytest -q
.venv\Scripts\uvicorn.exe app.main:app --reload --port 8080
```

Reglas con Emulator Suite, solo cuando corresponda:

```powershell
firebase emulators:exec --only firestore "npm --prefix functions run test:rules"
```

## Documentos de referencia

- `README.md`
- `ee_flutter/README.md`
- `ee_flutter/IMPLEMENTATION_REPORT.md`
- `ee_flutter/docs/AUDITORIA_TECNICA.md`
- `ee_flutter/docs/PLAN_IMPLEMENTACION.md`
- `ee_flutter/docs/MODELO_DATOS.md`
- `ee_flutter/docs/DECISIONES_TECNICAS.md`
- `ee_flutter/docs/FORMULAS_Y_UNIDADES.md`
- `ee_flutter/docs/SEGURIDAD_Y_ROLES.md`

Nota: `IMPLEMENTATION_REPORT.md` fue escrito antes de habilitar Email/Password.
Su pendiente sobre `PASSWORD_LOGIN_DISABLED` quedo resuelto el 2026-07-16.

## Pendientes y riesgos

- Dashboard FastAPI sin despliegue HTTPS.
- Confirmar existencia e identificador de Caldera 1100.
- Revisar con Operaciones los rangos de advertencia si cambian medidores,
  combustible o regimen de trabajo; la referencia historica inicial ya fue
  implementada.
- Revisar y, con respaldo, eliminar cualquier `operatorPin` historico remoto.
- Mantener restricciones de formato y tamano en el preset Cloudinary unsigned.
- Registros historicos pueden carecer de UID o timestamps de servidor.
- Sincronizacion Excel: falta crear el repositorio privado de transporte,
  autorizar GitHub en Power Automate y ejecutar la prueba integral sobre el
  maestro cerrado en Excel de escritorio.
- El arbol Git contiene numerosos cambios aun no confirmados; no limpiarlo ni
  descartarlo sin instruccion expresa de Jeff.

## Bitacora

### 2026-07-15 - Plataforma profesional inicial

- Se implementaron autenticacion Firebase simplificada para Spark, usuarios,
  fugas, seguimiento, bombas, dashboard, reglas, indices y auditoria.
- Se conservaron formulas existentes, Cloudinary y panel administrador legado.
- Se genero la version `1.1.0+3`.
- Referencia detallada: `ee_flutter/IMPLEMENTATION_REPORT.md`.

### 2026-07-16 - Produccion, autenticacion y prueba integral

- Se habilito Email/Password en Firebase Authentication.
- Se corrigio el registro/inicio de sesion web y la invalidacion de cache de
  Firebase Hosting.
- Se desplego la web en
  `https://eficiencia-energetica-ee.web.app`.
- Se verifico registro, ingreso y sesion persistente con Firebase real.
- Se compilo e instalo el APK release en Pixel 8.
- Se creo una fuga de prueba de vapor desde el emulador y se comprobo su
  aparicion en Seguimiento de reportes con miniatura y controles de OT.
- Se corrigio la configuracion de teclado del AVD para aceptar teclas de Windows.

### 2026-07-22 - Memoria persistente

- Se creo este `PROJECT_MEMORY.md`.
- Se agrego `AGENTS.md` para obligar su lectura al iniciar o retomar tareas y su
  actualizacion despues de cambios.
- Se agrego un archivo de enlace en la carpeta de arranque vacia
  `C:\Users\windo\Documents\App Eficiencia Energetica` para que futuras sesiones
  encuentren el repositorio canonico.
- No se modifico codigo funcional ni se realizo despliegue.

### 2026-07-24 - Consumos acumulados y presiones

- Solicitud: dividir Ingresar consumos en las pestanas Consumos y Presiones.
- Resultado: Consumos crea solo lecturas acumuladas; Alfa Laval solicita vapor
  y Distral 900/Cleaver Brooks lo deshabilitan.
- Resultado: se agrego la captura de cinco presiones del distribuidor Cleaver y
  nueve del distribuidor 900, todas en PSI, con revision y confirmacion previa.
- Datos: nueva coleccion `steam_pressure_readings` con auditoria de usuario,
  timestamps de servidor, plataforma, version de app y version de esquema.
- Compatibilidad: los registros historicos `interval_consumption` siguen
  leyendose, pero ya no pueden crearse desde la interfaz ni por reglas.
- Archivos principales: `ee_flutter/lib/main.dart`,
  `ee_flutter/lib/screens/pressure_entry_tab.dart`,
  `ee_flutter/lib/domain/steam_pressure_reading.dart`,
  `ee_flutter/lib/services/pressure_reading_store.dart` y
  `ee_flutter/firestore.rules`.
- Pruebas/builds: `flutter analyze` sin hallazgos, 38 pruebas Flutter aprobadas,
  web release y APK release de 52.7 MB compilados.
- Despliegue: Hosting y reglas Firestore publicados correctamente en produccion
  en `https://eficiencia-energetica-ee.web.app`.
- Verificacion web: URL y titulo correctos, sin errores ni advertencias en la
  consola del navegador.

### 2026-07-24 - Evaluacion de exportacion a Excel

- Firestore debe mantenerse como fuente oficial; no usar GitHub como base de
  datos ni publicar alli informacion operativa.
- La alternativa local con Python y Programador de tareas de Windows fue
  descartada por Jeff porque el proceso debe continuar con su laptop apagada.
- El libro debe usar `documentId` como clave, evitar duplicados y separar
  Consumos, Presiones, Trampas, Tuberia, Fugas y Bombas en hojas.
- El dashboard ya tiene exportacion CSV como base, pero actualmente no incluye
  `steam_pressure_readings` ni columnas amigables por modulo.
- Ruta recomendada totalmente en nube: GitHub Actions consulta los cambios de
  Firestore, actualiza el XLSX y lo escribe directamente en SharePoint/OneDrive
  mediante Microsoft Graph. Requiere secretos de GitHub, credencial Firebase de
  solo lectura y una aplicacion Microsoft Entra limitada al sitio destino.
- Power Automate puede observar el archivo en SharePoint/OneDrive para enviar
  avisos o ejecutar procesos posteriores, pero no es necesario para sincronizar
  Firestore con Excel.
- Power Automate directo contra Firestore requeriria REST/conector personalizado
  y probablemente licencia Premium; no es la primera opcion.
- Estado: investigacion y recomendacion solamente; no implementado. Antes de
  avanzar, confirmar disponibilidad de OneDrive/SharePoint corporativo y acceso
  de un administrador Microsoft 365 para autorizar la aplicacion Entra.

### 2026-07-24 - Revision del aviso de actualizaciones

- La app ya consulta al iniciar `app_config/mobile_app` y compara
  `latestBuildNumber` con el build instalado.
- Produccion conserva `latestVersion: 1.0.1` y `latestBuildNumber: 2`, mientras
  el codigo actual usa `1.1.0+3`; por eso no aparece ningun aviso actualmente.
- El documento permite mensaje, URL, actualizacion opcional o forzada y build
  minimo soportado.
- El campo remoto `channel: android` existe, pero el cliente actual no lo
  evalua. Web y Android usan el mismo `updateUrl`.
- Antes de la proxima version conviene separar el comportamiento: Android abre
  la descarga del APK y web muestra un boton para recargar la version publicada.
- Cada APK de actualizacion debe conservar `applicationId` y la misma firma del
  APK instalado; el build nuevo debe ser siempre mayor.
- Estado: revision solamente; no se modifico codigo ni configuracion remota.

### 2026-07-24 - Integracion de consumos de calderas con Excel

- Se audito sin modificar
  `C:\Users\windo\OneDrive - Grupo Danec\MEJORAS\1. SEGUIMIENTO DE LA ENERGÍA\REPORTE DE CALDERAS 2018.xlsx`.
- `Regist_inform` usa A:P: Fecha, Dia, Año, Mes, Presion, Semana, Caldera,
  paro, horas optimas, tiempo real, eficiencia, alcance, bunker, agua,
  Ton/Agua y galones/m3.
- Etiquetas confirmadas en el maestro: `CalAlfa`, `CalCleaver` y
  `900Distral`. El maestro conserva formulas propias y no fue alterado.
- Se creo
  `outputs/energia-calderas-20260724/DATOS_CALDERAS_APP_AUXILIAR.xlsx`
  con hojas Control, Datos_Firestore, Intervalos, Consumo_Horario y
  Resumen_Diario.
- Se implemento `ee_flutter/integrations/boiler_excel_sync/`: descarga
  `boiler_consumption_readings`, conserva todas las revisiones, calcula con la
  revision efectiva, rechaza deltas no positivos, distribuye intervalos
  irregulares por solapamiento horario y genera el resumen diario A:P.
- Solo se agregan lecturas `cumulative_meter` con unidades `gal`. Las unidades
  y valores originales permanecen visibles en Datos_Firestore.
- La presion diaria se calcula provisionalmente como promedio de lecturas del
  dia y caldera. Paro=0, horas optimas=24, tiempo real=24, eficiencia=1 y
  alcance=0.98 quedan documentados como supuestos pendientes de Operaciones.
- Se preparo `.github/workflows/sync-boiler-excel.yml` para ejecución horaria
  con GitHub Actions y carga a OneDrive/SharePoint mediante Microsoft Graph.
  No esta operativo hasta subir el workflow y configurar secretos de Firebase
  de solo lectura y Microsoft Entra; ningun secreto se guardo en Git.
- App: se agrego `Presion de caldera (PSI)` obligatoria a lecturas nuevas,
  `schemaVersion: 2` y compatibilidad con documentos historicos de esquema 1.
- Version generada: `1.1.1+4`. Web y reglas Firestore desplegadas en
  `https://eficiencia-energetica-ee.web.app`; APK release de 55.285.365 bytes.
- Pruebas: `flutter analyze`, 38 pruebas Flutter, 9 pruebas de reglas y 5
  pruebas del exportador aprobadas; web y APK release compilados.
- Pendiente externo: asignar secretos de GitHub y autorizar una aplicacion
  Microsoft Entra con permisos minimos sobre el archivo de destino.

### 2026-07-24 - Arquitectura Excel sin Power Automate Premium

- Jeff confirmo usar la misma cuenta Microsoft
  `Asistente Proyectos Mantenimiento` para Excel Online y Power Automate.
- El flujo con disparador HTTP se creo, verifico y elimino al confirmar que
  requiere licencia Power Automate Premium.
- Se descarto Microsoft Graph directo para evitar una aplicacion Entra y
  permisos administrativos adicionales.
- La solucion elegida usa un GitHub Action alojado en el repositorio privado,
  un issue del mismo repositorio, el conector estandar GitHub de Power Automate
  y `Run script` de Excel Online (Business). Firestore sigue siendo la fuente
  oficial.
- El repositorio de codigo `inoxiap/eficiencia-energetica-ee` es publico. Nunca
  publicar alli payloads operativos; crear un repositorio privado separado.
- El workflow privado usa su `GITHUB_TOKEN` automatico con `issues: write`; no
  requiere un token personal. El unico secreto previsto es la cuenta Firebase
  de solo lectura.
- `exporter.py` publica solamente el dia local en curso como payload incremental
  y rechaza cuerpos mayores al limite configurado. El Office Script acumula el
  historial por claves estables.
- Se creo en Excel Online el script
  `EE - Sincronizar consumos de calderas`. Administra `App_Datos_Firestore`,
  `App_Intervalos`, `App_Consumo_Horario`, `App_Resumen_Diario`,
  `App_Mapeo_Regist`, `App_Control` y las filas controladas de `Regist_inform`.
- Prueba de idempotencia aprobada en `Book.xlsx`: la segunda ejecucion produjo
  0 filas nuevas, 1 dato crudo actualizado y 1 fila de `Regist_inform`
  actualizada, sin duplicados.
- Pruebas del exportador: 9 aprobadas. TypeScript del Office Script transpilo y
  el script se ejecuto correctamente en Excel Online.
- Respaldo del maestro creado antes de la primera escritura:
  `Respaldos App EE\REPORTE DE CALDERAS 2018 - respaldo antes de Power Automate 20260724-184542.xlsx`.
- El maestro estaba bloqueado por Excel de escritorio. Para la prueba integral,
  Jeff debe cerrarlo primero.
- Se creo `inoxiap/eficiencia-energetica-datos` como repositorio privado y su
  issue `#1` como buzon.
- Power Automate quedo conectado a `inoxiap`, configurado con el issue `#1`,
  el archivo maestro y el Office Script, y se guardo correctamente sin
  conectores Premium.
- Se creo `EE Excel Reader` con rol `Lector de Cloud Datastore`; su clave se
  guardo solamente como el secreto `FIREBASE_SERVICE_ACCOUNT_JSON` del
  repositorio privado y el archivo descargado se elimino de la computadora.
- El exportador se publico en `main` con commit `ef1c368`. El workflow privado
  se instalo y su primera ejecucion manual termino correctamente en 32 segundos.
- Se actualizo `actions/setup-python` de v5 a v6 para eliminar la advertencia
  de Node.js 20. La segunda ejecucion termino correctamente en 24 segundos y
  sin advertencias.
- El payload del issue se valido como esquema 1, modo incremental y sin filas
  para el dia actual, porque no existian lecturas nuevas.
- La prueba integral de Power Automate termino `Test succeeded` en 9 segundos.
  El maestro creo las seis hojas `App_*`; `App_Control` quedo en
  `Completado`, con 0 filas nuevas y 0 conflictos. `Regist_inform` no recibio
  filas porque el payload estaba vacio.
- Pendiente operativo: validar de nuevo cuando exista al menos un par de
  lecturas acumuladas consecutivas de una caldera para comprobar deltas y
  resumen diario con datos reales.

### 2026-07-24 - Recuperacion de consumos pendientes y prueba Excel real

- Solicitud: investigar por que una lectura ingresada desde el telefono no
  aparecia en el Excel despues de ejecutar Power Automate.
- Hallazgo: la lectura reportada por Jeff no llego a Firestore; quedo
  `pending_sync` en el almacenamiento local del telefono. La transaccion de
  creacion intentaba leer primero un documento inexistente y las reglas
  rechazaban esa lectura para operadores con `PERMISSION_DENIED`.
- Hallazgo adicional: `app_config/mobile_app` seguia anunciando
  `1.0.1+2`, por lo que los telefonos no recibian aviso del APK nuevo.
- Correccion: `FirestoreConsumptionStore` crea directamente el documento;
  las reglas existentes siguen impidiendo actualizaciones y duplicados. Las
  consultas de operador ahora filtran por `createdByUid`.
- Recuperacion: `HybridConsumptionStore` reintenta lecturas `pending_sync`
  al abrir Ingresar consumos. Los registros locales heredados conservan
  esquema 1 cuando no tienen presion y usan las unidades de galones ya
  confirmadas para las calderas.
- Firebase: se desplego el indice
  `createdByUid ASC + recordedAt DESC`. El emulador Pixel 8 API 35 quedo sin
  errores de permisos ni de indice contra produccion.
- Prueba integral: un registro pendiente del emulador se recupero en
  Firestore, GitHub Actions publico una fila y Power Automate termino
  correctamente. El Office Script creo 1 fila cruda, 1 intervalo, 1 resumen
  diario y 1 fila controlada de `Regist_inform`, sin conflictos.
- Nota de calculo: al ser la primera lectura acumulada de la caldera, el
  consumo diario queda en cero hasta disponer de una segunda lectura para
  calcular el delta.
- Version: `1.1.2+5`. APK publicado en GitHub, aviso remoto actualizado y
  web desplegada en `https://eficiencia-energetica-ee.web.app`.
- Verificacion: 39 pruebas Flutter aprobadas, `flutter analyze` sin
  hallazgos, APK y web release compilados; enlace APK con respuesta HTTP 200.
- Pendiente operativo: instalar el build 5 en el telefono de Jeff, abrir
  Ingresar consumos para reenviar su lectura local y ejecutar la cadena
  GitHub/Power Automate. Validar un segundo registro de la misma caldera para
  comprobar un delta de consumo distinto de cero.

### 2026-07-26 - Banco comparativo de instrumentos industriales

- Solicitud: reemplazar el primer borrador de entradas genericas por opciones
  con apariencia de manometro o instrumento de medicion industrial.
- Resultado: `Tablero de ingreso` se rehizo como `Banco de instrumentos`, con
  cuatro alternativas interactivas conectadas a una misma lectura: manometro
  analogico, encoder rotativo con pantalla LED, dial circular y transmisor
  lineal. Incluye selector de galones, PSI, amperios y temperatura, mas ajuste
  fino mediante botones.
- Dependencias MIT incorporadas: `geekyants_flutter_gauges`,
  `flutter_dial_knob`, `sleek_circular_slider` y `segment_display`.
- Decision: se descarto Syncfusion para este prototipo por su licencia
  Community/comercial y `gauge_kit` por ser una publicacion demasiado reciente.
- Hallazgo visual: `RadialTrack.steps` representa el intervalo numerico y no la
  cantidad de divisiones. Se corrigio para mostrar cinco divisiones legibles y
  evitar miles de marcas superpuestas.
- Archivos principales:
  `ee_flutter/lib/screens/input_controls_playground_screen.dart`,
  `ee_flutter/lib/main.dart`, `ee_flutter/pubspec.yaml`,
  `ee_flutter/pubspec.lock` y
  `ee_flutter/test/input_controls_playground_test.dart`.
- Pruebas/builds: analisis focalizado sin hallazgos, 40 pruebas Flutter
  aprobadas, `flutter build web` aprobado y `git diff --check` sin errores.
- Revision visual: aprobada en 390x844. Se verificaron la escala del manometro,
  el cambio de galones a PSI, el ajuste fino de 0,1 PSI y la presentacion de los
  cuatro instrumentos.
- Despliegue: no se publico en Firebase. La vista local temporal sigue en
  `http://127.0.0.1:4174`.
- Pendiente: Jeff debe escoger el instrumento o combinacion que resulte mas
  sencilla para operadores antes de aplicarla a los formularios productivos.

### 2026-07-26 - Inicio y levantamiento de bombas simplificados

- Solicitud: integrar el acceso de usuario con el encabezado, mostrar el nombre
  de la sesion, reorganizar modulos y reducir el criterio tecnico requerido en
  el levantamiento electrico de bombas.
- Inicio: el encabezado y el acceso de usuario usan una proporcion aproximada
  4:1; el nombre de la sesion se actualiza al volver del acceso. `Ingresar
  consumos` es el primer modulo y `Seguimiento de reportes` el penultimo.
- Terminologia: todos los textos visibles de la app cambiaron de `operador` a
  `usuario`; los identificadores tecnicos y el rol interno `operator` se
  conservan por compatibilidad.
- Bombas: el tipo de levantamiento aparece primero. Seccion y potencia nominal
  usan ruedas con el estilo comun. La corriente avanza cada 2 A y las horas de
  trabajo diario se seleccionan entre 1 y 24.
- Bombas: se elimino la interfaz de mediciones avanzadas y el panel hidraulico
  `Operacion`. La tension nominal es la fuente predeterminada; la tension
  medida queda dentro de un bloque puntual y se registra `voltageSource`.
- Relacion: mejora y verificacion consultan las lineas base de Firestore,
  permiten escoger seccion, equipo y bomba, y reutilizan `assetId` junto con
  `baselineSurveyId`. Los IDs tecnicos dejaron de solicitarse manualmente.
- Seguridad: `pump_energy_surveys` permite lectura a usuarios autenticados para
  que las lineas base puedan reutilizarse entre turnos, sin habilitar edicion ni
  eliminacion.
- Archivos principales: `ee_flutter/lib/main.dart`,
  `ee_flutter/lib/screens/pump_survey_screen.dart`,
  `ee_flutter/lib/domain/pump_energy.dart`,
  `ee_flutter/lib/services/pump_survey_store.dart`,
  `ee_flutter/firestore.rules` y pruebas/documentacion asociadas.
- Pruebas/builds: `flutter analyze` sin hallazgos, 41 pruebas Flutter aprobadas,
  web compilada y APK debug compilado. Revision visual aprobada en 390x844 para
  inicio, acceso de usuario, linea base y datos electricos.
- Despliegue: no se publico Hosting ni la regla nueva mientras Jeff revisa el
  prototipo local en `http://127.0.0.1:4174`.
- Pendiente: despues de la aprobacion visual, desplegar Hosting y reglas para
  habilitar la consulta compartida de lineas base en produccion.

### 2026-07-27 - Navegacion inferior, presion y odometro digital

- Solicitud: sustituir `Volver a EE` en todos los modulos por una barra inferior
  con `Casa`, integrar la presion junto a la caldera y probar un ingreso de diez
  digitos similar a un contador industrial.
- Navegacion: acceso de usuario, trampas, tuberia desnuda, fugas, bombas, banco
  de instrumentos, consumos, seguimiento y administrador ya usan barra
  inferior. Las pantallas con pestañas conservan sus destinos y agregan Casa.
- Consumos: caldera y presion comparten una fila con proporcion 3:1. La rueda
  trabaja de 0 a 200 PSI en pasos de 1 o de 0,0 a 13,8 bar en pasos de 0,1,
  conservando PSI como unidad persistida. Valores iniciales: Alfa Laval 10,4
  bar (151 PSI); Distral 900 y Cleaver Brooks 8,0 bar (116 PSI).
- Banco: se agrego un odometro digital de diez ruedas independientes. Al abrir,
  consulta el almacen hibrido y carga la lectura acumulada de bunker mas
  reciente de la caldera seleccionada; sin historial muestra cero.
- Archivos principales: `ee_flutter/lib/main.dart`,
  `ee_flutter/lib/screens/input_controls_playground_screen.dart`,
  `ee_flutter/lib/widgets/home_navigation_bar.dart` y pruebas de widgets.
- Pruebas/builds: `flutter analyze` sin hallazgos, 41 pruebas Flutter
  aprobadas, web compilada y APK debug compilado.
- Revision visual: aprobada en 390x844. Se comprobaron 151 PSI para Alfa, 116
  PSI y 8,0 bar para Cleaver, regreso con Casa, carga real de
  `0004564621 gal` y modificacion independiente de una rueda. Sin errores de
  consola ni desbordamientos.
- Despliegue: no se publico en Firebase. La compilacion local esta disponible
  en `http://127.0.0.1:4174/`.
- Pendiente: Jeff debe validar el odometro antes de reutilizarlo en los campos
  productivos de bunker, agua o vapor.

### 2026-07-27 - Odometros productivos, conversion Alfa y rangos historicos

- Solicitud: aplicar el odometro de diez digitos al ingreso de consumos,
  intensificar el verde, ampliar la lectura inferior, convertir las lecturas
  Alfa Laval y analizar el historico para prevenir errores de digitacion.
- Alfa Laval: bunker se ingresa en litros y se normaliza como `L / 3.79` a
  galones; agua se ingresa en unidades del contador de 10 litros y se normaliza
  como `unidad x 2.64` a galones; vapor permanece en galones. Firestore conserva
  valor original, unidad, factores y valor normalizado con esquema 3.
- Odometros: bunker, agua y vapor usan diez ruedas independientes, cargan la
  lectura anterior de la caldera y conservan el valor guardado despues de una
  sincronizacion correcta. El verde paso a `#00ff66` y la lectura inferior a
  18 px.
- Seguridad: se analizo `Regist_inform` hasta el 2026-07-23. Los limites de
  advertencia corresponden al percentil 99 historico por hora mas 25 %:
  Alfa 380/6600, Cleaver 415/5750 y Distral 345/4700 gal/h para bunker/agua.
  La app advierte y exige una segunda confirmacion, pero permite registrar una
  condicion real extraordinaria.
- Excel: `App_Resumen_Diario` y `App_Consumo_Horario` reconciliaron exactamente.
  `Regist_inform` estaba atrasada porque `App_Mapeo_Regist` no contenia la fila
  administrada y el Office Script la marcaba como conflicto historico. Se
  preparo una recuperacion de mapeo para filas desde el 2026-07-24, sin tocar
  filas historicas anteriores. El cambio aun no reemplaza el Office Script
  activo de Power Automate.
- Archivos principales: `ee_flutter/lib/domain/boiler_consumption.dart`,
  `ee_flutter/lib/main.dart`,
  `ee_flutter/lib/screens/input_controls_playground_screen.dart`,
  `ee_flutter/integrations/boiler_excel_sync/office_script.ts` y pruebas/docs.
- Pruebas/builds: `flutter analyze` sin hallazgos, 45 pruebas Flutter y 9 del
  exportador aprobadas; Office Script transpilo sin errores; web y APK debug
  compilaron. Revision visual aprobada en 390x844, sin errores de consola,
  desbordamientos ni escrituras de prueba.
- Despliegue: no se publico Firebase Hosting, APK ni Office Script. La web local
  compilada permanece en `http://127.0.0.1:4174/`.
- Pendiente: con autorizacion de Jeff, copiar el Office Script corregido al
  flujo productivo y ejecutar Power Automate para reconciliar `Regist_inform`.

### 2026-07-27 - Diagnostico de sincronizacion y limpieza de demos

- Solicitud: investigar el fallo del workflow privado de consumos, comprobar
  los registros pendientes de Pablo Loachamin y eliminar los consumos demo de
  calderas en Firebase de produccion.
- Hallazgo: la ejecucion privada `#36` recupero correctamente Firestore, pero
  fallo al publicar el issue porque el payload tenia 85.275 caracteres y el
  limite seguro configurado era 60.000.
- Recuperacion: Firestore contiene 26 lecturas reales de Pablo con estado
  `synced`, registradas entre el 24 y el 27 de julio y creadas en la nube en un
  lote el 27 de julio. No fueron eliminadas ni modificadas.
- Causa adicional: existian 4.392 documentos demo en
  `boiler_consumption_readings`, con IDs que comenzaban por
  `demo_consumption_`. El exportador horario recorre la coleccion completa y
  estos documentos contribuyeron a agotar la cuota diaria de lecturas del plan
  Spark.
- Limpieza: se eliminaron en produccion los 4.392 IDs demo por lotes
  deterministas. Firestore confirmo la finalizacion de todas las operaciones de
  borrado. La lectura de comprobacion inmediata no pudo ejecutarse porque la
  cuota diaria ya estaba agotada.
- Codigo y despliegue: no se modifico codigo, el workflow privado ni el Office
  Script productivo.
- Pendiente: modificar el transporte para publicar payloads por bloques o por
  fecha y ejecutar la recuperacion de las 26 lecturas en Excel. Tambien conviene
  evitar que el exportador lea toda la coleccion en cada ejecucion.

### 2026-07-27 - Analisis de cuotas Firestore y transporte GitHub

- El filtro incremental actual se aplica despues de ejecutar
  `order_by("recordedAt").stream()`, por lo que cada workflow lee la coleccion
  completa aunque el issue reciba solo registros recientes.
- Con tres calderas y 72 lecturas diarias, el escaneo completo horario superaria
  por si solo las 50.000 lecturas diarias del plan Spark aproximadamente al
  cumplir un mes de historial.
- El payload repite la misma informacion en datos crudos, intervalos, filas
  horarias y resumen diario. En una muestra de 26 lecturas, las filas horarias
  ocuparon 18.958 de 31.480 caracteres; los huecos largos multiplican esas filas
  y explican el payload real de 85.275 caracteres.
- Recomendacion: conservar Firestore como fuente oficial y Excel como reporte;
  no eliminar datos reales de Firestore despues de exportarlos. GitHub debe
  contener solamente un lote pendiente y un cursor de confirmacion.
- Diseno propuesto: consulta incremental por `createdAt` de servidor mas ID,
  contexto limitado por caldera y fecha, lotes menores a 45.000 caracteres,
  confirmacion de Power Automate mediante `Update an Issue` y limpieza del
  cuerpo despues de una escritura exitosa en Excel.
- Optimizar despues la app: reemplazar lecturas remotas de hasta 10.000
  documentos por consultas de ultima lectura, intervalo objetivo y paginas
  pequenas para administracion.
- Estado: analisis solamente; no se modificaron el exportador, workflow,
  Power Automate, Firestore ni Office Script productivos.

### 2026-07-27 - Recuperacion acotada de 26 lecturas

- Solicitud: recuperar en el Excel maestro las 26 lecturas reales de Pablo
  Loachamin que permanecen seguras en Firestore.
- Exportador: la consulta incremental ahora se ejecuta en Firestore por
  `createdAt`; se agrego recuperacion manual por fecha local y contexto minimo
  anterior/posterior por caldera. Los contextos solo intervienen en los
  calculos y no se duplican en la tabla de datos crudos.
- Transporte: el workflow privado acepta `payload_date` para procesar un solo
  dia. El payload sintetico de 72 lecturas quedo en 52.091 caracteres, debajo
  del limite de 60.000.
- Excel: se reemplazo y guardo en produccion el Office Script
  `EE - Sincronizar consumos de calderas`. Puede recuperar el mapeo de filas
  administradas desde el 2026-07-24 y mantiene protegida la historia anterior.
- Despliegues: repositorio publico `main` en `a96f566`; repositorio privado de
  datos `main` en `b909335`.
- Pruebas: 10 pruebas unitarias del exportador aprobadas, `py_compile` aprobado
  y `git diff --check` sin errores.
- Ejecucion real: se lanzo la recuperacion del 2026-07-24 en GitHub Actions,
  ejecucion `30293742254`. El nuevo flujo fue utilizado, pero Firestore respondio
  `429 Quota exceeded`; no se publicaron datos parciales ni se altero Excel.
- Continuacion: se creo el heartbeat
  `recuperar-26-lecturas-de-calderas` para las 02:10 de America/Guayaquil.
  Debe procesar secuencialmente 2026-07-24, 25, 26 y 27, ejecutar Power Automate
  entre fechas, comprobar las 26 filas sin duplicados y eliminar el heartbeat
  al concluir.

### 2026-07-27 - Flujo eficiente y publicacion 1.2.0

- Solicitud: aplicar el manejo eficiente de datos dentro de los limites
  gratuitos y publicar la ultima version para Android y web.
- Exportador: `schemaVersion` subio a 2. Antes de consultar Firestore revisa el
  estado del issue privado; si existe un lote `ready`, termina sin volver a
  leer ni sobrescribir datos. Tras una confirmacion consulta solamente
  `createdAt > cursor` en el servidor. Los payloads grandes se dividen
  automaticamente por fecha y conservan `remainingDates` hasta completar la
  entrega.
- Confirmacion: el Office Script devuelve un payload `acknowledged` despues de
  escribir Excel. El flujo productivo
  `EE - Actualizar Excel maestro desde GitHub` actualiza el issue 1 con ese
  resultado. La prueba manual real del flujo finalizo correctamente en 16
  segundos y el issue quedo confirmado con esquema 2.
- App: las consultas remotas generales de consumos se limitaron a 250
  documentos recientes. La cache local conserva todos los registros
  `pending_sync` y hasta 500 registros sincronizados, sin descartar pendientes.
- Cuotas: se conserva la ejecucion horaria. En estado confirmado no consulta
  Firestore; cuando hay datos usa una consulta incremental. El consumo
  estimado de GitHub Actions permanece por debajo de los 2.000 minutos
  mensuales incluidos y Power Automate queda muy por debajo de su perfil bajo.
  Firestore sigue siendo la fuente oficial y no se eliminan registros reales
  despues de exportarlos.
- Version: Flutter `1.2.0+6`, commit fuente `a668946`. El APK release pesa
  55.915.778 bytes, fue validado con `apksigner`, instalado con exito en
  `EE_Pixel_8_API_35_x64` y abierto sin problemas.
- Publicacion Android:
  `https://github.com/inoxiap/eficiencia-energetica-ee/releases/tag/v1.2.0`.
  Descarga directa:
  `https://github.com/inoxiap/eficiencia-energetica-ee/releases/download/v1.2.0/eficiencia-energetica-ee-1.2.0-build6.apk`.
- Publicacion web: `https://eficiencia-energetica-ee.web.app`. Hosting,
  reglas e indices de Firestore fueron desplegados. La ruta raiz y los archivos
  de arranque usan `no-cache` para mostrar versiones nuevas de inmediato sin
  desactivar la cache de todos los recursos estaticos.
- Actualizaciones: `app_config/mobile_app` quedo habilitado con build 6, URL
  Android al APK y URL web al Hosting. Las instalaciones Android anteriores
  mostraran confirmacion de actualizacion; las versiones web anteriores
  ofreceran recargar. La actualizacion no es forzada.
- Pruebas/builds: `flutter analyze` sin hallazgos; 45 pruebas Flutter, 14 del
  exportador, 7 del dashboard y 5 de Functions aprobadas; Functions compilo;
  `flutter build web --release` y `flutter build apk --release` finalizaron
  correctamente. APK y web respondieron HTTP 200 y la web fue comprobada
  visualmente en produccion.
- Pendiente: la recuperacion de las 26 lecturas de Pablo continua programada
  para despues del reinicio de cuota de Firestore. No eliminar el heartbeat
  `recuperar-26-lecturas-de-calderas` hasta comprobar los datos en Excel.

### 2026-07-27 - Confirmacion del bloqueo de las 26 lecturas

- Consulta: Jeff confirmo que las 26 lecturas de Pablo todavia no aparecen en
  el Excel maestro.
- Diagnostico: el workflow privado `#38`, ejecutado a las 13:46 de Ecuador,
  aprobo sus pruebas pero fallo al consultar Firestore con
  `429 RESOURCE_EXHAUSTED: Quota exceeded`. El issue privado permanece en
  esquema 2, modo `acknowledgement`, estado `acknowledged` y cero filas; por
  eso Power Automate no tenia un lote nuevo que escribir.
- Recuperacion: el heartbeat `recuperar-26-lecturas-de-calderas` esta activo a
  las 02:10 de America/Guayaquil. Su primera oportunidad util sera el
  2026-07-28, despues del reinicio aproximado de cuota a las 02:00.
- Datos: no hay indicios de perdida ni de rechazo de Excel. Las 26 lecturas
  permanecen pendientes de ser leidas desde Firestore y transportadas por
  fechas.

### 2026-07-28 - Recuperacion completa de lecturas retenidas

- Solicitud: recuperar las 26 lecturas identificadas inicialmente y comprobar
  si se acumularon otras durante el agotamiento de cuota de Firestore.
- Causa corregida: despues del reinicio de cuota, GitHub Actions revelo un
  segundo bloqueo: faltaba el indice compuesto ascendente
  `boilerId ASC + recordedAt ASC` requerido por el exportador. Se agrego a
  `ee_flutter/firestore.indexes.json`, se desplego en produccion y Firestore
  confirmo el estado `READY`.
- Auditoria final: se localizaron 63 lecturas reales desde el 2026-07-24, no
  solamente 26. El desglose por fecha local fue 6 el 24, 7 el 25, 16 el 26,
  28 el 27 y 6 el 28. Por usuario fueron 33 de Pablo Loachamin y 30 de los
  demas usuarios. Todas conservaron el estado `synced`.
- Recuperacion: se reprocesaron de forma idempotente los cinco dias mediante
  GitHub Actions y Power Automate. Las ejecuciones exitosas fueron
  `30361657978`, `30361904120`, `30362057292`, `30362196209` y
  `30362327230`, con lotes de 6, 7, 16, 28 y 6 filas respectivamente.
- Verificacion del transporte: despues de cada fecha, Power Automate actualizo
  el issue privado a `acknowledged`. El lote final quedo confirmado para
  2026-07-28 con 6 filas y sin fechas restantes.
- Verificacion del Excel maestro: `App_Control` mostro `Completado` para el
  ultimo lote, 6 filas crudas nuevas, 0 actualizadas, 0 conflictos historicos
  y 0 filas omitidas. Firestore se volvio a consultar al terminar y el conteo
  permanecio estable en 63, por lo que no quedaron lecturas adicionales sin
  procesar dentro del periodo afectado.
- Datos: no se borraron registros reales de Firestore. El reproceso usa el ID
  del documento y no duplica filas ya existentes en Excel.
- Automatizacion: se elimino el heartbeat temporal
  `recuperar-26-lecturas-de-calderas`, ya que la recuperacion y comprobacion
  concluyeron.

### 2026-07-28 - Orden cronologico del Excel maestro

- Solicitud: ordenar localmente la informacion recuperada sin modificar la
  logica de Firestore, GitHub, Power Automate ni las cargas posteriores.
- Archivo actualizado:
  `C:\Users\windo\OneDrive - Grupo Danec\MEJORAS\1. SEGUIMIENTO DE LA ENERGÍA\REPORTE DE CALDERAS 2018.xlsx`.
- Respaldo previo:
  `C:\Users\windo\OneDrive - Grupo Danec\MEJORAS\1. SEGUIMIENTO DE LA ENERGÍA\Respaldos Codex\REPORTE DE CALDERAS 2018 - respaldo antes de ordenar 2026-07-28.xlsx`.
- Hojas ordenadas por fecha y hora ascendente, con claves secundarias estables:
  `App_Datos_Firestore`, `App_Intervalos`, `App_Consumo_Horario` y
  `App_Resumen_Diario`.
- Se conservaron sin cambios `Regist_inform`, `App_Mapeo_Regist`,
  `App_Control` y las demas hojas del libro. El ordenamiento se ejecuto con el
  motor nativo de Excel para preservar fechas ISO, formatos, vinculos,
  formulas y objetos.
- Verificacion: quedaron 68 filas crudas, 68 intervalos, 212 asignaciones
  horarias y 12 resumenes diarios, sin saltos cronologicos. Las cuatro hojas
  conservaron exactamente las mismas filas antes y despues. El libro mantuvo
  sus 15 hojas y 58.505 celdas con formulas.
- Ajuste adicional: se ordeno exclusivamente el bloque de la aplicacion en
  `Regist_inform!A6488:S6499`, correspondiente a las 12 filas del 24 al 28 de
  julio de 2026. La fila 6487 y toda la historia anterior permanecieron
  intactas. Dentro de cada fecha se aplico un orden estable por caldera.
- Respaldo del segundo ajuste:
  `C:\Users\windo\OneDrive - Grupo Danec\MEJORAS\1. SEGUIMIENTO DE LA ENERGÍA\Respaldos Codex\REPORTE DE CALDERAS 2018 - respaldo antes de ordenar Regist_inform 2026-07-28.xlsx`.
- Verificacion de `Regist_inform`: se conservaron los mismos 12 registros,
  las formulas de cada fila continuan apuntando a su propia fila, los nombres
  de los dias se muestran en espanol y el libro sigue conteniendo 15 hojas y
  58.505 celdas con formulas.
- Compatibilidad: no se alteraron IDs ni claves de sincronizacion. Las cargas
  posteriores pueden continuar actualizando por `documentId` y `syncKey`.

### 2026-07-28 - Precarga Cleaver, vapor en kg e historial 1.3.0

- Solicitud: corregir la precarga del hodometro de Cleaver Brooks, definir la
  lectura de vapor en kilogramos y agregar un historial de consumos separado
  por caldera.
- Causa de Cleaver: la pantalla asociaba la ultima lectura al nombre visible y
  Firestore limitaba a cada usuario a sus propios documentos. La precarga ahora
  usa el `boilerId` estable y las lecturas operativas son visibles para todo
  usuario autenticado. Crear sigue exigiendo `createdByUid` propio y el cliente
  no puede actualizar ni borrar lecturas.
- Vapor: Alfa Laval captura y guarda las nuevas lecturas acumuladas en `kg`.
  Los documentos historicos de Alfa etiquetados como `gal` se interpretan como
  `kg` sin modificar el valor ni reescribir los documentos existentes.
- Interfaz: se agrego el boton `Registros` junto a `Ingresar consumos`. La nueva
  pantalla separa Alfa Laval, Distral 900 y Cleaver Brooks en la navegacion
  inferior, muestra fecha/hora, bunker, agua y vapor, inicia con 15 filas y
  permite cargar 15 mas. En telefono las cuatro columnas caben en pantalla.
- Prueba productiva: una sesion autenticada cargo 19 lecturas de Alfa Laval en
  el historial. Al seleccionar Cleaver Brooks en `Ingresar consumos`, bunker y
  agua recuperaron valores acumulados reales distintos de cero. No hubo errores
  de consola ni escrituras durante estas comprobaciones.
- Seguridad: `boiler_consumption_readings` permite lectura a usuarios
  autenticados; las reglas de creacion, inmutabilidad y ausencia de PIN se
  conservaron. Se agrego una prueba especifica de lectura compartida.
- Version y publicacion: Flutter `1.3.0+7`. Web y reglas desplegadas en
  `https://eficiencia-energetica-ee.web.app`. APK firmado de 56.194.394 bytes:
  `https://github.com/inoxiap/eficiencia-energetica-ee/releases/download/v1.3.0/eficiencia-energetica-ee-1.3.0-build7.apk`.
  `app_config/mobile_app` anuncia build 7 con actualizacion no forzada.
- Pruebas/builds: `flutter analyze` sin hallazgos, 47 pruebas Flutter y 10
  pruebas de reglas aprobadas; builds release web y Android correctos.
- Commits principales: `378108a`, `c5933f5` y `e1632ca`.
- Pendientes: ninguno para esta solicitud.

### 2026-07-29 - Recuperacion del Excel tras sobrescritura de OneDrive

- Incidente: el libro local ordenado el 2026-07-28 se sincronizo tarde y
  reemplazo la version de la nube que habia seguido recibiendo lecturas durante
  la noche y la manana del 29. No se restauro una version a ciegas: Firestore
  se mantuvo como fuente oficial.
- Respaldo inmediato de la copia sobrescrita, fuera de OneDrive:
  `outputs/excel-recovery-20260729/REPORTE DE CALDERAS 2018 - copia local tras sobrescritura 2026-07-29.xlsx`.
  SHA-256:
  `7F2C3B0BED9D476ABF6B046E95FB0A19C09EF937539F0DA816272FE763259D6C`.
- Diagnostico: el libro sobrescrito conservaba 68 lecturas y terminaba el
  2026-07-28 a las 11:02 de Ecuador. Una sincronizacion automatica posterior
  agrego cuatro lecturas del 29; al comparar los IDs con Firestore quedaron 30
  faltantes: 18 del 28 y 12 del 29.
- Fuente oficial: Firestore contenia 102 lecturas desde el 24 hasta el 29 de
  julio: 6, 7, 16, 28, 29 y 16 por fecha local. Por caldera eran 26 de Alfa
  Laval, 4 de Distral 900 y 72 de Cleaver Brooks.
- Recuperacion idempotente: se reprocesaron completos los dias 2026-07-28 y
  2026-07-29. GitHub Actions termino correctamente en las ejecuciones
  `30487177795` y `30487340286`, con lotes de 29 y 16 lecturas. Power Automate
  tambien termino correctamente en las ejecuciones
  `08584162512163860436299831807CU09` y
  `08584162510777747168439869363CU04`; ambos lotes quedaron
  `acknowledged`.
- Verificacion cloud: `App_Datos_Firestore!A103` contiene
  `cleaver_brooks_1200_2026072920` y `A104` esta vacia. Esto corresponde a 102
  filas de datos mas la cabecera. `Regist_inform!A6500:A6501` contiene las dos
  filas del 2026-07-29 y `A6502` esta vacia.
- Verificacion local despues de que OneDrive bajo la version restaurada:
  `App_Datos_Firestore` tiene 102 IDs, exactamente los mismos que Firestore,
  con 0 faltantes, 0 extras y 0 duplicados. `App_Intervalos` tiene 102 filas,
  `App_Consumo_Horario` 302 y `App_Resumen_Diario` 14, sin contar cabeceras.
  `Regist_inform` conserva 14 filas administradas desde el 24, incluidas dos
  del 29 para `CalAlfa` y `CalCleaver`.
- Integridad: el libro conserva 15 hojas y 58.519 celdas con formulas. Los
  errores de formula existentes se limitan al rango historico
  `rev_900-700!L5:L31`; no aparecen en las hojas administradas por la app.
- Respaldo final restaurado, fuera de OneDrive:
  `outputs/excel-recovery-20260729/REPORTE DE CALDERAS 2018 - recuperado 2026-07-29 1510.xlsx`.
  Pesa 1.718.182 bytes y su SHA-256 es
  `D2B0F4ADDAAA5693157002068031A2BF3F6BB9CA67FA024FEE27C49A10781007`.
- Regla operativa: antes de modificar localmente el maestro, confirmar que
  OneDrive muestre sincronizacion completa. Si no esta sincronizado, trabajar
  sobre una copia fuera de OneDrive y no reemplazar el maestro. Para cambios
  importantes, conservar respaldo externo y comprobar despues los IDs contra
  Firestore.

### 2026-08-05 - Destinos jerarquicos y transporte de fugas

- Solicitud: reemplazar la seccion generica de fugas por selectores dependientes
  Macroarea -> Proceso/destino general -> Equipo -> Sistema/subsistema usando
  `destinations-phanto-ready.json`, permitir seleccion parcial y preparar el
  transito Firestore -> GitHub -> Power Automate -> Excel.
- Catalogo: la fuente contiene 5.097 destinos, 16 macroareas y version 2.0.0.
  `tool/generate_destination_catalog.cjs` valida nombres y hojas ambiguas y
  genera `assets/destination_catalog.json` de 588.428 bytes. No se incluye el
  JSON fuente de 5 MB en el APK.
- Interfaz: cada selector ofrece una opcion vacia y ningun descendiente se
  autoselecciona. Cambiar macroarea limpia proceso, equipo, sistema e ID;
  cambiar proceso limpia equipo, sistema e ID; cambiar equipo limpia sistema e
  ID. La captura puede terminar en cualquier nivel, incluso `none`.
- Persistencia: `leak_reports` usa esquema 2 con `sectionCode`, `processCode`,
  `equipmentCode`, `systemCode`, `destinationId` y `selectionDepth`, ademas de
  snapshots visibles. Los 13 equipos sin sistema de NO OPERATIVOS se reconocen
  como hojas terminales. Se agrego `condensate` como tipo de fuga.
- Identificacion: el usuario ya no escribe el numero. Una transaccion sobre
  `maintenance_counters/leak_reports` asigna `leakNumber` y `tagNumber` con
  formato `F-000001`; reintentar el mismo documento es idempotente.
- Auditoria: fecha y hora usan timestamps de servidor, y usuario, version y
  plataforma se toman automaticamente de la sesion y del aplicativo.
- Transporte: `integrations/leak_excel_sync` publica en un issue privado solo
  reportes nuevos o modificados por `updatedAt`. Incluye estados de OT y trabajo
  ejecutado, foto, destino, fecha, hora y usuario. Un lote `ready` bloquea nuevas
  lecturas hasta recibir acuse `acknowledged`; GitHub es transito, no historico.
  El Office Script crea o actualiza `App_Fugas`/`tblAppFugas` por ID estable.
- Eficiencia: el exportador de fugas se agrega al mismo workflow horario de
  calderas para no duplicar minutos de GitHub Actions. Cada lote se limita a 50
  filas y el siguiente avanza desde el cursor confirmado.
- Version: Flutter `1.4.0+8`. Hosting y reglas Firestore se desplegaron en
  produccion en `https://eficiencia-energetica-ee.web.app`.
- Pruebas/builds: `flutter analyze` sin hallazgos, 51 pruebas Flutter y 4 del
  exportador de fugas aprobadas; Functions y Office Script compilaron; web y APK
  release correctos. El APK pesa 53,7 MB, verifica firma v2 y tiene SHA-256
  `7AD122631703C21B62BBE554F677E3DCFCA3ED04EACFCA6864CA5153F44C9381`.
- Verificacion visual: produccion se reviso con una sesion real sin escribir
  datos. Macroarea, proceso y equipo aparecieron de forma dependiente; cambiar
  macroarea limpio los niveles inferiores. No hubo errores de consola.
- Pendiente: publicar el APK build 8 y actualizar el aviso remoto; instalar el
  workflow privado e issue de fugas; seleccionar el libro de OneDrive y crear
  el flujo Power Automate con el Office Script preparado.

## Plantilla para futuras entradas

```markdown
### AAAA-MM-DD - Titulo breve

- Solicitud:
- Resultado:
- Archivos principales:
- Pruebas/builds:
- Despliegue:
- Decisiones:
- Pendientes o riesgos:
```
