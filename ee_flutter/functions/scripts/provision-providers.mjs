import {randomInt} from "node:crypto";
import {readFile} from "node:fs/promises";
import process from "node:process";

import {applicationDefault, initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {FieldValue, Timestamp, getFirestore} from "firebase-admin/firestore";

const inputPath = process.argv[2];
if (!inputPath) {
  throw new Error("Uso: node scripts/provision-providers.mjs <archivo.json>");
}

const projectId =
  process.env.FIREBASE_PROJECT_ID || "eficiencia-energetica-ee";
const expiresAt = Timestamp.fromDate(new Date("2026-12-01T05:00:00.000Z"));
const pepperedEmail = (nationalId) =>
  `operator-${nationalId}@eficiencia-energetica-ee.app`;
const firebasePassword = (pin) => `Ee:${pin}`;
const auth = initializeApp({credential: applicationDefault(), projectId});
const firebaseAuth = getAuth(auth);
const db = getFirestore(auth);

function validNationalId(value) {
  if (!/^\d{10}$/.test(value)) return false;
  const province = Number(value.slice(0, 2));
  if (province < 1 || province > 24 || Number(value[2]) >= 6) return false;
  const digits = [...value].map(Number);
  let total = 0;
  for (let i = 0; i < 9; i += 1) {
    let digit = digits[i] * (i % 2 === 0 ? 2 : 1);
    if (digit > 9) digit -= 9;
    total += digit;
  }
  return (10 - (total % 10)) % 10 === digits[9];
}

function makePin(usedPins) {
  let pin;
  do {
    pin = String(randomInt(0, 10_000)).padStart(4, "0");
  } while (usedPins.has(pin));
  usedPins.add(pin);
  return pin;
}

const providers = JSON.parse(await readFile(inputPath, "utf8"));
if (!Array.isArray(providers) || providers.length === 0) {
  throw new Error("El JSON debe contener una lista no vacia de proveedores.");
}

const identities = new Set();
for (const provider of providers) {
  const fullName = String(provider.fullName ?? "").trim();
  const nationalId = String(provider.nationalId ?? "").trim();
  const companyId = String(provider.companyId ?? "").trim();
  const companyName = String(provider.companyName ?? "").trim();
  if (fullName.length < 3 || !validNationalId(nationalId) ||
      !/^[a-z0-9_-]{2,40}$/.test(companyId) || companyName.length < 2) {
    throw new Error("Proveedor invalido: revisa nombre, cedula y empresa.");
  }
  if (identities.has(nationalId)) {
    throw new Error("El archivo contiene cedulas repetidas.");
  }
  identities.add(nationalId);
}

for (const provider of providers) {
  try {
    await firebaseAuth.getUserByEmail(pepperedEmail(provider.nationalId));
    throw new Error(`La cuenta ${provider.fullName} ya existe; no se cambio.`);
  } catch (error) {
    if (error.code !== "auth/user-not-found") throw error;
  }
}

const created = [];
const usedPins = new Set();
try {
  for (const provider of providers) {
    const pin = makePin(usedPins);
    const email = pepperedEmail(provider.nationalId);
    const user = await firebaseAuth.createUser({
      email,
      password: firebasePassword(pin),
      displayName: provider.fullName.trim(),
      disabled: false,
    });
    created.push({provider, user, pin});
    await firebaseAuth.setCustomUserClaims(user.uid, {
      role: "provider",
      companyId: provider.companyId.trim(),
    });
    await db.collection("users").doc(user.uid).create({
      id: user.uid,
      uid: user.uid,
      displayName: provider.fullName.trim(),
      nationalId: provider.nationalId.trim(),
      role: "provider",
      companyId: provider.companyId.trim(),
      companyNameSnapshot: provider.companyName.trim(),
      active: true,
      credentialExpiresAt: expiresAt,
      createdAt: FieldValue.serverTimestamp(),
      createdByUid: "provider-provisioning-script",
      updatedAt: FieldValue.serverTimestamp(),
      updatedByUid: "provider-provisioning-script",
      appVersion: "provider-provisioner-v1",
      platform: "server",
      schemaVersion: 1,
      status: "active",
      source: "admin_provisioned",
    });
    await db.collection("audit_logs").add({
      eventType: "provider_account_created",
      actorUid: "provider-provisioning-script",
      actorRole: "system",
      targetCollection: "users",
      targetDocumentId: user.uid,
      occurredAt: FieldValue.serverTimestamp(),
      platform: "server",
      appVersion: "provider-provisioner-v1",
      metadata: {companyId: provider.companyId.trim()},
    });
  }
} catch (error) {
  await Promise.all(created.map(async ({user}) => {
    await db.collection("users").doc(user.uid).delete().catch(() => undefined);
    await firebaseAuth.deleteUser(user.uid).catch(() => undefined);
  }));
  throw error;
}

console.log("Cuentas creadas. Entrega estos PIN una sola vez y por canal privado:");
console.table(created.map(({provider, pin}) => ({
  nombre: provider.fullName.trim(),
  empresa: provider.companyName.trim(),
  cedula: provider.nationalId.trim(),
  pin,
  vence: "2026-12-01 00:00 America/Guayaquil",
})));
