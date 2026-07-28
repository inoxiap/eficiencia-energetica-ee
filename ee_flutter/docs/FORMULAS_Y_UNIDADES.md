# Formulas y unidades

## Trampas

Version: trap-sizing-v1.

- Directo: condensado kg/h = L/min x 1.0 kg/L x 60.
- Lotes: masa x Cp x delta T / calor latente / tiempo.
- Intercambiador: caudal masico x Cp x delta T / calor latente.
- Distribuidor principal: maximo de 12 % del agua y perdida superficial.
- Distribuidor secundario: capacidad estimada x 1 % ajustada por presion,
  comparada con perdida superficial.
- Linea principal: perdida superficial / calor latente.
- Factor de seguridad: 1.2.

Constantes actuales: densidad aceite 0.89 kg/L, Cp 2.0 kJ/(kg C), densidad de
condensado 1.0 kg/L. Las ocho rutas tienen pruebas de regresion numerica.

## Tuberia desnuda

Version: bare-pipe-v1.

Se conserva la combinacion de conveccion natural y radiacion. Resultados:

- W/m: perdida lineal.
- kW: potencia termica.
- kWh/mes: energia, usando 24 h/dia y 30 dias/mes.
- gal/mes y USD/mes: estimaciones con PCI, eficiencia y precio documentados.

No se convierte kW a kWh sin horas explicitas.

## Calderas

- cumulative_meter: consumo = lectura actual - lectura anterior.
- interval_consumption: el valor ingresado ya es consumo.
- Deltas negativos o reinicios producen valor nulo y advertencia.
- Lecturas brutas siempre se conservan.

Las lecturas acumuladas no se suman; el consumo usa deltas consecutivos
validados. La presion de caldera se captura en PSI y no participa en el calculo
del delta.

Para Alfa Laval, la interfaz usa las unidades que ve el usuario en los
contadores:

- Bunker: litros. El valor normalizado se guarda en galones como
  `gal = litros / 3.79`.
- Agua: unidades del contador, donde cada unidad representa 10 litros. El valor
  normalizado se guarda como `gal = unidades x 2.64`.
- Vapor: kilogramos (`kg`), sin conversion adicional.

La equivalencia fisica exacta es 1 galon estadounidense =
3.785411784 litros; por eso 10 litros equivalen a 2.64172 galones. La app usa
los factores operativos redondeados 3.79 y 2.64 confirmados para los medidores
de planta. Guarda tanto el valor original y su unidad como el valor normalizado
de bunker y agua en galones. El vapor conserva el valor acumulado original en
kilogramos. Distral 900 y Cleaver Brooks mantienen sus lecturas habilitadas en
galones y no solicitan vapor.

### Advertencias de rango historico

Las advertencias se calculan sobre el delta normalizado por las horas reales
transcurridas desde la lectura anterior, nunca sobre el total acumulado del
contador. El operador puede continuar despues de una segunda confirmacion; no
se bloquean condiciones extraordinarias reales.

La referencia `regist_inform_p99_2026_07_23_v1` se obtuvo de las filas
historicas de `Regist_inform` anteriores al uso de la app. Se tomo el percentil
99 de consumo por hora y se agrego un margen del 25 %, redondeado hacia arriba:

| Caldera | Bunker, advertir sobre | Agua, advertir sobre |
| --- | ---: | ---: |
| Alfa Laval | 380 gal/h | 6600 gal/h |
| Cleaver Brooks | 415 gal/h | 5750 gal/h |
| Distral 900 | 345 gal/h | 4700 gal/h |

Los saltos de prueba de Alfa Laval observados el 24 y 26 de julio de 2026
superan ampliamente estos valores y se consideran datos de prueba. Los limites
son configuraciones de advertencia iniciales y deben revisarse con Operaciones
si cambia un medidor, combustible o regimen de trabajo.

Para el Excel auxiliar, un delta medido entre horas irregulares se distribuye
entre horas cerradas segun el tiempo de solapamiento:

    consumo_hora = delta_intervalo
                   x horas_solapadas / horas_intervalo

La suma de las asignaciones horarias conserva exactamente el delta original.
Los totales diarios se forman con esas asignaciones para dividir correctamente
un intervalo que cruce la medianoche. Los deltas de bunker y agua solo se
procesan en registros `cumulative_meter` normalizados a `gal`. El vapor se
conserva en `kg` dentro de los datos crudos.

El resumen compatible con `Regist_inform` usa provisionalmente:

- Presion: promedio aritmetico de las lecturas del dia y caldera.
- Minutos de paro: 0.
- Horas optimas: 24.
- Tiempo real: 24.
- Eficiencia: 1.
- Alcance: 0.98.
- Ton/Agua: agua gal x 3.785 / 1000.
- galones/m3: bunker gal / Ton/Agua.

Los supuestos operativos quedan visibles en la hoja `Control` y deben
revalidarse cuando existan datos de paro y disponibilidad.

## Bombas

Version: pump-energy-v1.

Prioridad:

1. kW activo medido.
2. Trifasico: sqrt(3) x V linea x I promedio x FP / 1000.
3. Monofasico: V x I x FP / 1000.
4. Sin medicion: HP x 0.746 x factor de carga / eficiencia.

La interfaz usa la tension nominal seleccionada cuando no se abre el campo
puntual de tension medida. Cada levantamiento guarda `voltageSource` como
`nominal` o `measured`, ademas del valor original medido cuando exista.

Potencia mecanica: kW entrada x eficiencia.

Energia:

- kWh/dia = kW x horas/dia.
- kWh/ano = kWh/dia x dias/ano.

Desequilibrio = maxima desviacion respecto al promedio / promedio x 100.

Confianza:

- Alta: kW medido.
- Media: V, I y FP medidos.
- Baja: FP, eficiencia o carga asumidos.

La eficiencia y FP de respaldo provienen de tablas internas por banda de HP,
con fuente almacenada. motor_reference_tables permite sustituirlas por tablas
administrables por HP, polos e IE.

Una carga electrica baja solo genera candidateForHydraulicReview. No confirma
sobredimensionamiento.
