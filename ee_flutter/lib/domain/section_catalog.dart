class PlantSection {
  const PlantSection({
    required this.id,
    required this.displayName,
    this.aliases = const [],
  });

  final String id;
  final String displayName;
  final List<String> aliases;
}

const plantSections = <PlantSection>[
  PlantSection(id: 'refineria', displayName: 'Refineria'),
  PlantSection(
    id: 'confiteria_galleteria',
    displayName: 'Confiteria y Galleteria',
    aliases: ['Confiteria'],
  ),
  PlantSection(id: 'desodorizacion', displayName: 'Desodorizacion'),
  PlantSection(id: 'fraccionamiento', displayName: 'Fraccionamiento'),
  PlantSection(id: 'manteca', displayName: 'Manteca'),
  PlantSection(id: 'aceites', displayName: 'Aceites', aliases: ['Envase']),
  PlantSection(id: 'hidrogenacion', displayName: 'Hidrogenacion'),
  PlantSection(id: 'jaboneria', displayName: 'Jaboneria'),
  PlantSection(id: 'recepcion', displayName: 'Recepcion'),
  PlantSection(id: 'dex', displayName: 'DEX'),
  PlantSection(
    id: 'servicios_industriales',
    displayName: 'Servicios Industriales',
    aliases: ['Calderas'],
  ),
  PlantSection(id: 'margarina', displayName: 'Margarina'),
];

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
