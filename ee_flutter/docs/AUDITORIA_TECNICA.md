# Auditoria tecnica

Fecha: 2026-07-11

## Repositorio y arquitectura

La fuente vigente esta en ee_flutter/ dentro del repositorio
inoxiap/eficiencia-energetica-ee. La carpeta App Eficiencia Energetica contiene
un Git vacio y no es la fuente.

- Version 1.0.1+2, Flutter 3.41.9 y Dart 3.11.5.
- Rama main; commit inicial auditado d95faf3.
- Android y web comparten la base Flutter.
- app/ y web/ son antecedentes nativo/PWA.

La app usa Material, MaterialPageRoute, StatefulWidget y setState. No hay
Provider, Riverpod, Bloc ni otro gestor de estado.

- lib/main.dart: arranque, tema, pantallas y componentes; unas 2.900 lineas.
- lib/domain/trap_sizing.dart: catalogo y formulas de trampas.
- lib/domain/bare_pipe.dart: modelo y formula de tuberia desnuda.
- lib/domain/boiler_consumption.dart: lecturas y deltas.
- lib/services/: persistencia, Cloudinary y actualizaciones.

Pantallas: inicio/splash, trampas, tuberia desnuda, consumos y panel
administrador. El panel no tiene control de acceso. Su interfaz no se
modificara salvo una dependencia minima inevitable.

## Persistencia actual

Tuberia y consumos guardan primero en SharedPreferences, intentan escribir en
Firestore y al leer mezclan remoto/local por id. No existe cola durable, estado
pendiente, confirmacion remota ni reintento automatico.

## Firebase

Proyecto eficiencia-energetica-ee:

- Android: com.example.eficiencia_energetica_ee.
- Web: configurada con FlutterFire.
- Firestore nativo (default), region nam5.
- Sin indices compuestos ni reglas/indices versionados.

Colecciones remotas:

- app_config: 1 documento.
- bare_pipe_reports: 9 documentos.
- boiler_consumption_readings: 4.392 documentos.

Las reglas remotas son temporales y ya vencieron:

    allow read, write: if request.time < timestamp.date(2026, 6, 29);

El cliente recibe denegacion. Deben reemplazarse por reglas basadas en Firebase
Authentication. No se encontro uso de Firebase Storage ni reglas asociadas.

## Proveedor de imagenes

El proveedor es Cloudinary y se conservara:

- Cloud name dovufh5wv.
- Upload preset ee_evidencias_unsigned.
- Carga por la API de imagenes.
- Se guardan secure_url y public_id.

La app usa image_picker, ancho maximo 1.600 px y calidad 85. La carga es
unsigned. Se evaluara firma de backend o endurecimiento del preset sin migrar
imagenes ni cambiar de proveedor.

## Dimensionamiento de trampas

Usos reales:

- Tracing.
- Serpentin de tanque.
- Chaqueta o Marmita.
- Chaqueta trabajo pesado.
- Distribuidor principal de caldero.
- Distribuidor de vapor.
- Intercambiador de calor.
- Linea principal de vapor (Pierna de condensado).

Inicia sin uso. Tracing no pide datos. Los demas permiten metodo directo en
L/min o calculo indirecto.

Constantes preservadas:

- Condensado 1.0 kg/L.
- Aceite 0.89 kg/L y 2.0 kJ/(kg C).
- Factor de seguridad 1.2.
- Ambiente 30 C.
- Distribuidor principal 12 %.
- Distribuidor secundario 1 %.
- Velocidad de referencia 10 m/s.

Formulas:

- Directo: kg/h = L/min x 1.0 x 60.
- Tanques/marmitas/chaquetas: balance de energia por lote.
- Intercambiador: balance continuo.
- Distribuidor principal: maximo entre 12 % del agua y perdida superficial.
- Distribuidor secundario: maximo entre drenaje estimado y perdida superficial.
- Linea principal: perdida superficial dividida por calor latente.

La recomendacion de diametro es preliminar, sin curva de fabricante ni presion
diferencial. La calculadora no persiste actualmente.

## Tuberia desnuda

Entradas: seccion, diametro, presion, longitud y foto requerida. La formula
calcula saturacion, conveccion, radiacion, W/m, kW, energia mensual y costo.

Supuestos: ambiente 27 C, emisividad 0.8, 24 h/dia, 30 dias/mes, eficiencia
0.76, PCI 139000 BTU/gal y precio 0.94 USD/gal.

Se sube primero a Cloudinary y luego se guarda. No hay resumen/confirmacion
previa. Si Firestore falla queda copia local sin estado remoto explicito. Las
fechas son textos ISO del cliente.

## Consumos de calderas

Calderas definidas y presentes remotamente:

- Caldera Alfa Laval 1200.
- Caldera Distral 900.
- Caldera Cleaver Brooks 1200.

No existe Caldera 1100. El codigo habilita vapor solo para Alfa Laval, en
conflicto con el criterio solicitado para Cleaver Brooks. Se tratara como
configuracion pendiente de confirmacion.

Los campos son lecturas totales. Se calculan deltas positivos contra la lectura
anterior; reinicios o negativos producen delta nulo.

Brechas:

- Unidades "unid.".
- ID aleatorio sin proteccion por caldera/hora.
- Sin revision, historial ni confirmacion.
- operatorPin en texto plano local y remoto.
- Los 4.392 documentos contienen operatorPin.
- Fechas como texto, no timestamp de servidor.

Hay 1.464 lecturas por caldera y no se detectaron horas duplicadas.

## Autenticacion y catalogos

No existe firebase_auth, registro, login, sesion, roles, claims ni Cloud
Functions. El panel administrador es accesible desde inicio. No se implementara
validacion de PIN en cliente.

La lista de secciones actual es texto libre: Jaboneria, Margarina, Calderas,
Refineria, Hidrogenacion, Envase y Confiteria. No tiene IDs estables. Se
agregara el catalogo comun con aliases historicos.

## Compatibilidad y linea base

- flutter analyze: aprobado.
- flutter test: 1 prueba aprobada.
- Build web: aprobado.
- APK Android debug: aprobado.

Android y web estan activos. Apple usara la PWA; iOS nativo no tiene FlutterFire.

## Riesgos prioritarios

1. Reglas vencidas y no versionadas.
2. PIN en texto plano.
3. Sin autenticacion/autorizacion.
4. Timestamps del cliente en texto.
5. Unidades desconocidas.
6. Conflicto sobre la caldera que mide vapor.
7. Carga unsigned de Cloudinary.
8. Responsabilidades concentradas en main.dart.
9. Cobertura de pruebas insuficiente.
10. Offline sin confirmacion real de nube.

## Actualizacion 2026-07-15

- Se retiro la dependencia de Cloud Functions del cliente Flutter.
- Se agrego `leak_reports` y seguimiento de mantenimiento para fugas/tuberias.
- Se confirmo Cloudinary como proveedor de todas las nuevas evidencias.
- Reglas e indices se desplegaron en produccion.
- El proveedor Correo/contrasena sigue deshabilitado y requiere permiso de
  propietario para activarse en Firebase Console.

## Decisiones pendientes

- Caldera que registra vapor.
- Existencia e ID de Caldera 1100.
- Unidades de agua, bunker y vapor.
- Modo acumulado o intervalo por variable/caldera.
- Rangos razonables de advertencia.

Hasta confirmar, se conservara compatibilidad y se usara configuracion
explicita; no se inventaran valores.
