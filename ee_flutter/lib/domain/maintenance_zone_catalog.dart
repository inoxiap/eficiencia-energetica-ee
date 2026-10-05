class MaintenanceZone {
  const MaintenanceZone({
    required this.number,
    required this.section,
    required this.process,
    required this.responsibles,
  });

  final int number;
  final String section;
  final String process;
  final List<String> responsibles;

  String get label => 'Zona $number - $section - $process';
}

const maintenanceZones = <MaintenanceZone>[
  MaintenanceZone(
    number: 1,
    section: 'Refinería',
    process: 'Almacenamiento RB',
    responsibles: ['Rodis Valdéz', 'Edwin Aimacaña'],
  ),
  MaintenanceZone(
    number: 2,
    section: 'Refinería',
    process: 'Servicios Refinería',
    responsibles: ['Edgar Rumipamba', 'Edwin Aimacaña'],
  ),
  MaintenanceZone(
    number: 3,
    section: 'Refinería',
    process: 'Blanqueo',
    responsibles: ['Darwin Guallichico', 'Luís Taipe'],
  ),
  MaintenanceZone(
    number: 4,
    section: 'Refinería',
    process: 'Neutralización',
    responsibles: ['Vinicio Portilla', 'Luís Taipe'],
  ),
  MaintenanceZone(
    number: 5,
    section: 'Refinería',
    process: 'Marino',
    responsibles: ['Angel Sivinta', 'Franklin Toapanta'],
  ),
  MaintenanceZone(
    number: 6,
    section: 'Refinería',
    process: 'Filtración',
    responsibles: ['Jonathan Rodriguez', 'Franklin Toapanta'],
  ),
  MaintenanceZone(
    number: 7,
    section: 'Refinería',
    process: 'Blanqueo Lambda',
    responsibles: ['Victor Torres', 'Henry Suntaxi'],
  ),
  MaintenanceZone(
    number: 8,
    section: 'Refinería',
    process: 'Blanqueo Gianazza',
    responsibles: ['Angel Sivinta', 'Henry Suntaxi'],
  ),
  MaintenanceZone(
    number: 9,
    section: 'Refinería',
    process: 'Refinación Soya',
    responsibles: ['Gustavo Herrera', 'Kevin Changoluisa'],
  ),
  MaintenanceZone(
    number: 10,
    section: 'Refinería',
    process: 'Blanqueo Omicron',
    responsibles: ['Pablo Mafla', 'Kevin Changoluisa'],
  ),
  MaintenanceZone(
    number: 11,
    section: 'Desodorización',
    process: 'Almacenamiento RBD',
    responsibles: ['Rodis Valdéz', 'Mario Mora'],
  ),
  MaintenanceZone(
    number: 12,
    section: 'Desodorización',
    process: 'Servicios Desodorización',
    responsibles: ['Marco Montatixe', 'Mario Mora'],
  ),
  MaintenanceZone(
    number: 13,
    section: 'Desodorización',
    process: 'Torre Delta',
    responsibles: ['Gustavo Herrera'],
  ),
  MaintenanceZone(
    number: 14,
    section: 'Desodorización',
    process: 'Torre Alfa',
    responsibles: ['Pablo Mafla', 'Vianka Condor'],
  ),
  MaintenanceZone(
    number: 15,
    section: 'Desodorización',
    process: 'Torre Gama',
    responsibles: ['Vinicio Portilla'],
  ),
  MaintenanceZone(
    number: 16,
    section: 'Desodorización',
    process: 'Torre Beta',
    responsibles: ['Darwin Guallichico', 'Vianka Condor'],
  ),
  MaintenanceZone(
    number: 17,
    section: 'Desodorización',
    process: 'Torre Omega',
    responsibles: ['Victor Torres', 'Eduardo Suquillo'],
  ),
  MaintenanceZone(
    number: 18,
    section: 'Fraccionamiento',
    process: 'Almacenamiento',
    responsibles: ['Rodis Valdéz', 'Eduardo Suquillo'],
  ),
  MaintenanceZone(
    number: 19,
    section: 'Fraccionamiento',
    process: 'Servicios Fraccionamiento',
    responsibles: ['Carlos Vega', 'Jorge Carrillo'],
  ),
  MaintenanceZone(
    number: 20,
    section: 'Fraccionamiento',
    process: 'Tirtiaux',
    responsibles: ['Pablo Mafla', 'Jorge Carrillo'],
  ),
  MaintenanceZone(
    number: 21,
    section: 'Fraccionamiento',
    process: 'Desmet',
    responsibles: ['Darwin Guallichico', 'Ruben Pinargote'],
  ),
  MaintenanceZone(
    number: 22,
    section: 'Fraccionamiento',
    process: 'Lipico',
    responsibles: ['Victor Torres', 'Ruben Pinargote'],
  ),
  MaintenanceZone(
    number: 23,
    section: 'Fraccionamiento',
    process: 'Chocolatera',
    responsibles: ['Vinicio Portilla', 'Diego Toapanta'],
  ),
  MaintenanceZone(
    number: 24,
    section: 'Fraccionamiento',
    process: 'Winterización de girasol',
    responsibles: ['Vinicio Portilla', 'Diego Toapanta'],
  ),
  MaintenanceZone(
    number: 25,
    section: 'Hidrogenación',
    process: 'Almacenamiento hidrogenados',
    responsibles: ['Kevin Zambrano'],
  ),
  MaintenanceZone(
    number: 26,
    section: 'Hidrogenación',
    process: 'Servicios hidrogenación',
    responsibles: ['Angel Sivinta', 'Carlos Vega', 'Diego Toapanta'],
  ),
  MaintenanceZone(
    number: 27,
    section: 'Hidrogenación',
    process: 'Generación hidrógeno',
    responsibles: ['Gustavo Herrera'],
  ),
  MaintenanceZone(
    number: 28,
    section: 'Hidrogenación',
    process: 'Autoclaves',
    responsibles: ['Pablo Mafla', 'Diego Toapanta'],
  ),
  MaintenanceZone(
    number: 29,
    section: 'Recepción',
    process: 'Almacenamiento recepción',
    responsibles: ['Rodis Valdéz', 'Edwin Aimacaña'],
  ),
  MaintenanceZone(
    number: 30,
    section: 'Recepción',
    process: 'Servicios recepción',
    responsibles: ['Jonathan Rodriguez', 'Edwin Aimacaña'],
  ),
  MaintenanceZone(
    number: 31,
    section: 'Recepción',
    process: 'Descargadero',
    responsibles: ['Kevin Zambrano', 'Ruben Pinargote'],
  ),
  MaintenanceZone(
    number: 32,
    section: 'Servicios Industriales',
    process: 'Agua industrial',
    responsibles: ['Vinicio Portilla', 'Luís Taipe'],
  ),
  MaintenanceZone(
    number: 33,
    section: 'Servicios Industriales',
    process: 'Agua potable',
    responsibles: ['Victor Torres', 'Luís Taipe'],
  ),
  MaintenanceZone(
    number: 34,
    section: 'Servicios Industriales',
    process: 'Aire comprimido',
    responsibles: ['Gustavo Herrera', 'Franklin Toapanta'],
  ),
  MaintenanceZone(
    number: 35,
    section: 'Servicios Industriales',
    process: 'Clarificación',
    responsibles: ['Kevin Zambrano'],
  ),
  MaintenanceZone(
    number: 36,
    section: 'Servicios Industriales',
    process: 'Servicio de energía',
    responsibles: ['Edgar Rumipamba'],
  ),
  MaintenanceZone(
    number: 37,
    section: 'Servicios Industriales',
    process: 'Servicio de vapor',
    responsibles: ['Marco Montatixe', 'Franklin Toapanta'],
  ),
  MaintenanceZone(
    number: 38,
    section: 'Servicios Industriales',
    process: 'Torres de enfriamiento',
    responsibles: ['Darwin Guallichico', 'Henry Suntaxi'],
  ),
  MaintenanceZone(
    number: 39,
    section: 'Servicios Industriales',
    process: 'Tratamiento de agua residual 1',
    responsibles: ['Angel Sivinta'],
  ),
  MaintenanceZone(
    number: 40,
    section: 'Servicios Industriales',
    process: 'Tratamiento de agua residual 2',
    responsibles: ['Jonathan Rodriguez'],
  ),
  MaintenanceZone(
    number: 41,
    section: 'Jabonería',
    process: 'Detergente',
    responsibles: ['Jaime Rodriguez'],
  ),
  MaintenanceZone(
    number: 42,
    section: 'Jabonería',
    process: 'Jabón de tocador',
    responsibles: ['Michael Llumiquinga'],
  ),
  MaintenanceZone(
    number: 43,
    section: 'Jabonería',
    process: 'Línea 1',
    responsibles: ['Michael Llumiquinga', 'Ruben Pinargote'],
  ),
  MaintenanceZone(
    number: 44,
    section: 'Jabonería',
    process: 'Línea 2',
    responsibles: ['Michael Llumiquinga', 'Jorge Carrillo'],
  ),
  MaintenanceZone(
    number: 45,
    section: 'Jabonería',
    process: 'Pailas',
    responsibles: ['Michael Llumiquinga', 'Eduardo Suquillo'],
  ),
  MaintenanceZone(
    number: 46,
    section: 'Jabonería',
    process: 'Selladoras de cartón',
    responsibles: ['Jaime Rodriguez'],
  ),
  MaintenanceZone(
    number: 47,
    section: 'Jabonería',
    process: 'Servicios jabonería',
    responsibles: ['Michael Llumiquinga', 'Eduardo Suquillo'],
  ),
  MaintenanceZone(
    number: 48,
    section: 'DEX',
    process: 'Línea 1',
    responsibles: ['Jaime Rodriguez'],
  ),
  MaintenanceZone(
    number: 49,
    section: 'DEX',
    process: 'Línea 2',
    responsibles: ['Jaime Rodriguez'],
  ),
  MaintenanceZone(
    number: 50,
    section: 'DEX',
    process: 'Servicios DEX',
    responsibles: ['Jaime Rodriguez'],
  ),
  MaintenanceZone(
    number: 51,
    section: 'Servicios Industriales',
    process: 'Agua potable Semprebene',
    responsibles: ['Jefferson Zamora'],
  ),
  MaintenanceZone(
    number: 52,
    section: 'Jabón Cálcico',
    process: 'Línea 1',
    responsibles: ['Alex Illapa'],
  ),
  MaintenanceZone(
    number: 53,
    section: 'Jabón Cálcico',
    process: 'Servicios cálcico',
    responsibles: ['Alex Illapa'],
  ),
  MaintenanceZone(
    number: 54,
    section: 'Desinfectante',
    process: 'Cloro desinfectante',
    responsibles: ['Alex Illapa'],
  ),
  MaintenanceZone(
    number: 55,
    section: 'Desinfectante',
    process: 'Jabón líquido',
    responsibles: ['Alex Illapa'],
  ),
  MaintenanceZone(
    number: 56,
    section: 'Desinfectante',
    process: 'Servicios cloro-desinfectante',
    responsibles: ['Alex Illapa'],
  ),
  MaintenanceZone(
    number: 57,
    section: 'Margarina',
    process: 'Almacenamiento MRG',
    responsibles: ['Edgar Ubillus'],
  ),
  MaintenanceZone(
    number: 58,
    section: 'Margarina',
    process: 'Cuartos fríos',
    responsibles: ['David Quiranza'],
  ),
  MaintenanceZone(
    number: 59,
    section: 'Margarina',
    process: 'Empaque',
    responsibles: ['David Quiranza'],
  ),
  MaintenanceZone(
    number: 60,
    section: 'Margarina',
    process: 'Frío por NH3',
    responsibles: ['David Quiranza'],
  ),
  MaintenanceZone(
    number: 61,
    section: 'Margarina',
    process: 'Línea G1',
    responsibles: ['Edgar Ubillus'],
  ),
  MaintenanceZone(
    number: 62,
    section: 'Margarina',
    process: 'Línea G2 y G3',
    responsibles: ['Edgar Ubillus'],
  ),
  MaintenanceZone(
    number: 63,
    section: 'Margarina',
    process: 'Línea K1',
    responsibles: ['Edgar Ubillus'],
  ),
  MaintenanceZone(
    number: 64,
    section: 'Margarina',
    process: 'Línea K2',
    responsibles: ['David Quiranza'],
  ),
  MaintenanceZone(
    number: 65,
    section: 'Margarina',
    process: 'Línea Prepac Margarina',
    responsibles: ['David Quiranza'],
  ),
  MaintenanceZone(
    number: 66,
    section: 'Margarina',
    process: 'Línea Prepac Margarina 2',
    responsibles: ['Santiago Cárdenas'],
  ),
  MaintenanceZone(
    number: 67,
    section: 'Margarina',
    process: 'Selladoras de cartón',
    responsibles: ['Santiago Cárdenas'],
  ),
  MaintenanceZone(
    number: 68,
    section: 'Margarina',
    process: 'Servicios margarina',
    responsibles: ['Edgar Ubillus', 'Henry Suntaxi'],
  ),
  MaintenanceZone(
    number: 69,
    section: 'Confitería y Galletería',
    process: 'Bañado',
    responsibles: ['Santiago Cárdenas'],
  ),
  MaintenanceZone(
    number: 70,
    section: 'Confitería y Galletería',
    process: 'Chocolatería',
    responsibles: ['Jefferson Zamora'],
  ),
  MaintenanceZone(
    number: 71,
    section: 'Confitería y Galletería',
    process: 'Empaque',
    responsibles: ['Jefferson Zamora'],
  ),
  MaintenanceZone(
    number: 72,
    section: 'Confitería y Galletería',
    process: 'Línea miniconos',
    responsibles: ['Jefferson Zamora'],
  ),
  MaintenanceZone(
    number: 73,
    section: 'Confitería y Galletería',
    process: 'Línea wafer',
    responsibles: ['Santiago Cárdenas'],
  ),
  MaintenanceZone(
    number: 74,
    section: 'Confitería y Galletería',
    process: 'Preparación',
    responsibles: ['Santiago Cárdenas'],
  ),
  MaintenanceZone(
    number: 75,
    section: 'Confitería y Galletería',
    process: 'Servicios',
    responsibles: ['Jefferson Zamora', 'Angel Loachamin'],
  ),
  MaintenanceZone(
    number: 76,
    section: 'Servicios Industriales',
    process: 'Compresores refinería',
    responsibles: ['Angel Loachamin'],
  ),
  MaintenanceZone(
    number: 77,
    section: 'Taller Mecánico',
    process: 'Servicios',
    responsibles: ['Diego Pachacama'],
  ),
  MaintenanceZone(
    number: 78,
    section: 'Aceites',
    process: 'Almacenamiento aceites',
    responsibles: ['Kevin Changoluisa'],
  ),
  MaintenanceZone(
    number: 79,
    section: 'Aceites',
    process: 'Servicios aceites',
    responsibles: ['Kevin Changoluisa'],
  ),
  MaintenanceZone(
    number: 80,
    section: 'Aceites',
    process: 'Líneas Auseres',
    responsibles: ['Mario Mora'],
  ),
  MaintenanceZone(
    number: 81,
    section: 'Aceites',
    process: 'Achiote',
    responsibles: ['Mario Mora'],
  ),
  MaintenanceZone(
    number: 82,
    section: 'Aceites',
    process: 'Líneas Prepacs',
    responsibles: ['Vianka Condor'],
  ),
  MaintenanceZone(
    number: 83,
    section: 'Aceites',
    process: 'Empaque',
    responsibles: ['Vianka Condor'],
  ),
];

MaintenanceZone? maintenanceZoneByNumber(int number) {
  for (final zone in maintenanceZones) {
    if (zone.number == number) return zone;
  }
  return null;
}
