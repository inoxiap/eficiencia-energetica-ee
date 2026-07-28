# Eficiencia Energetica EE

Aplicacion Flutter para Android y web orientada a captura de datos de planta,
calculos de eficiencia energetica y trazabilidad en Firebase.

## Modulos

- Dimensionamiento de trampas de vapor.
- Reporte de tuberia desnuda con fotos en Cloudinary.
- Reporte de fugas de vapor, aceite, agua y aire con fotos en Cloudinary.
- Seguimiento operativo de OT generada y trabajo ejecutado.
- Lecturas acumuladas de calderas y presiones de distribuidores.
- Registro e inicio de sesion de operadores.
- Levantamiento electrico de bombas.
- Panel administrador legado dentro de Flutter, sin cambios funcionales.
- Dashboard administrador independiente en energy_dashboard/.

## Arquitectura

- Flutter/Dart: cliente Android y PWA web.
- Cloud Firestore: datos estructurados.
- Firebase Authentication: sesion persistente.
- Cloudinary: fotos de tuberia y placa de bomba.
- FastAPI/Jinja2/Plotly.js: dashboard independiente.

El operador ve cedula y PIN. Internamente se usa el proveedor
Correo/contrasena de Firebase Auth con una direccion tecnica derivada de la
cedula. Firebase conserva y protege la credencial; el PIN no se guarda en
Firestore, SharedPreferences ni localStorage. Esta variante funciona en Spark
y su nivel de seguridad corresponde al PIN corto elegido para uso interno.

## Requisitos Flutter

- Flutter 3.41.9 o compatible.
- Android SDK/Java 17.
- Configuracion FlutterFire incluida para Android y web.

Comandos:

    flutter pub get
    flutter analyze
    flutter test
    flutter build web --no-web-resources-cdn --no-wasm-dry-run
    flutter build apk --debug

## Firebase en plan Spark

En Firebase Console se debe habilitar una sola vez Authentication > Proveedores
de acceso > Correo/contrasena. No se requiere Cloud Functions ni plan Blaze.

Pruebas de reglas:

    firebase emulators:exec --only firestore "npm --prefix functions run test:rules"

Despliegue:

    firebase deploy --only firestore:rules,firestore:indexes,hosting

### Prueba local completa de autenticacion

Iniciar los emuladores:

    firebase emulators:start --only auth,firestore

En otra terminal, compilar la web en modo emulador:

    flutter build web --no-web-resources-cdn --no-wasm-dry-run --dart-define=USE_FIREBASE_EMULATORS=true

En web el modo emulador usa `127.0.0.1`; en el emulador Android usa
`10.0.2.2`. Auth escucha en 9099 y Firestore en 8081. Una compilacion sin el
`dart-define` conserva Firebase real.

Todo registro publico crea el rol `operator`. El rol `admin` se asigna solamente
desde un entorno administrativo confiable o desde Firebase Console.

## Remediacion del PIN historico

La app elimina operatorPin de SharedPreferences al leer datos locales antiguos.
Para Firestore existe un script que por defecto solo simula:

    cd functions
    npm run sanitize:pins

Despues de crear un respaldo y aprobar la eliminacion:

    npm run sanitize:pins -- --apply

## Dashboard

Ver energy_dashboard/README.md. Resumen:

    cd energy_dashboard
    python -m venv .venv
    .venv/Scripts/pip install -r requirements.txt
    copy .env.example .env
    .venv/Scripts/uvicorn app.main:app --reload --port 8080

No guardar la cuenta de servicio ni los secretos en el repositorio.

## Decisiones pendientes de planta

- Confirmar si existe Caldera 1100 y su ID.
- Confirmar rangos operativos de advertencia.

Las lecturas nuevas de agua y bunker se normalizan en galones (`gal`) para los
calculos y la integracion con Excel. El vapor de Alfa Laval se registra en
kilogramos (`kg`). Todas son lecturas acumuladas. Distral 900 y Cleaver Brooks
mantienen vapor deshabilitado. Las presiones se guardan en PSI. La presion de
cada caldera se guarda con su lectura acumulada en
`boiler_consumption_readings`; las presiones de distribuidores se guardan en
`steam_pressure_readings`.

## Excel de consumos de calderas

`integrations/boiler_excel_sync/` contiene el exportador que convierte las
lecturas acumuladas en intervalos, consumo por hora cerrada y resumen diario
compatible con las columnas A:P de `Regist_inform`.

La sincronizacion funciona con la laptop apagada y actualiza el mismo libro
maestro `REPORTE DE CALDERAS 2018.xlsx`. Un GitHub Action alojado en el
repositorio privado lee Firestore y publica un payload incremental en su issue.
Power Automate,
con conectores estandar de GitHub y Excel Online (Business), ejecuta un Office
Script que actualiza las hojas `App_*` y `Regist_inform` por claves estables.
El flujo es idempotente y evita sobrescribir filas historicas no administradas.

El disparador HTTP se descarto porque exige Power Automate Premium. Los datos
operativos nunca deben publicarse en el repositorio publico del codigo. La
configuracion completa y los secretos requeridos estan documentados en
`integrations/boiler_excel_sync/README.md`.

## Documentacion

- docs/AUDITORIA_TECNICA.md
- docs/PLAN_IMPLEMENTACION.md
- docs/MODELO_DATOS.md
- docs/DECISIONES_TECNICAS.md
- docs/FORMULAS_Y_UNIDADES.md
- docs/SEGURIDAD_Y_ROLES.md
- IMPLEMENTATION_REPORT.md
