import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import process from 'node:process';
import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

const commit = process.argv.includes('--commit');
const filePath = process.argv.find((value) => value.endsWith('.json'));
const ownerUid = process.env.IMPORT_OWNER_UID?.trim();
const ownerName = process.env.IMPORT_OWNER_NAME?.trim();
if (!filePath) throw new Error('Uso: node scripts/import-steam-traps.mjs archivo.json [--commit]');
if (!ownerUid || !ownerName) throw new Error('Define IMPORT_OWNER_UID e IMPORT_OWNER_NAME.');

const sections = new Map([
  ['01', ['refineria', 'Refineria']], ['02', ['desodorizacion', 'Desodorizacion']],
  ['03', ['fraccionamiento', 'Fraccionamiento']], ['04', ['manteca', 'Manteca']],
  ['05', ['aceites', 'Aceites']], ['06', ['hidrogenacion', 'Hidrogenacion']],
  ['07', ['jaboneria', 'Jaboneria']], ['08', ['recepcion', 'Recepcion']],
  ['09', ['dex', 'DEX']], ['10', ['servicios_industriales', 'Servicios Industriales']],
  ['11', ['administracion', 'Administracion']], ['12', ['jabon_calcico', 'Jabon Calcico']],
  ['13', ['desinfectante', 'Desinfectante']], ['15', ['margarina', 'Margarina']],
  ['16', ['confiteria_galleteria', 'Confiteria y Galleteria']],
]);

const payload = JSON.parse(await readFile(filePath, 'utf8'));
if (!Array.isArray(payload)) throw new Error('El JSON debe contener un arreglo.');
const normalized = payload.map((row, index) => {
  const legacyId = String(row.legacyId ?? row.idAnterior ?? '').trim();
  const sectionCode = String(row.sectionCode ?? row.codigoSeccion ?? '').padStart(2, '0');
  if (!legacyId) throw new Error(`Fila ${index + 1}: falta identificador anterior.`);
  if (!sections.has(sectionCode)) throw new Error(`Fila ${index + 1}: seccion ${sectionCode} no homologada.`);
  return { row, legacyId, sectionCode };
});

console.log(`${normalized.length} trampas validadas. Modo: ${commit ? 'COMMIT' : 'DRY-RUN'}.`);
if (!commit) process.exit(0);

initializeApp({ credential: applicationDefault(), projectId: process.env.GCLOUD_PROJECT });
const db = getFirestore();
for (const { row, legacyId, sectionCode } of normalized) {
  const internalId = `legacy_${createHash('sha256').update(legacyId).digest('hex').slice(0, 24)}`;
  const document = db.collection('steam_trap_records').doc(internalId);
  await db.runTransaction(async (transaction) => {
    if ((await transaction.get(document)).exists) return;
    const counter = db.collection('steam_trap_counters').doc(sectionCode);
    const counterSnapshot = await transaction.get(counter);
    const next = (counterSnapshot.data()?.lastNumber ?? 0) + 1;
    const tag = `TV-${sectionCode}-${String(next).padStart(3, '0')}`;
    const [sectionId, sectionName] = sections.get(sectionCode);
    transaction.set(counter, { sectionCode, lastNumber: next, updatedAt: FieldValue.serverTimestamp(), updatedByUid: ownerUid }, { merge: true });
    transaction.set(document, {
      id: internalId, tag, tagLocked: true, legacyId, sectionCode, sectionId,
      sectionNameSnapshot: sectionName,
      zone: String(row.zone ?? row.zona ?? '').trim(),
      equipmentName: String(row.equipmentName ?? row.equipo ?? '').trim(),
      equipmentNameNormalized: String(row.equipmentName ?? row.equipo ?? '').trim().toLowerCase(),
      serviceId: String(row.serviceId ?? row.servicio ?? '').trim(),
      serviceNameSnapshot: String(row.serviceName ?? row.servicio ?? '').trim(),
      description: String(row.description ?? row.descripcion ?? '').trim(),
      diameter: String(row.diameter ?? row.diametro ?? '').trim(),
      trapTypeId: String(row.trapTypeId ?? row.tipoTrampa ?? '').trim(),
      trapTypeNameSnapshot: String(row.trapTypeName ?? row.tipoTrampa ?? '').trim(),
      condensateRecovery: String(row.condensateRecovery ?? row.recuperacionCondensado ?? 'to_confirm').trim(),
      coordinates: row.coordinates ?? row.coordenadas ?? null,
      comments: '', diagnosisStatus: 'pending', entryMode: 'inventory_validation', status: 'draft',
      photoProvider: 'cloudinary', ownerUid, ownerNameSnapshot: ownerName,
      createdAt: FieldValue.serverTimestamp(), createdByUid: ownerUid, createdByNameSnapshot: ownerName,
      updatedAt: FieldValue.serverTimestamp(), updatedByUid: ownerUid,
      appVersion: 'inventory-import-v1', platform: 'web', schemaVersion: 1, source: 'inventory_import',
      sectionHistory: [],
    });
  });
}
console.log('Importacion terminada de forma idempotente.');
