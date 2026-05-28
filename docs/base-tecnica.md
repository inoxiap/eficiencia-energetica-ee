# Base tecnica de calculo

Esta nota resume la base usada por la app para estimar condensado cuando el operador no conoce el caudal directo.

## Principio general

La carga de condensado se calcula como:

```text
condensado_kg_h = carga_termica_kJ_h / calor_latente_vapor_kJ_kg
```

La app interpola temperatura de saturacion y calor latente del vapor para presiones entre 1 y 15 bar(g). La tabla interna evita usar una recta simple de presion contra calor latente.

## Medicion directa con balde

Cuando el operador conoce el caudal de condensado, la entrada directa se hace en L/min. La app convierte ese dato a kg/h para compararlo con capacidades de trampas:

```text
condensado_kg_h = caudal_L_min * 1.0 kg/L * 60
```

Se usa densidad aproximada de condensado de 1.0 kg/L. Esta aproximacion es suficiente para una seleccion preliminar de campo; si luego se desea mayor precision, se puede corregir por temperatura del condensado.

## Aceite de palma

Para no pedir datos que el operador no conoce, la app usa constantes internas:

```text
Cp aceite de palma = 2.0 kJ/kg C
densidad aceite de palma = 0.89 kg/L
```

La referencia de palm olein reporta Cp = 1.9 kJ/kg C y densidad = 0.912 g/cm3 a 15 C. El valor 2.0 kJ/kg C es una base redondeada y practica para campo.

## Chaqueta, marmita o serpentin de tanque

El operador ingresa "Volumen de aceite o grasa". Para mantener la captura rapida en campo, la rueda usa pasos variables: 100 L hasta 1000 L, 500 L hasta 10000 L, 5000 L hasta 50000 L y 10000 L hasta 1000000 L.

El tiempo de calentamiento tambien se captura con pasos variables: 5 min hasta 60 min, 30 min desde 1.5 h hasta 6 h, y 1 h desde 7 h hasta 48 h. Internamente todos esos valores se convierten a minutos para aplicar la formula.

Base:

```text
masa_kg = volumen_L * densidad_kg_L
carga_termica_kJ = masa_kg * Cp * (T_final - T_inicial)
condensado_kg_h = carga_termica_kJ / calor_latente_kJ_kg * (60 / tiempo_min)
```

Equivale a la formula de calentamiento de liquidos en marmitas, tanques con chaqueta o serpentines de tanque: volumen, gravedad especifica, Cp, aumento de temperatura, calor latente y tiempo.

## Intercambiador de calor

Base:

```text
caudal_masico_kg_h = caudal_m3_h * 1000 L/m3 * densidad_kg_L
carga_termica_kJ_h = caudal_masico_kg_h * Cp * (T_salida - T_entrada)
condensado_kg_h = carga_termica_kJ_h / calor_latente_kJ_kg
```

Es el mismo balance de energia, pero continuo. La entrada se expresa en m3/h porque suele coincidir con la capacidad nominal de bomba conocida por operadores.

## Tracing

En esta etapa la app no dimensiona carga para tracing. Por criterio operativo del proyecto, al seleccionar Tracing se recomienda directamente trampa termodinamica bimetalica y no se piden parametros adicionales.

## Distribuidor principal de caldero

El distribuidor principal de caldero se separa del resto porque ahi si puede tener sentido comparar contra el agua consumida por el caldero. Si el caldero consume 19 m3/h de agua y el proveedor asumio 12% como condensado/humedad/arrastre:

```text
19 m3/h * 1000 kg/m3 * 0.12 = 2280 kg/h ~= 2280 L/h
```

Ese calculo reproduce la magnitud de 2000 L/h mencionada por el proveedor. Importante: 12% no se debe documentar como buena practica universal de calidad de vapor. Las referencias tecnicas definen la calidad de vapor como fraccion seca; por ejemplo, 99% de calidad contiene 1% de agua liquida y algunos fabricantes consideran vapor saturado de alta calidad alrededor de 99.5% seco. Por eso, en la app el 12% queda como una constante interna conservadora de planta para el distribuidor principal, no como valor normal de caldera.

Base usada por la app:

```text
condensado_arrastre_kg_h = agua_caldero_m3_h * 1000 kg/m3 * 12 / 100
```

Como respaldo, con los datos de geometria se estima la carga de operacion por perdida termica superficial:

```text
area_m2 = pi * diametro_m * longitud_m
perdida_W = area_m2 * U * (T_saturacion_vapor - T_ambiente)
condensado_superficie_kg_h = perdida_W * 3.6 / calor_latente_kJ_kg
condensado_kg_h = max(condensado_arrastre_kg_h, condensado_superficie_kg_h)
```

Supuestos internos:

```text
T_ambiente = 30 C
U = 11.36 W/m2 C
factor_principal_caldero = 12%
```

Ese U equivale aproximadamente a 2 Btu/h ft2 F, usado como coeficiente de conveccion libre en formulas de cargas de condensado por radiacion/superficie. Si despues definimos que todas las lineas estan aisladas, conviene agregar un selector o usar una constante mas baja.

## Distribuidor de vapor secundario

Para un distribuidor que no es el principal del caldero, el consumo total de agua del caldero no es proporcional al vapor que realmente pasa por ese ramal. La presion del caldero y la presion del distribuidor ayudan a tener una idea del nivel energetico, pero no determinan por si solas el caudal real; para eso haria falta caudalimetro, consumo de equipos conectados, Cv de valvulas, orificios o calculo de red.

Como estimacion preliminar, la app usa dos referencias:

- Spirax Sarco indica que en drenaje de mains la carga por trampa suele tomarse como 1% de la capacidad de vapor de la linea, con drenajes cada 50 m y buena aislacion.
- Para headers/distribuidores, Spirax Sarco indica velocidad de diseno de 10 a 15 m/s para la maxima carga entrante. La app usa 10 m/s como referencia conservadora baja.

Base usada por la app:

```text
densidad_vapor_kg_m3 ~= P_abs / (R_vapor * T_sat_K)
capacidad_vapor_kg_h = area_interna_m2 * 10 m/s * densidad_vapor_kg_m3 * 3600
fraccion_presion = limitar(P_abs_distribuidor / P_abs_caldero, 0.25, 1.0)
condensado_drenaje_kg_h = capacidad_vapor_kg_h * 1% * fraccion_presion
condensado_kg_h = max(condensado_drenaje_kg_h, condensado_superficie_kg_h)
```

Esta estimacion es deliberadamente preliminar. Si se conoce el caudal real del ramal o se mide condensado con balde, ese dato debe reemplazar la estimacion indirecta.

## Linea principal de vapor

Para linea principal entre drenajes, la app conserva la estimacion por perdida termica superficial del tramo:

```text
area_m2 = pi * diametro_m * longitud_m
perdida_W = area_m2 * U * (T_saturacion_vapor - T_ambiente)
condensado_kg_h = perdida_W * 3.6 / calor_latente_kJ_kg
```

## Capacidad de descarga de trampas

No existe una capacidad unica por diametro de conexion. La descarga depende de:

- Tipo de trampa.
- Modelo.
- Diametro de conexion.
- Orificio/asiento interno.
- Presion diferencial real entre entrada y salida.
- Contrapresion en retorno.

Ejemplos de catalogo muestran la variacion:

- Armstrong 800 Series: modelos con conexion 1/2 a 3/4 pulg pueden ir desde 318 kg/h hasta 998 kg/h segun modelo; modelos 3/4 a 1 pulg pueden llegar a 1996 kg/h.
- Armstrong BVSW drain traps: algunos modelos 1/2, 3/4 y 1 pulg declaran hasta 3175 kg/h.
- Watson McDaniel IB Series: el catalogo indica que la capacidad se selecciona por presion diferencial y muestra que modelos 1/2 a 3/4 pulg pueden ir desde cientos hasta mas de 2000 lb/h dependiendo de orificio y PMO.

Por eso la app no debe concluir capacidad solo con "1/2 pulg" o "3/4 pulg"; debe comparar la carga requerida contra tabla de fabricante y presion diferencial.

## Diametro preliminar de conexion

La app agrega un diametro preliminar de conexion usando la capacidad minima sugerida despues del factor de seguridad. La tabla usada es una guia inicial de campo:

| Capacidad requerida | Diametro preliminar |
| --- | --- |
| Hasta 200 kg/h | 1/2 pulg (15 mm) |
| 200 a 500 kg/h | 3/4 pulg (20 mm) |
| 500 a 1000 kg/h | 1 pulg (25 mm) |
| 1000 a 2000 kg/h | 1-1/4 pulg (32 mm) |
| 2000 a 3000 kg/h | 1-1/2 pulg (40 mm) |
| 3000 a 5000 kg/h | 2 pulg (50 mm) |
| Mayor a 5000 kg/h | 2-1/2 a 4 pulg o trampas en paralelo |

Esta tabla se basa en una guia TLV de diametro de tuberia/salida por carga maxima de condensado. Para seleccion final, se debe validar el modelo de trampa, orificio, presion diferencial minima y contrapresion.

## Factor de seguridad

La app aplica un factor de seguridad fijo de 1.2 sobre la carga calculada, por criterio del proyecto. Para seleccion final, todavia se debe validar contra presion diferencial, contrapresion, orificio interno y tabla del fabricante.

## Fuentes iniciales

- Spirax Sarco, "Calculating Condensate Loads", TI-S99-09-US.
  https://content.spiraxsarco.com/-/media/spiraxsarco/international/documents/us/ti/condensate-loads-ti-s99-09-us.ashx
- Spirax Sarco, "Sizing Condensate Return Lines".
  https://www.spiraxsarco.com/Learn-about-steam/Condensate-Recovery/Sizing-Condensate-Return-Lines
- Spirax Sarco, "Selecting Steam Traps - Steam Mains, Tanks and Vats, Pressure Reducing Valves".
  https://www.spiraxsarco.com/learn-about-steam/steam-traps-and-steam-trapping/selecting-steam-traps---steam-mains-tanks-and-vats-pressure-reducing-valves
- TLV, "Condensate Load" calculators and saturated steam table tools.
  https://toolbox.tlv.com/global/TI/
- Veolia Water Technologies, "Water Handbook - Steam Purity".
  https://www.watertechnologies.com/handbook/chapter-16-steam-purity
- HPAC Engineering, "Effective Boiler-Level Control".
  https://www.hpac.com/heating/article/20925317/effective-boiler-level-control
- Sadiq et al., "An Experimental Investigation of Static Properties of Bio-Oils and SAE40 Oil in Journal Bearing Applications", Materials, 2022.
  https://www.mdpi.com/1996-1944/15/6/2247
