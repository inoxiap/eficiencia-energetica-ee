import process from "node:process";
import {basename, extname} from "node:path";
import {readFile} from "node:fs/promises";

import {applicationDefault, initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {FieldValue, getFirestore} from "firebase-admin/firestore";

const [nationalId, closePath, generalPath, confirmFlag] = process.argv.slice(2);
if (!nationalId || !closePath || !generalPath || confirmFlag !== "--confirm-production") {
  throw new Error(
    "Uso: node scripts/seed-steam-trap-demo.mjs <cedula-jeff> " +
    "<foto-cercana> <foto-general> --confirm-production",
  );
}

const projectId = process.env.FIREBASE_PROJECT_ID || "eficiencia-energetica-ee";
if (projectId !== "eficiencia-energetica-ee") {
  throw new Error("El dataset de demostracion solo se crea en el proyecto EE.");
}

const app = initializeApp({credential: applicationDefault(), projectId});
const auth = getAuth(app);
const db = getFirestore(app);
const email = `operator-${nationalId}@eficiencia-energetica-ee.app`;
const jeff = await auth.getUserByEmail(email);
if (!jeff.displayName?.toLowerCase().includes("jefferson")) {
  throw new Error("La cuenta encontrada no coincide con Jefferson; no se escribio nada.");
}

const examples = [
  {
    id: "demo_steam_trap_refineria_001",
    tag: "DEMO-TV-01-001",
    sectionCode: "01",
    sectionId: "refineria",
    sectionNameSnapshot: "Refineria",
    zone: "Zona de demostracion A",
    equipmentName: "Linea de vapor de proceso",
    equipmentNameNormalized: "linea de vapor de proceso",
    serviceId: "steam_distributor",
    serviceNameSnapshot: "Distribuidor de vapor",
    diameter: "1/2 in",
    trapTypeId: "inverted_bucket",
    trapTypeNameSnapshot: "Balde invertido",
    condensateRecovery: "yes",
    comments: "Registro ficticio para probar consulta y descarga.",
    diagnosisStatus: "requires_attention",
  },
  {
    id: "demo_steam_trap_jaboneria_001",
    tag: "DEMO-TV-07-001",
    sectionCode: "07",
    sectionId: "jaboneria",
    sectionNameSnapshot: "Jaboneria",
    zone: "Zona de demostracion B",
    equipmentName: "Chaqueta de tanque de proceso",
    equipmentNameNormalized: "chaqueta de tanque de proceso",
    serviceId: "jacket",
    serviceNameSnapshot: "Chaqueta",
    diameter: "3/4 in",
    trapTypeId: "float_thermostatic",
    trapTypeNameSnapshot: "Flotador termostatica",
    condensateRecovery: "to_confirm",
    comments: "Segundo registro ficticio. Las fotografias son ilustrativas.",
    diagnosisStatus: "operational",
  },
  {
    id: "demo_steam_trap_servicios_001",
    tag: "DEMO-TV-10-001",
    sectionCode: "10",
    sectionId: "servicios_industriales",
    sectionNameSnapshot: "Servicios Industriales",
    zone: "Zona de demostracion C",
    equipmentName: "Drenaje de colector de vapor",
    equipmentNameNormalized: "drenaje de colector de vapor",
    serviceId: "steam_distributor",
    serviceNameSnapshot: "Distribuidor de vapor",
    diameter: "1 in",
    trapTypeId: "inverted_bucket",
    trapTypeNameSnapshot: "Balde invertido",
    condensateRecovery: "no",
    comments: "Dataset de entrenamiento, no representa un equipo real.",
    diagnosisStatus: "pending",
  },
  {
    id: "demo_steam_trap_margarina_001",
    tag: "DEMO-TV-15-001",
    sectionCode: "15",
    sectionId: "margarina",
    sectionNameSnapshot: "Margarina",
    zone: "Zona de demostracion D",
    equipmentName: "Serpentin de calentamiento",
    equipmentNameNormalized: "serpentin de calentamiento",
    serviceId: "coil",
    serviceNameSnapshot: "Serpentin",
    diameter: "1/2 in",
    trapTypeId: "float_thermostatic",
    trapTypeNameSnapshot: "Flotador termostatica",
    condensateRecovery: "yes",
    comments: "Dataset de entrenamiento, no representa un equipo real.",
    diagnosisStatus: "operational",
  },
];

const documents = await Promise.all(
  examples.map((example) => db.collection("steam_trap_records").doc(example.id).get()),
);
if (documents.some((document) => document.exists)) {
  throw new Error("Ya existe parte del dataset DEMO; no se modifico ningun registro.");
}

async function uploadDemoImage(path, publicId) {
  const bytes = await readFile(path);
  const form = new FormData();
  form.append("upload_preset", "ee_evidencias_unsigned");
  form.append("public_id", publicId);
  form.append("folder", "ee_demo_steam_traps");
  form.append(
    "file",
    new Blob([bytes], {type: "image/png"}),
    basename(path, extname(path)) + ".png",
  );
  const response = await fetch(
    "https://api.cloudinary.com/v1_1/dovufh5wv/image/upload",
    {method: "POST", body: form},
  );
  const payload = await response.json();
  if (!response.ok || !payload.secure_url || !payload.public_id) {
    throw new Error("Cloudinary no pudo cargar la fotografia DEMO.");
  }
  return {
    url: payload.secure_url,
    publicId: payload.public_id,
    format: payload.format || "png",
  };
}

const closePhoto = await uploadDemoImage(closePath, "DEMO_TRAMPAS_CERCA");
const generalPhoto = await uploadDemoImage(generalPath, "DEMO_TRAMPAS_GENERAL");
const batch = db.batch();
for (const [index, example] of examples.entries()) {
  const close = {
    type: "close",
    ...closePhoto,
    fileName: `${example.tag}_CERCA.${closePhoto.format}`,
    uploadedAt: new Date().toISOString(),
    ownerUid: "demo-seed",
    tag: example.tag,
    provider: "cloudinary",
  };
  const general = {
    type: "general",
    ...generalPhoto,
    fileName: `${example.tag}_GENERAL.${generalPhoto.format}`,
    uploadedAt: new Date().toISOString(),
    ownerUid: "demo-seed",
    tag: example.tag,
    provider: "cloudinary",
  };
  batch.create(db.collection("steam_trap_records").doc(example.id), {
    ...example,
    tagLocked: true,
    entryMode: "new_entry",
    status: "complete",
    photoProvider: "cloudinary",
    closePhoto: close,
    generalPhoto: general,
    ownerUid: "demo-seed",
    ownerNameSnapshot: "Dataset de demostracion",
    companyId: "demo",
    companyNameSnapshot: "Demostracion",
    isDemo: true,
    sharedWithUids: [jeff.uid],
    createdAt: FieldValue.serverTimestamp(),
    createdByUid: "demo-seed",
    createdByNameSnapshot: "Dataset de demostracion",
    updatedAt: FieldValue.serverTimestamp(),
    updatedByUid: "demo-seed",
    appVersion: "demo-seed-v1",
    platform: "server",
    schemaVersion: 1,
    source: "demo_seed",
    sectionHistory: [],
    demoSequence: index + 1,
  });
}
batch.create(db.collection("audit_logs").doc(), {
  eventType: "steam_trap_demo_dataset_created",
  actorUid: "demo-seed-script",
  actorRole: "system",
  targetCollection: "steam_trap_records",
  targetDocumentId: "demo_steam_trap_*",
  occurredAt: FieldValue.serverTimestamp(),
  platform: "server",
  appVersion: "demo-seed-v1",
  metadata: {count: examples.length, sharedWithUid: jeff.uid},
});
await batch.commit();

console.log(`Dataset DEMO creado: ${examples.length} registros y 2 fotografias.`);
