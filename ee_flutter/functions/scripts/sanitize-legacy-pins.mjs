import process from "node:process";

import {applicationDefault, initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore} from "firebase-admin/firestore";

const apply = process.argv.includes("--apply");
const projectId =
  process.env.FIREBASE_PROJECT_ID || "eficiencia-energetica-ee";

initializeApp({credential: applicationDefault(), projectId});
const db = getFirestore();
const snapshot = await db
  .collection("boiler_consumption_readings")
  .where("operatorPin", "!=", null)
  .get();

console.log(
  `${snapshot.size} documentos contienen el campo legado operatorPin.`,
);

if (!apply) {
  console.log(
    "Simulacion terminada. Cree un respaldo y ejecute de nuevo con --apply para retirar exclusivamente ese campo.",
  );
  process.exit(0);
}

const writer = db.bulkWriter();
for (const document of snapshot.docs) {
  writer.update(document.ref, {
    operatorPin: FieldValue.delete(),
    updatedAt: FieldValue.serverTimestamp(),
    migrationVersion: "remove-legacy-operator-pin-v1",
  });
}
await writer.close();
console.log("Campo operatorPin retirado de los documentos encontrados.");
