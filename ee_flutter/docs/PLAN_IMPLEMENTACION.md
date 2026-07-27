# Plan de implementacion

## Principios

- Evolucionar Flutter sin reescribir la app.
- Preservar formulas mediante pruebas de regresion.
- Mantener Cloudinary.
- No modificar la interfaz del panel administrador salvo dependencia minima.
- Usar timestamps de servidor y mostrar America/Guayaquil.
- No escribir en nube sin usuario autenticado y confirmacion.
- No guardar secretos en Git.

## Dependencia de seguridad

Las fases 1 a 3 necesitan identidad para una escritura segura. Se prepararan
modelos, repositorios, confirmaciones y pruebas en orden; toda escritura remota
exigira sesion valida. Registro e inicio de sesion usan Firebase Authentication
con correo interno derivado de la cedula, compatible con el plan Spark.

## Fase 0 - Base tecnica

- Catalogo comun de secciones con IDs.
- Tipos comunes de auditoria, unidades y estados.
- Proveedor de sesion desacoplado.
- Pruebas de regresion de todas las formulas.
- Reglas, indices y emuladores versionados.

Salida: resultados anteriores preservados, builds aprobados y ningun guardado
nuevo sin identidad.

## Fase 1 - Trampas

- Mantener ocho usos y metodos directo/indirecto.
- Agregar seccion, equipo y observaciones.
- Calcular y mostrar sin guardar.
- Agregar Guardar en la nube y Solo calcular / No guardar.
- Mostrar resumen y pedir confirmacion.
- Guardar entradas, unidades, resultado, supuestos, factor 1.2, recomendacion y
  version de formula.
- Crear repositorio y pruebas.

Coleccion nueva: steam_trap_sizing_reports.

## Fase 2 - Tuberia desnuda

- Reutilizar bare_pipe_reports.
- Agregar IDs de seccion, auditoria y equipo/ubicacion.
- Calcular y resumir antes de guardar.
- Mantener Cloudinary y registrar provider=cloudinary.
- Estados draft, uploading, pending_sync, synced y error.
- Reintento idempotente y compatibilidad con documentos historicos.

## Fase 3 - Consumos

- Reutilizar boiler_consumption_readings.
- Agregar boilerId, unidades y readingMode.
- ID deterministico por caldera/hora.
- Revision e historial sin borrado.
- Revision/confirmacion previa.
- Deltas solo para cumulative_meter.
- Control de reinicios, negativos, faltantes y cobertura.
- Sustituir PIN por UID; nunca copiar PIN historico.
- Regla de vapor configurable hasta confirmacion.

## Fase 4 - Autenticacion

- Firebase Authentication correo/contrasena, compatible con Spark.
- Credencial tecnica derivada de cedula + PIN, sin mostrar correo al operador.
- Registro, login, sesion persistente, cierre y cambio de operador.
- Perfil `users/{uid}` y rol inicial operator.
- Impedir autoasignacion de admin.
- Reglas por auth.uid y rol Firestore.
- No migrar PIN historico como credencial.

Estado: implementado y probado en Android. Falta que un propietario habilite el
proveedor Correo/contrasena en el proyecto Firebase real.

## Fase 4B - Fugas y seguimiento

- Captura de fugas con evidencia Cloudinary y datos operativos simples.
- Historial compartido de fugas y tuberia desnuda.
- Filtro de fechas y estados OT generada/trabajo ejecutado.
- Vista administrativa y dashboard independiente.

## Fase 5 - Bombas

- Dominio, calculadora, repositorio y pantalla.
- Ruedas existentes mas entrada manual.
- Catalogo HP y opcion Otro.
- Captura electrica completa y foto de placa en Cloudinary.
- Prioridad de calculo y niveles de confianza.
- Desequilibrio y advertencias sin diagnostico definitivo.
- Tablas configurables de eficiencia/FP.
- Comparacion linea base/post mejora.

Colecciones: pump_energy_surveys y motor_reference_tables.

## Fase 6 - Dashboard

Crear energy_dashboard/ con FastAPI, Jinja2, Plotly.js, Firebase Admin solo en
servidor, autenticacion admin, filtros, paginacion, CSV, Dockerfile,
requirements, .env.example y README.

El navegador nunca recibira credenciales administrativas. Las consultas seran
filtradas/paginadas y no cargaran colecciones completas.

## Fases 7 y 8 - Seguridad, indices y UX

- Reglas restrictivas por coleccion.
- Impedir falsificacion de UID y borrado desde clientes.
- Validar campos y estados.
- Indices para consultas reales.
- Pruebas con Emulator Suite.
- Estados claros de calculo, carga y sincronizacion.
- Prevencion de doble toque.
- Unidades visibles y controles responsivos.
- Offline idempotente con distincion local/pendiente/remoto.

## Fases 9 y 10 - Verificacion y entrega

Por fase: flutter analyze, flutter test, build web y build Android.

Al cierre: pruebas de reglas/autenticacion, dashboard, secretos, compatibilidad
historica, documentacion completa, README e IMPLEMENTATION_REPORT.md.

## Confirmaciones requeridas antes del despliegue final

- Caldera que registra vapor.
- Existencia de Caldera 1100.
- Unidades reales de medidores.
- Modo de lectura por variable/caldera.
- Rangos de advertencia.
- Activacion del proveedor Correo/contrasena en Firebase Authentication.
