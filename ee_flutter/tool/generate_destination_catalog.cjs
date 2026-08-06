const fs = require('fs');
const path = require('path');

const [sourcePath, outputPath] = process.argv.slice(2);
if (!sourcePath || !outputPath) {
  throw new Error(
    'Uso: node tool/generate_destination_catalog.cjs <fuente.json> <salida.json>',
  );
}

const source = JSON.parse(fs.readFileSync(sourcePath, 'utf8'));
if (!Array.isArray(source.destinations)) {
  throw new Error('El archivo fuente no contiene destinations.');
}

const sections = new Map();

function getOrCreate(map, code, name, create) {
  const current = map.get(code);
  if (current) {
    if (current.name !== name) {
      throw new Error(`Nombre inconsistente para ${code}: ${current.name} / ${name}`);
    }
    return current;
  }
  const value = create();
  map.set(code, value);
  return value;
}

for (const destination of source.destinations) {
  const section = getOrCreate(
    sections,
    String(destination.section.code),
    String(destination.section.name),
    () => ({
      code: String(destination.section.code),
      name: String(destination.section.name),
      processes: new Map(),
    }),
  );
  const process = getOrCreate(
    section.processes,
    String(destination.process.code),
    String(destination.process.name),
    () => ({
      code: String(destination.process.code),
      name: String(destination.process.name),
      equipment: new Map(),
    }),
  );
  const equipment = getOrCreate(
    process.equipment,
    String(destination.equipment.code),
    String(destination.equipment.name),
    () => ({
      code: String(destination.equipment.code),
      name: String(destination.equipment.name),
      destinationId: '',
      systems: new Map(),
    }),
  );

  const systemCode = String(destination.system.code || '');
  const systemName = String(destination.system.name || '');
  if (!systemCode) {
    if (equipment.systems.size > 0 || equipment.destinationId) {
      throw new Error(`Equipo terminal ambiguo: ${destination.route}`);
    }
    equipment.destinationId = String(destination.id);
    continue;
  }
  if (equipment.destinationId) {
    throw new Error(`Equipo mezcla hoja directa y sistemas: ${destination.route}`);
  }
  const system = getOrCreate(
    equipment.systems,
    systemCode,
    systemName,
    () => ({
      code: systemCode,
      name: systemName,
      destinationId: String(destination.id),
    }),
  );
  if (system.destinationId !== String(destination.id)) {
    throw new Error(`Sistema terminal ambiguo: ${destination.route}`);
  }
}

const compact = {
  schemaVersion: source.schemaVersion,
  generatedAt: source.generatedAt,
  sections: [...sections.values()].map((section) => ({
    code: section.code,
    name: section.name,
    processes: [...section.processes.values()].map((process) => ({
      code: process.code,
      name: process.name,
      equipment: [...process.equipment.values()].map((equipment) => ({
        code: equipment.code,
        name: equipment.name,
        destinationId: equipment.destinationId,
        systems: [...equipment.systems.values()],
      })),
    })),
  })),
};

fs.mkdirSync(path.dirname(outputPath), {recursive: true});
fs.writeFileSync(outputPath, `${JSON.stringify(compact)}\n`, 'utf8');
console.log(
  `Catalogo generado: ${compact.sections.length} macroareas, ${source.destinations.length} destinos.`,
);
