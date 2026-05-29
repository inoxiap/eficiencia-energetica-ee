# Eficiencia Energetica EE

Aplicacion movil/web para herramientas de campo orientadas a eficiencia energetica. Incluye dimensionamiento preliminar de trampas de condensado por uso y reporte de tuberia desnuda con evidencia fotografica. La version web/PWA permite registrar reportes y ver un panel local con calor y dinero perdido estimado.

## Estado actual

- Splash de 1 segundo con logo sobre fondo de marca.
- Pantalla principal general de Eficiencia Energetica EE.
- Modulo inicial "Dimensionamiento de trampas" con selector de uso, sin seleccion por defecto.
- Modulo "Reporte de tuberia desnuda" con captura/subida de evidencia a Cloudinary.
- Panel administrador local, sin clave por ahora, con acumulados y graficas por seccion.
- Tipo de trampa recomendado, condicion tipica y observaciones cargadas automaticamente.
- Rueda numerica para ingresar el caudal de condensado conocido en L/min.
- Casilla "No conozco la cantidad de condensado" para cambiar a calculo indirecto.
- Calculo de carga de condensado directa o estimada, sin permitir ambos modos a la vez.
- Resumen con tipo de trampa, carga estimada, factor de seguridad, capacidad minima sugerida y diametro preliminar.

## Reporte de tuberia desnuda

La PWA usa el preset unsigned de Cloudinary `ee_evidencias_unsigned` del cloud `dovufh5wv` para subir la foto de evidencia desde el navegador. Los reportes se guardan temporalmente en `localStorage` bajo la clave `eeBarePipeReports`; el siguiente paso natural sera sincronizarlos con Firebase cuando definamos usuarios y base de datos.

Campos del reporte:

- Foto de evidencia, requerida para ingresar el reporte.
- Seccion: jaboneria, margarina, calderas, refineria, hidrogenacion, envase o confiteria.
- Diametro de tuberia: 1/2", 3/4", 1", 1 1/4", 1 1/2", 2", 3", 4" o 6".
- Presion estimada de la linea: 0 a 20 bar(g).
- Longitud de tuberia desnuda en metros.

Los datos tecnicos son opcionales. Si faltan diametro, presion o longitud, el reporte queda guardado con el calculo pendiente.

## Panel administrador

El panel administrador suma los reportes locales y muestra:

- Numero de reportes.
- Calor disipado en kW.
- Energia mensual en kWh/mes.
- Dinero perdido en USD/mes.
- Graficas por seccion para calor y dinero perdido.
- Ultimos reportes con miniatura de la evidencia.

## Usos y trampas

| Uso | Tipo de trampa | Condicion |
| --- | --- | --- |
| Tracing | Termodinamica bimetalica | Baja carga |
| Serpentin de tanque | Flotador termostatica | Transferencia de calor |
| Chaqueta o Marmita | Flotador termostatica | Carga variable |
| Chaqueta trabajo pesado | Balde invertido | Drenaje |
| Distribuidor principal de caldero | Balde invertido | Drenaje principal con posible arrastre |
| Distribuidor de vapor | Balde invertido | Drenaje de distribucion secundaria |
| Intercambiador de calor | Flotador termostatica | Alta carga variable |
| Linea principal de vapor (Pierna de condensado) | Balde invertido | Drenaje de linea |

## Campos propuestos para validar

Todos los usos permiten ingresar primero el caudal de condensado conocido en L/min, para que pueda medirse con balde y cronometro. La app lo convierte internamente a kg/h usando densidad aproximada de condensado de 1.0 kg/L. Si se marca "No conozco la cantidad de condensado", la app oculta ese campo y muestra solo los campos indirectos.

El campo "Volumen de aceite o grasa" usa una escala especial: de 100 a 1000 L en pasos de 100 L, de 1000 a 10000 L en pasos de 500 L, de 10000 a 50000 L en pasos de 5000 L, y de 50000 a 1000000 L en pasos de 10000 L.

El campo "Tiempo de calentamiento" tambien usa escala por tramos: hasta 60 min en pasos de 5 min, de 1.5 h a 6 h en pasos de 30 min, y de 7 h a 48 h en pasos de 1 h. La app calcula internamente en minutos, aunque la rueda muestre horas.

| Uso | Campos indirectos |
| --- | --- |
| Tracing | Sin campos; seleccion directa de trampa termodinamica bimetalica |
| Serpentin de tanque | Volumen de aceite o grasa, temperatura inicial, temperatura final, tiempo de calentamiento, presion de vapor |
| Chaqueta o Marmita | Volumen de aceite o grasa, temperatura inicial, temperatura final, tiempo de calentamiento, presion de vapor |
| Chaqueta trabajo pesado | Volumen de aceite o grasa, temperatura inicial, temperatura final, tiempo de calentamiento, presion de vapor |
| Distribuidor principal de caldero | Agua consumida por caldero, diametro del distribuidor, largo del distribuidor, presion del distribuidor |
| Distribuidor de vapor | Presion del caldero, presion del distribuidor, diametro del distribuidor, largo del distribuidor |
| Intercambiador de calor | Caudal de aceite o grasa en m3/h, temperatura de entrada, temperatura de salida, presion de vapor |
| Linea principal de vapor | Presion de vapor, diametro de linea principal, longitud entre drenajes |

## Hipotesis actuales

- El calculo es preliminar para dimensionamiento inicial, no reemplaza una tabla de fabricante.
- Se aplica factor de seguridad fijo de 1.2.
- El condensado medido directamente se ingresa en L/min y se convierte a kg/h con densidad aproximada de 1.0 kg/L.
- Para calentamiento de aceite de palma se usa calor especifico fijo de 2.0 kJ/kg C.
- Para convertir volumen/caudal de aceite de palma a masa se usa densidad fija de 0.89 kg/L.
- El calor latente y la temperatura de saturacion del vapor se interpolan desde una tabla interna para 1 a 15 bar(g).
- Para linea principal se estima condensado por perdidas termicas de operacion en el tramo entre drenajes.
- Para distribuidor principal de caldero se usa una constante interna conservadora de 12% sobre el agua consumida por el caldero y se compara contra la perdida superficial del distribuidor.
- Para distribuidor de vapor secundario se estima una capacidad probable de vapor por diametro, presion y velocidad de referencia; luego se toma 1% como drenaje tipico de linea y se compara contra la perdida superficial.
- La base tecnica y fuentes estan documentadas en `docs/base-tecnica.md`.

## Compilar

```powershell
.\gradlew.bat :app:assembleDebug
```

APK generado:

```text
app/build/outputs/apk/debug/app-debug.apk
```

## Version web/PWA

La version web esta en:

```text
web/
```

Para probarla localmente:

```powershell
node web/server.cjs
```

Abrir:

```text
http://localhost:4173
```

En iPhone se puede abrir desde Safari y usar "Agregar a pantalla de inicio".
