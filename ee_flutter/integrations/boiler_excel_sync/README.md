# Sincronizacion de consumos de calderas

Esta integracion mantiene actualizado el mismo archivo corporativo
`REPORTE DE CALDERAS 2018.xlsx`, aun cuando la laptop de Jeff este apagada.
Firestore conserva la fuente oficial de los datos.

## Arquitectura sin conectores Premium

1. Un workflow del repositorio privado se ejecuta cada hora, descarga el codigo
   publico de la aplicacion y lee `boiler_consumption_readings` desde Firestore.
2. `exporter.py` conserva revisiones, calcula deltas validos, reparte consumos
   por hora cerrada y genera el resumen diario.
3. El workflow publica un JSON incremental en el cuerpo de un issue de un
   repositorio GitHub privado dedicado exclusivamente al transporte.
4. Un flujo programado de Power Automate usa el conector estandar de GitHub
   para leer ese issue.
5. La accion estandar `Excel Online (Business) / Run script` entrega el JSON al
   Office Script `EE - Sincronizar consumos de calderas`.
6. El script actualiza el libro maestro por claves estables, sin duplicar filas
   y sin reemplazar el historial existente.

Se descarto el disparador HTTP de Power Automate porque requiere licencia
Premium. Tambien se descarto guardar el payload en el repositorio publico del
codigo: los datos operativos solo pueden viajar por el repositorio privado.

## Hojas administradas en el maestro

- `App_Datos_Firestore`: documentos originales y revisiones.
- `App_Intervalos`: diferencias validas entre lecturas acumuladas.
- `App_Consumo_Horario`: reparto proporcional entre horas cerradas.
- `App_Resumen_Diario`: una fila por fecha y caldera, compatible con A:P.
- `App_Mapeo_Regist`: relacion entre cada clave diaria y su fila administrada
  en `Regist_inform`.
- `App_Control`: fecha de sincronizacion, conteos, conflictos y estado.

`Regist_inform` se actualiza para `CalAlfa`, `CalCleaver` y `900Distral`. Si una
fila historica no administrada ya ocupa la misma fecha/caldera, el script la
registra como conflicto y no la sobrescribe.

La sincronizacion es incremental e idempotente:

- Una clave nueva crea una fila.
- Una clave ya conocida actualiza su fila.
- Ejecutar dos veces el mismo payload no crea duplicados.
- Las hojas `App_*` acumulan el historial recibido.

## Ejecucion local

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python exporter.py --output DATOS_CALDERAS_APP_AUXILIAR.xlsx --skip-publish
```

Para probar sin Firebase:

```powershell
python exporter.py --input-json datos.json --output salida.xlsx --skip-publish
```

El libro auxiliar es solo diagnostico local; el proceso en nube modifica el
maestro mediante el Office Script.

## Repositorio privado y GitHub Actions

El archivo `private_repo_workflow.yml` es la plantilla que debe guardarse como
`.github/workflows/sync-boiler-excel.yml` dentro del repositorio privado.

El unico `Actions secret` requerido es:

- `FIREBASE_SERVICE_ACCOUNT_JSON`: cuenta de servicio con lectura de
  Firestore.

El workflow usa `${{ github.token }}` para actualizar el issue de su mismo
repositorio. No requiere token personal. El permiso queda limitado a
`contents: read` e `issues: write`.

No guardar la cuenta de servicio en Git. El repositorio privado y el issue deben
existir antes de ejecutar el workflow.

## Configuracion de Power Automate

Flujo programado cada hora:

1. `Recurrence`.
2. `GitHub / Get a particular issue of a repository`.
3. `Excel Online (Business) / Run script`.
4. Archivo:
   `/MEJORAS/1. SEGUIMIENTO DE LA ENERGIA/REPORTE DE CALDERAS 2018.xlsx`.
5. Script: `EE - Sincronizar consumos de calderas`.
6. Parametro `payloadJson`: cuerpo del issue obtenido en el paso 2.

La cuenta Microsoft usada es `Asistente Proyectos Mantenimiento`. El libro debe
estar cerrado en Excel de escritorio durante la primera prueba integral para
evitar un bloqueo de edicion.

## Supuestos pendientes de validacion

- Presion diaria: promedio aritmetico de lecturas del dia.
- Minutos de paro: 0.
- Horas optimas: 24.
- Tiempo real: 24.
- Eficiencia: 1.
- Alcance: 0.98.

Los supuestos quedan visibles en `App_Control` y pueden ajustarse cuando
Operaciones entregue datos de paro y disponibilidad.
