class PlantSection {
  const PlantSection({
    required this.code,
    required this.id,
    required this.displayName,
    this.aliases = const [],
  });

  final String code;
  final String id;
  final String displayName;
  final List<String> aliases;
}

const plantSections = <PlantSection>[
  PlantSection(code: '01', id: 'refineria', displayName: 'Refineria'),
  PlantSection(code: '02', id: 'desodorizacion', displayName: 'Desodorizacion'),
  PlantSection(
    code: '03',
    id: 'fraccionamiento',
    displayName: 'Fraccionamiento',
  ),
  PlantSection(code: '04', id: 'manteca', displayName: 'Manteca'),
  PlantSection(
    code: '05',
    id: 'aceites',
    displayName: 'Aceites',
    aliases: ['Envase'],
  ),
  PlantSection(code: '06', id: 'hidrogenacion', displayName: 'Hidrogenacion'),
  PlantSection(code: '07', id: 'jaboneria', displayName: 'Jaboneria'),
  PlantSection(code: '08', id: 'recepcion', displayName: 'Recepcion'),
  PlantSection(code: '09', id: 'dex', displayName: 'DEX'),
  PlantSection(
    code: '10',
    id: 'servicios_industriales',
    displayName: 'Servicios Industriales',
    aliases: ['Calderas'],
  ),
  PlantSection(code: '11', id: 'administracion', displayName: 'Administracion'),
  PlantSection(code: '12', id: 'jabon_calcico', displayName: 'Jabon Calcico'),
  PlantSection(code: '13', id: 'desinfectante', displayName: 'Desinfectante'),
  PlantSection(code: '15', id: 'margarina', displayName: 'Margarina'),
  PlantSection(
    code: '16',
    id: 'confiteria_galleteria',
    displayName: 'Confiteria y Galleteria',
    aliases: ['Confiteria'],
  ),
];

PlantSection? plantSectionByCode(String code) {
  for (final section in plantSections) {
    if (section.code == code) return section;
  }
  return null;
}

PlantSection? plantSectionById(String id) {
  for (final section in plantSections) {
    if (section.id == id) {
      return section;
    }
  }
  return null;
}

String normalizeEquipmentName(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
