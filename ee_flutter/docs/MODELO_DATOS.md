# Modelo de datos

Version inicial del esquema nuevo: 1.

## Convenciones

- Colecciones/campos nuevos en ingles.
- IDs de catalogo en lower_snake_case.
- Fechas remotas como Timestamp.
- Presentacion en America/Guayaquil.
- Numero y unidad en campos separados.
- Entradas originales en inputs y resultados en results.
- Dimensiones de filtro tambien en primer nivel.

## Campos comunes

Todo registro operativo nuevo incluye:

    id
    sectionId
    sectionNameSnapshot
    equipmentName
    equipmentNameNormalized
    createdAt: Timestamp de servidor
    createdByUid
    createdByNameSnapshot
    updatedAt: Timestamp de servidor
    updatedByUid
    appVersion
    platform: android | web
    schemaVersion
    status
    source: manual
    notes

capturedAtLocal puede apoyar una cola offline, pero nunca sustituye createdAt.

## Catalogo de secciones

| ID estable | Etiqueta |
| --- | --- |
| refineria | Refineria |
| confiteria_galleteria | Confiteria y Galleteria |
| desodorizacion | Desodorizacion |
| fraccionamiento | Fraccionamiento |
| manteca | Manteca |
| aceites | Aceites |
| hidrogenacion | Hidrogenacion |
| jaboneria | Jaboneria |
| recepcion | Recepcion |
| dex | DEX |
| servicios_industriales | Servicios Industriales |
| margarina | Margarina |

Cada entrada puede tener displayName, normalizedName, aliases, active,
sortOrder y schemaVersion. Calderas, Envase y Confiteria historicos se mapean
mediante aliases documentados.

## steam_trap_sizing_reports

Coleccion nueva. Campos consultables:

    applicationTypeId
    calculationMethod: direct | indirect | direct_selection
    formulaVersion
    condensateLoadKgH
    requiredCapacityKgH
    recommendedTrapType
    recommendedConnectionDiameter
    safetyFactor

inputs.values conserva por cada fieldKey: value, unit y labelSnapshot.
results conserva cargas, equivalente L/h, recomendacion y explicacion.
assumptions conserva valores y version de fuente.

El documento se crea solo despues de calcular, revisar y confirmar.

## bare_pipe_reports

Se conserva la coleccion existente.

Historico:

    id, createdAt ISO, section, diameterLabel, pressureBarG, lengthMeters,
    photoUrl, photoPublicId, calculation

Nuevo:

    sectionId, sectionNameSnapshot, equipmentName, equipmentNameNormalized
    diameterNominal, diameterUnit, outsideDiameterMm
    pressureValue, pressureUnit, lengthValue, lengthUnit
    photo: provider, url, publicId, uploadStatus
    results: surfaceTemperatureC, heatLossWPerM, heatLossKw,
             assumedOperatingHoursMonth, energyKwhMonth,
             estimatedBunkerGallonsMonth, estimatedCostUsdMonth
    formulaVersion, syncError
    workOrderCreated, workOrderCreatedAt, workOrderCreatedByUid
    workCompleted, workCompletedAt, workCompletedByUid

El lector acepta documentos historicos y nuevos. provider sera cloudinary.

## leak_reports

Coleccion separada para fugas de planta:

    sectionId, sectionNameSnapshot
    equipmentName, equipmentNameNormalized
    leakType: steam | oil | water | air
    leakTypeNameSnapshot, tagNumber
    photoUrl, photoPublicId, photoProvider: cloudinary
    workOrderCreated, workOrderCreatedAt, workOrderCreatedByUid
    workCompleted, workCompletedAt, workCompletedByUid
    status: open | work_order_created | completed

El reporte se crea solo despues de revisar y confirmar. Todos los operadores
autenticados pueden consultar fugas y tuberias y actualizar exclusivamente el
flujo de mantenimiento.

## boiler_consumption_readings

Se conserva la coleccion existente.

Historico:

    boilerName, fuelTotal, waterTotal, steamTotal, operatorPin,
    fuelConsumption, waterConsumption, steamConsumption,
    recordedAt ISO, createdAt ISO

operatorPin queda obsoleto y nunca se escribe en datos nuevos.

Nuevo:

    boilerId, boilerNameSnapshot
    recordedAt, intervalStart, intervalEnd: Timestamp
    readingMode: cumulative_meter
    waterValue, waterUnit
    bunkerValue, bunkerUnit
    steamValue, steamUnit
    boilerPressurePsi, boilerPressureUnit: psi
    waterIntervalConsumption, bunkerIntervalConsumption,
    steamIntervalConsumption
    revision, replacesRecordId, rootRecordId
    validationWarnings
    coverageStatus: complete | partial | missing

Las unidades normalizadas de agua y bunker son `gal`. El vapor de Alfa Laval
se registra en `kg`; Distral 900 y Cleaver Brooks no solicitan vapor.
Desde `schemaVersion: 2`, cada lectura nueva incluye la presion de la caldera
en PSI. Las reglas aceptan documentos historicos de esquema 1 sin presion para
mantener compatibilidad, pero exigen un valor numerico no negativo en esquema 2.
La interfaz solo permite crear lecturas acumuladas. Los documentos historicos
con `interval_consumption` se conservan y siguen siendo interpretados por los
lectores para no alterar datos previos.

ID base: boilerId mas intervalStart UTC en formato YYYYMMDDHH. Las revisiones
se versionan transaccionalmente y nunca eliminan la anterior.

## steam_pressure_readings

Lecturas de presion de distribuidores registradas desde la segunda pestana del
modulo de consumos:

    id
    recordedAt: Timestamp
    pressureUnit: psi
    cleaverDistributorPsi:
      omega, lambda, omicron, beta, hydrogenation
    distral900DistributorPsi:
      soapPlant, desmetTirtioux, newLine, cleaverInlet, bleachers,
      marino, padLoading, receptionTanks, waterTank4
    sectionId: servicios_industriales
    sectionNameSnapshot: Servicios Industriales
    equipmentName: Distribuidores de vapor
    createdAt, updatedAt: server timestamp
    createdByUid, updatedByUid
    createdByNameSnapshot
    appVersion
    platform
    schemaVersion: 1
    status: synced
    source: manual

Los catorce valores son obligatorios, numericos y mayores o iguales a cero.
Cada registro usa un ID unico y se confirma con lectura desde servidor antes de
informar al operador que fue guardado en la nube.

## users

Documento users/{uid}:

    id: uid
    displayName
    nationalId
    role: operator | admin
    active
    createdAt
    updatedAt
    schemaVersion

No contiene PIN. La cedula se conserva como texto, pero no se usa como ID del
documento. Registro publico nunca asigna admin.

## user_private_credentials

Coleccion reservada y bloqueada por reglas. La arquitectura Spark actual no la
utiliza; las credenciales viven exclusivamente en Firebase Authentication.

## audit_logs

Solo backend para eventos sensibles:

    eventType, actorUid, actorRole, targetCollection, targetDocumentId,
    occurredAt, appVersion, platform, metadata

No almacenar PIN, cedula completa ni tokens.

## pump_energy_surveys

Campos consultables:

    assetId, interventionId, surveyType, baselineSurveyId
    nominalPowerHp, phaseCount
    estimatedInputPowerKw, measuredInputPowerKw, estimatedShaftPowerKw
    dailyEnergyKwh, annualEnergyKwh
    confidenceLevel
    candidateForHydraulicReview

Objetos:

- identification: tag, servicio, marca, modelo, rpm, frecuencia, polos, arranque.
- electricalInputs: tension nominal, tension medida opcional, fuente de
  tension, corriente promedio, FP, kW, eficiencia, frecuencia, metodo e
  instrumento.
- operatingInputs: horas de trabajo diario.
- results: potencia, energia, carga y desequilibrios.
- assumptions: FP, eficiencia, carga, fuentes y version.
- warnings.
- photo: provider cloudinary, url y publicId.

candidateForHydraulicReview nunca equivale a sobredimensionamiento confirmado.
Los levantamientos `post_improvement` y `verification` reutilizan `assetId` y
guardan `baselineSurveyId` del levantamiento `baseline` seleccionado.

## motor_reference_tables

Tabla administrable: powerHp, poles, ieClass, efficiency,
typicalPowerFactor, source, effectiveFrom, version y active.

## app_config

Se conserva mobile_app para version, build, mensaje, URL, actualizacion forzada
y canal. Supuestos tecnicos/configuracion de calderas iran en documentos
separados y sin secretos.

## Indices previstos

- Trampas: createdAt+sectionId, createdAt+applicationTypeId,
  createdAt+createdByUid.
- Tuberia: createdAt+sectionId, sectionId+heatLossKw.
- Fugas: createdAt+sectionId, createdAt+leakType.
- Calderas: boilerId+recordedAt, boilerId+intervalStart+revision.
- Bombas: createdAt+sectionId, sectionId+surveyType,
  assetId+surveyType+createdAt.

firestore.indexes.json se ajustara contra consultas reales.

## Compatibilidad

- No se cambian IDs ni colecciones existentes.
- Lectores aceptan textos ISO historicos y Timestamp nuevos.
- Campos historicos siguen legibles hasta una migracion administrativa.
- Datos nuevos nunca escriben operatorPin.
- No hay migraciones remotas automaticas desde la app.
