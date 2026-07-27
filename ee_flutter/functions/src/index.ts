import * as argon2 from "argon2";
import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {FieldValue, Timestamp, getFirestore} from "firebase-admin/firestore";
import {defineSecret} from "firebase-functions/params";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {
  credentialLookupId,
  isAcceptedOperatorNationalId,
  isValidPin,
  normalizeNationalId,
} from "./credentials";

initializeApp();

const db = getFirestore();
const auth = getAuth();
const cedulaLookupPepper = defineSecret("CEDULA_LOOKUP_PEPPER");
const region = "us-central1";
const maxFailedAttempts = 5;
const lockMinutes = 15;
const allowTestNationalIds = process.env.FUNCTIONS_EMULATOR === "true";
const argonParameters = {
  type: argon2.argon2id,
  memoryCost: 19456,
  timeCost: 2,
  parallelism: 1,
};

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function validateCredentials(
  nationalId: string,
  pin: unknown,
): asserts pin is string {
  if (!isAcceptedOperatorNationalId(nationalId, allowTestNationalIds)) {
    throw new HttpsError(
      "invalid-argument",
      "La cedula no es valida. Verifica que sea una cedula ecuatoriana " +
        "de persona natural con digito verificador correcto.",
    );
  }
  if (!isValidPin(pin)) {
    throw new HttpsError(
      "invalid-argument",
      "El PIN debe contener entre 4 y 6 numeros.",
    );
  }
}

export const registerOperator = onCall(
  {region, secrets: [cedulaLookupPepper]},
  async (request) => {
    const fullName = text(request.data?.fullName);
    const nationalId = normalizeNationalId(request.data?.nationalId);
    const pin = request.data?.pin;
    if (fullName.length < 3 || fullName.length > 120) {
      throw new HttpsError("invalid-argument", "Ingresa el nombre completo.");
    }
    validateCredentials(nationalId, pin);

    const lookupId = credentialLookupId(
      nationalId,
      cedulaLookupPepper.value(),
    );
    const credentialRef = db
      .collection("user_private_credentials")
      .doc(lookupId);
    const pinHash = await argon2.hash(pin, argonParameters);
    const user = await auth.createUser({displayName: fullName, disabled: false});

    try {
      await db.runTransaction(async (transaction) => {
        const existing = await transaction.get(credentialRef);
        if (existing.exists) {
          throw new HttpsError(
            "already-exists",
            "Ya existe un operador con esa cedula.",
          );
        }
        transaction.create(credentialRef, {
          uid: user.uid,
          nationalIdLookupHash: lookupId,
          pinHash,
          pinHashAlgorithm: "argon2id",
          pinHashParameters: {
            memoryCost: argonParameters.memoryCost,
            timeCost: argonParameters.timeCost,
            parallelism: argonParameters.parallelism,
          },
          failedAttempts: 0,
          lockedUntil: null,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        transaction.create(db.collection("users").doc(user.uid), {
          uid: user.uid,
          displayName: fullName,
          role: "operator",
          active: true,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          schemaVersion: 1,
        });
        transaction.create(db.collection("audit_logs").doc(), {
          eventType: "operator_registered",
          actorUid: user.uid,
          actorRole: "operator",
          targetCollection: "users",
          targetDocumentId: user.uid,
          occurredAt: FieldValue.serverTimestamp(),
          platform: text(request.data?.platform) || "unknown",
          appVersion: text(request.data?.appVersion) || "unknown",
          metadata: {},
        });
      });
      await auth.setCustomUserClaims(user.uid, {role: "operator"});
      const customToken = await auth.createCustomToken(user.uid, {
        role: "operator",
      });
      return {customToken};
    } catch (error) {
      await auth.deleteUser(user.uid).catch(() => undefined);
      throw error;
    }
  },
);

export const loginOperator = onCall(
  {region, secrets: [cedulaLookupPepper]},
  async (request) => {
    const nationalId = normalizeNationalId(request.data?.nationalId);
    const pin = request.data?.pin;
    validateCredentials(nationalId, pin);

    const lookupId = credentialLookupId(
      nationalId,
      cedulaLookupPepper.value(),
    );
    const credentialRef = db
      .collection("user_private_credentials")
      .doc(lookupId);
    const credential = await credentialRef.get();
    if (!credential.exists) {
      throw new HttpsError("unauthenticated", "Cedula o PIN incorrectos.");
    }
    const data = credential.data()!;
    const lockedUntil = data.lockedUntil as Timestamp | null;
    if (lockedUntil && lockedUntil.toMillis() > Date.now()) {
      throw new HttpsError(
        "resource-exhausted",
        "Demasiados intentos. Espera antes de reintentar.",
      );
    }

    const validPin = await argon2.verify(String(data.pinHash ?? ""), pin);
    if (!validPin) {
      await db.runTransaction(async (transaction) => {
        const current = await transaction.get(credentialRef);
        const attempts = Number(current.data()?.failedAttempts ?? 0) + 1;
        transaction.update(credentialRef, {
          failedAttempts: attempts,
          lockedUntil:
            attempts >= maxFailedAttempts
              ? Timestamp.fromMillis(Date.now() + lockMinutes * 60_000)
              : null,
          updatedAt: FieldValue.serverTimestamp(),
        });
      });
      throw new HttpsError("unauthenticated", "Cedula o PIN incorrectos.");
    }

    const uid = String(data.uid ?? "");
    const profile = await db.collection("users").doc(uid).get();
    if (!profile.exists || profile.data()?.active !== true) {
      throw new HttpsError("permission-denied", "El operador esta inactivo.");
    }
    const role = profile.data()?.role === "admin" ? "admin" : "operator";
    await credentialRef.update({
      failedAttempts: 0,
      lockedUntil: null,
      updatedAt: FieldValue.serverTimestamp(),
    });
    await db.collection("audit_logs").add({
      eventType: "operator_login",
      actorUid: uid,
      actorRole: role,
      targetCollection: "users",
      targetDocumentId: uid,
      occurredAt: FieldValue.serverTimestamp(),
      platform: text(request.data?.platform) || "unknown",
      appVersion: text(request.data?.appVersion) || "unknown",
      metadata: {},
    });
    await auth.setCustomUserClaims(uid, {role});
    const customToken = await auth.createCustomToken(uid, {role});
    return {customToken};
  },
);
