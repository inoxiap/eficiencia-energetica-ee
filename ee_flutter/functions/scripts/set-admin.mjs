import process from "node:process";

import {applicationDefault, initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {FieldValue, getFirestore} from "firebase-admin/firestore";

const uid = process.argv[2];
if (!uid) {
  throw new Error("Uso: node scripts/set-admin.mjs <uid>");
}
const projectId =
  process.env.FIREBASE_PROJECT_ID || "eficiencia-energetica-ee";
initializeApp({credential: applicationDefault(), projectId});

await getAuth().setCustomUserClaims(uid, {role: "admin"});
await getFirestore().collection("users").doc(uid).update({
  role: "admin",
  updatedAt: FieldValue.serverTimestamp(),
});
await getFirestore().collection("audit_logs").add({
  eventType: "admin_role_assigned",
  actorUid: "administrative-script",
  actorRole: "system",
  targetCollection: "users",
  targetDocumentId: uid,
  occurredAt: FieldValue.serverTimestamp(),
  platform: "server",
  appVersion: "set-admin-v1",
  metadata: {},
});
console.log(`Rol admin asignado al UID ${uid}.`);
