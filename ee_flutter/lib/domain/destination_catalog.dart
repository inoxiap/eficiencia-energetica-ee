import 'dart:convert';

class DestinationCatalog {
  const DestinationCatalog({
    required this.schemaVersion,
    required this.sections,
  });

  final String schemaVersion;
  final List<DestinationSection> sections;

  factory DestinationCatalog.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('El catalogo de destinos no es valido.');
    }
    final rawSections = decoded['sections'];
    if (rawSections is! List) {
      throw const FormatException('El catalogo no contiene macroareas.');
    }
    return DestinationCatalog(
      schemaVersion: decoded['schemaVersion'] as String? ?? '',
      sections: rawSections
          .whereType<Map<String, dynamic>>()
          .map(DestinationSection.fromJson)
          .toList(growable: false),
    );
  }

  DestinationSection? sectionByCode(String code) {
    return _byCode(sections, code, (item) => item.code);
  }

  DestinationSelection selection({
    String sectionCode = '',
    String processCode = '',
    String equipmentCode = '',
    String systemCode = '',
  }) {
    if (sectionCode.isEmpty) {
      if (processCode.isNotEmpty ||
          equipmentCode.isNotEmpty ||
          systemCode.isNotEmpty) {
        throw const FormatException(
          'No se acepta un destino hijo sin macroarea.',
        );
      }
      return const DestinationSelection.empty();
    }

    final section = sectionByCode(sectionCode);
    if (section == null) {
      throw FormatException('Macroarea desconocida: $sectionCode');
    }
    if (processCode.isEmpty) {
      if (equipmentCode.isNotEmpty || systemCode.isNotEmpty) {
        throw const FormatException('No se acepta un equipo sin proceso.');
      }
      return DestinationSelection.section(section);
    }

    final process = section.processByCode(processCode);
    if (process == null) {
      throw FormatException('Proceso desconocido: $processCode');
    }
    if (equipmentCode.isEmpty) {
      if (systemCode.isNotEmpty) {
        throw const FormatException('No se acepta un sistema sin equipo.');
      }
      return DestinationSelection.process(section, process);
    }

    final equipment = process.equipmentByCode(equipmentCode);
    if (equipment == null) {
      throw FormatException('Equipo desconocido: $equipmentCode');
    }
    if (systemCode.isEmpty) {
      return DestinationSelection.equipment(section, process, equipment);
    }

    final system = equipment.systemByCode(systemCode);
    if (system == null) {
      throw FormatException('Sistema desconocido: $systemCode');
    }
    return DestinationSelection.system(section, process, equipment, system);
  }
}

class DestinationSection {
  const DestinationSection({
    required this.code,
    required this.name,
    required this.processes,
  });

  final String code;
  final String name;
  final List<DestinationProcess> processes;

  factory DestinationSection.fromJson(Map<String, dynamic> json) {
    return DestinationSection(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      processes: (json['processes'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(DestinationProcess.fromJson)
          .toList(growable: false),
    );
  }

  DestinationProcess? processByCode(String code) {
    return _byCode(processes, code, (item) => item.code);
  }
}

class DestinationProcess {
  const DestinationProcess({
    required this.code,
    required this.name,
    required this.equipment,
  });

  final String code;
  final String name;
  final List<DestinationEquipment> equipment;

  factory DestinationProcess.fromJson(Map<String, dynamic> json) {
    return DestinationProcess(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      equipment: (json['equipment'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(DestinationEquipment.fromJson)
          .toList(growable: false),
    );
  }

  DestinationEquipment? equipmentByCode(String code) {
    return _byCode(equipment, code, (item) => item.code);
  }
}

class DestinationEquipment {
  const DestinationEquipment({
    required this.code,
    required this.name,
    required this.destinationId,
    required this.systems,
  });

  final String code;
  final String name;
  final String destinationId;
  final List<DestinationSystem> systems;

  bool get isTerminal => systems.isEmpty && destinationId.isNotEmpty;

  factory DestinationEquipment.fromJson(Map<String, dynamic> json) {
    return DestinationEquipment(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      destinationId: json['destinationId'] as String? ?? '',
      systems: (json['systems'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(DestinationSystem.fromJson)
          .toList(growable: false),
    );
  }

  DestinationSystem? systemByCode(String code) {
    return _byCode(systems, code, (item) => item.code);
  }
}

class DestinationSystem {
  const DestinationSystem({
    required this.code,
    required this.name,
    required this.destinationId,
  });

  final String code;
  final String name;
  final String destinationId;

  factory DestinationSystem.fromJson(Map<String, dynamic> json) {
    return DestinationSystem(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      destinationId: json['destinationId'] as String? ?? '',
    );
  }
}

class DestinationSelection {
  const DestinationSelection._({
    required this.sectionCode,
    required this.sectionName,
    required this.processCode,
    required this.processName,
    required this.equipmentCode,
    required this.equipmentName,
    required this.systemCode,
    required this.systemName,
    required this.destinationId,
    required this.selectionDepth,
  });

  const DestinationSelection.empty()
    : this._(
        sectionCode: '',
        sectionName: '',
        processCode: '',
        processName: '',
        equipmentCode: '',
        equipmentName: '',
        systemCode: '',
        systemName: '',
        destinationId: '',
        selectionDepth: 'none',
      );

  DestinationSelection.section(DestinationSection section)
    : this._(
        sectionCode: section.code,
        sectionName: section.name,
        processCode: '',
        processName: '',
        equipmentCode: '',
        equipmentName: '',
        systemCode: '',
        systemName: '',
        destinationId: '',
        selectionDepth: 'section',
      );

  DestinationSelection.process(
    DestinationSection section,
    DestinationProcess process,
  ) : this._(
        sectionCode: section.code,
        sectionName: section.name,
        processCode: process.code,
        processName: process.name,
        equipmentCode: '',
        equipmentName: '',
        systemCode: '',
        systemName: '',
        destinationId: '',
        selectionDepth: 'process',
      );

  DestinationSelection.equipment(
    DestinationSection section,
    DestinationProcess process,
    DestinationEquipment equipment,
  ) : this._(
        sectionCode: section.code,
        sectionName: section.name,
        processCode: process.code,
        processName: process.name,
        equipmentCode: equipment.code,
        equipmentName: equipment.name,
        systemCode: '',
        systemName: '',
        destinationId: equipment.isTerminal ? equipment.destinationId : '',
        selectionDepth: 'equipment',
      );

  DestinationSelection.system(
    DestinationSection section,
    DestinationProcess process,
    DestinationEquipment equipment,
    DestinationSystem system,
  ) : this._(
        sectionCode: section.code,
        sectionName: section.name,
        processCode: process.code,
        processName: process.name,
        equipmentCode: equipment.code,
        equipmentName: equipment.name,
        systemCode: system.code,
        systemName: system.name,
        destinationId: system.destinationId,
        selectionDepth: 'system',
      );

  final String sectionCode;
  final String sectionName;
  final String processCode;
  final String processName;
  final String equipmentCode;
  final String equipmentName;
  final String systemCode;
  final String systemName;
  final String destinationId;
  final String selectionDepth;

  Map<String, String> toCodeJson() => {
    'sectionCode': sectionCode,
    'processCode': processCode,
    'equipmentCode': equipmentCode,
    'systemCode': systemCode,
    'destinationId': destinationId,
    'selectionDepth': selectionDepth,
  };
}

T? _byCode<T>(List<T> values, String code, String Function(T) getCode) {
  for (final value in values) {
    if (getCode(value) == code) return value;
  }
  return null;
}
