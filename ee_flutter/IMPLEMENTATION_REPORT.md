# Implementation report

Fecha: 2026-07-15

## Actualizacion 2026-07-28 - Version 1.3.0

- La precarga del hodometro usa el `boilerId` estable y ya no depende del
  nombre visible de la caldera.
- Los usuarios autenticados pueden consultar el historial operativo compartido
  de consumos; las escrituras siguen ligadas al usuario y no se permite
  actualizar ni borrar lecturas desde el cliente.
- El vapor de Alfa Laval se captura y almacena en kilogramos (`kg`).
- Se agrego `Registros` junto a `Ingresar consumos`, con vistas independientes
  para Alfa Laval, Distral 900 y Cleaver Brooks y carga progresiva de 15 filas.
- Verificacion: `flutter analyze` sin hallazgos, 47 pruebas Flutter y 10 pruebas
  de reglas aprobadas, build web y APK release `1.3.0+7` correctos.
- Produccion: Hosting y reglas Firestore desplegados en
  `https://eficiencia-energetica-ee.web.app`.

## Actualizacion 2026-07-24

- Se agrego presion obligatoria de caldera en PSI a cada lectura acumulada.
- Se creo `integrations/boiler_excel_sync/` para exportar Firestore a un libro
  auxiliar con datos crudos, intervalos, consumo horario y resumen diario.
- Se preparo un workflow horario de GitHub Actions que publica un payload
  incremental en un issue privado para que Power Automate actualice el mismo
  libro maestro mediante Excel Online (Business) y Office Scripts.
- El archivo maestro `REPORTE DE CALDERAS 2018.xlsx` se audito y no fue
  modificado durante la preparacion. Se creo un respaldo previo a la prueba.
- Se creo y probo el Office Script `EE - Sincronizar consumos de calderas`.
  Una segunda ejecucion del mismo payload produjo cero filas nuevas y una
  actualizacion, confirmando que no duplica registros.
- Se descarto el disparador HTTP de Power Automate porque requiere licencia
  Premium. La solucion elegida usa solamente conectores estandar.
- Se dividio Ingresar consumos en las pestanas inferiores Consumos y Presiones.
- Las lecturas nuevas de calderas son exclusivamente acumuladas.
- Alfa Laval solicita bunker, agua y vapor; Distral 900 y Cleaver Brooks
  mantienen vapor deshabilitado.
- Se agregaron cinco presiones del distribuidor Cleaver y nueve del
  distribuidor 900, todas en PSI, con revision y confirmacion antes de guardar.
- Se incorporo `steam_pressure_readings` con trazabilidad y timestamps de
  servidor, junto con reglas restrictivas de Firestore.
- Compatibilidad historica: el motor sigue leyendo documentos
  `interval_consumption`, aunque la interfaz y las reglas ya no crean nuevos.
- Verificacion: `flutter analyze`, 38 pruebas Flutter, build web release y APK
  release aprobados.
- Produccion: Hosting y reglas Firestore desplegados correctamente en
  `https://eficiencia-energetica-ee.web.app`.
- Integracion Excel: 9 pruebas Python aprobadas y Office Script compilado,
  guardado y probado en Excel Online.

## Implementado

- Autenticacion cedula+PIN simplificada con Firebase Authentication y sesion persistente.
- Compatibilidad con plan Spark; Flutter ya no depende de Cloud Functions.
- Registro de perfil `users/{uid}` con rol inicial `operator` y auditoria.
- Modulo `Reportar fugas` con foto Cloudinary, seccion, ubicacion opcional,
  tipo de fuga, numero, revision y confirmacion.
- Coleccion `leak_reports`, reglas e indices desplegados en produccion.
- Seguimiento compartido de fugas y tuberia desnuda con filtro de fechas,
  `OT generada` y `Trabajo ejecutado`.
- Nueva vista de fugas en el panel administrador Flutter.
- Fugas agregadas al dashboard FastAPI, filtros, KPIs, graficos, tabla y CSV.
- Login del dashboard alineado con Firebase Auth y rol Firestore.
- Bunker y agua normalizados en galones (`gal`); vapor de Alfa Laval en
  kilogramos (`kg`).
- Version Android/web 1.3.0+7.

## Existia y se conservo

- Formulas y ocho usos de trampas; factor de seguridad 1.2.
- Formula y flujo de tuberia desnuda.
- Fotos en Cloudinary; no se migro el proveedor.
- Consumos acumulados/intervalo y revisiones por hora.
- Levantamiento electrico de bombas y sus calculos.
- Actualizacion Android mediante `app_config`.

## Produccion

- Firestore rules: desplegadas.
- Firestore indexes: desplegados.
- Firebase Hosting: `https://eficiencia-energetica-ee.web.app`.
- Plan confirmado: Spark.
- Pendiente externo: habilitar el proveedor `Correo/contrasena` en Firebase
  Authentication. La cuenta actual puede desplegar, pero la consola indica que
  necesita permiso de propietario para cambiar proveedores.
- Dashboard independiente aun no esta desplegado como servicio HTTPS.
- No se ejecuto limpieza remota del campo historico `operatorPin`.

## Pruebas ejecutadas

- `flutter analyze`: aprobado sin observaciones.
- `flutter test`: 35 pruebas aprobadas.
- Reglas Firestore: 7 pruebas aprobadas con Emulator Suite.
- Dashboard: 7 pruebas aprobadas.
- `flutter build apk --release`: aprobado, 52.6 MB.
- `flutter build web --release`: aprobado.
- Pixel 8 API 35: instalacion y revision visual aprobadas.
- Registro de operador en Firebase Auth de prueba: aprobado.
- Cierre, ingreso con cedula+PIN y persistencia tras reinicio: aprobados.
- Seguimiento: lectura de fugas/tuberias y ambos checks actualizados en
  Firestore desde Android: aprobados.

## Riesgos pendientes

- Un PIN de 4 a 6 digitos tiene seguridad limitada; se acepta para el uso
  interno solicitado y nunca se almacena en texto plano por la app.
- El preset Cloudinary unsigned debe conservar restricciones de formato y tamano.
- Los registros historicos pueden carecer de UID o timestamps de servidor.
- Falta confirmar la caldera que registra vapor y la existencia de Caldera 1100.
- La primera prueba integral uso un payload vacio porque no habia lecturas del
  dia. Falta validar nuevamente con dos lecturas acumuladas consecutivas para
  observar un delta y resumen diario reales.

## Comandos principales

    flutter analyze
    flutter test
    flutter build apk --release
    flutter build web --release
    firebase emulators:exec --only firestore "npm --prefix functions run test:rules"
    energy_dashboard/.venv/Scripts/python.exe -m pytest -q
    firebase deploy --only firestore:rules,firestore:indexes,hosting

    cd integrations/boiler_excel_sync
    python -m unittest -v test_exporter.py

## Proximo paso obligatorio

1. Registrar al menos dos lecturas acumuladas consecutivas de una caldera.
2. Confirmar que el siguiente ciclo horario calcula el delta y actualiza
   `App_Consumo_Horario`, `App_Resumen_Diario` y `Regist_inform`.

## Integracion Excel operativa

- Repositorio privado: `inoxiap/eficiencia-energetica-datos`.
- Buzon: issue `#1`.
- Workflow privado: horario al minuto 17 y ejecutable manualmente.
- Cuenta Firebase: `EE Excel Reader`, rol `Lector de Cloud Datastore`.
- Secreto requerido: `FIREBASE_SERVICE_ACCOUNT_JSON`.
- Power Automate: `EE - Actualizar Excel maestro desde GitHub`, estado `On`.
- Primera ejecucion GitHub Actions: exitosa en 32 segundos.
- Segunda ejecucion con `actions/setup-python@v6`: exitosa en 24 segundos y
  sin advertencias.
- Primera prueba integral Power Automate: `Test succeeded` en 9 segundos.
- Maestro: seis hojas `App_*` creadas y `App_Control` en `Completado`.
