import * as argon2 from "argon2";
import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {FieldValue, Timestamp, getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {defineSecret} from "firebase-functions/params";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
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
const notificationRecipientUids = [
  "SPe6lULbvJWUXnJrcjx6jAJd8To2", // Jefferson
  "QmZrgEauvZQmrgal0qX2UQqEdtF2", // administrator account
];
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

export const registerOperator = onCall({region}, async () => {
  throw new HttpsError(
    "permission-denied",
    "El registro de usuarios requiere una invitacion del administrador.",
  );
});

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

type BoilerAlertReading = {
  recordedAt: number;
  bunker: number;
  pressurePsi: number | null;
  rootRecordId: string;
  revision: number;
};

type NormalizedBunkerHour = {
  hourEnd: Date;
  gallons: number;
  pressurePsi: number | null;
};

function toNumber(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function guayaquilHourStart(value: Date): Date {
  const local = new Date(value.getTime() - 5 * 60 * 60 * 1000);
  return new Date(Date.UTC(
    local.getUTCFullYear(),
    local.getUTCMonth(),
    local.getUTCDate(),
    local.getUTCHours(),
  ) + 5 * 60 * 60 * 1000);
}

function cleaverThreshold(pressurePsi: number | null): number | null {
  if (pressurePsi === null) return null;
  if (pressurePsi >= 100 && pressurePsi <= 123) return 190;
  if (pressurePsi >= 150 && pressurePsi <= 161) return 300;
  return null;
}

function bunkerThreshold(boilerId: string, pressurePsi: number | null): number | null {
  if (boilerId === "alfa_laval_1200") return 300;
  if (boilerId === "distral_900") return 190;
  if (boilerId === "cleaver_brooks_1200") return cleaverThreshold(pressurePsi);
  return null;
}

function normalizedBunkerHours(
  readings: BoilerAlertReading[],
  now: Date,
): NormalizedBunkerHour[] {
  const latestByRoot = new Map<string, BoilerAlertReading>();
  for (const reading of readings) {
    const previous = latestByRoot.get(reading.rootRecordId);
    if (!previous || reading.revision > previous.revision ||
        (reading.revision === previous.revision &&
          reading.recordedAt > previous.recordedAt)) {
      latestByRoot.set(reading.rootRecordId, reading);
    }
  }
  const ordered = [...latestByRoot.values()]
    .filter((reading) => Number.isFinite(reading.bunker))
    .sort((left, right) => left.recordedAt - right.recordedAt);
  if (ordered.length < 2) return [];

  const first = new Date(ordered[0].recordedAt);
  const last = new Date(ordered[ordered.length - 1].recordedAt);
  const firstHourEnd = new Date(guayaquilHourStart(first).getTime() + 60 * 60 * 1000);
  const buckets = new Map<number, {value: number; coverage: number; pressurePsi: number | null}>();
  for (
    let hourEnd = guayaquilHourStart(last);
    hourEnd.getTime() >= firstHourEnd.getTime();
    hourEnd = new Date(hourEnd.getTime() - 60 * 60 * 1000)
  ) {
    buckets.set(hourEnd.getTime(), {value: 0, coverage: 0, pressurePsi: null});
  }

  for (let index = 1; index < ordered.length; index += 1) {
    const previous = ordered[index - 1];
    const current = ordered[index];
    const intervalMs = current.recordedAt - previous.recordedAt;
    const delta = current.bunker - previous.bunker;
    if (intervalMs <= 0 || delta < 0) continue;
    let bucketEnd = guayaquilHourStart(new Date(current.recordedAt));
    if (current.recordedAt > bucketEnd.getTime()) {
      bucketEnd = new Date(bucketEnd.getTime() + 60 * 60 * 1000);
    }
    while (bucketEnd.getTime() > previous.recordedAt) {
      const bucket = buckets.get(bucketEnd.getTime());
      if (bucket) {
        const bucketStart = bucketEnd.getTime() - 60 * 60 * 1000;
        const overlapStart = Math.max(previous.recordedAt, bucketStart);
        const overlapEnd = Math.min(current.recordedAt, bucketEnd.getTime());
        const overlapMs = overlapEnd - overlapStart;
        if (overlapMs > 0) {
          bucket.value += delta * overlapMs / intervalMs;
          bucket.coverage += overlapMs;
          bucket.pressurePsi = current.pressurePsi ?? previous.pressurePsi;
        }
      }
      bucketEnd = new Date(bucketEnd.getTime() - 60 * 60 * 1000);
    }
  }

  return [...buckets.entries()]
    .map(([time, bucket]) => ({
      hourEnd: new Date(time),
      gallons: bucket.coverage > 0 ? bucket.value * 60 * 60 * 1000 / bucket.coverage : 0,
      pressurePsi: bucket.pressurePsi,
    }))
    .filter((hour) => hour.hourEnd.getTime() <= now.getTime())
    .sort((left, right) => left.hourEnd.getTime() - right.hourEnd.getTime());
}

export const alertOnNormalizedBoilerConsumption = onDocumentCreated(
  {document: "boiler_consumption_readings/{readingId}", region},
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    const boilerId = text(data.boilerId);
    if (!boilerId) return;

    const source = await db.collection("boiler_consumption_readings")
      .where("boilerId", "==", boilerId)
      .orderBy("recordedAt", "desc")
      .limit(500)
      .get();
    const readings: BoilerAlertReading[] = source.docs.map((doc) => {
      const value = doc.data();
      const timestamp = value.recordedAt as Timestamp;
      return {
        recordedAt: timestamp.toMillis(),
        bunker: Number(value.fuelTotal ?? value.bunkerValue ?? NaN),
        pressurePsi: toNumber(value.boilerPressurePsi),
        rootRecordId: text(value.rootRecordId) || doc.id,
        revision: Number(value.revision ?? 1),
      };
    });
    const latestHour = normalizedBunkerHours(readings, new Date()).at(-1);
    if (!latestHour) return;

    const threshold = bunkerThreshold(boilerId, latestHour.pressurePsi);
    if (threshold === null || latestHour.gallons <= threshold) return;

    const hourKey = latestHour.hourEnd.toISOString().replace(/[^0-9]/g, "");
    const alertRef = db.collection("boiler_consumption_alerts")
      .doc(`${boilerId}_${hourKey}`);
    const created = await db.runTransaction(async (transaction) => {
      const existing = await transaction.get(alertRef);
      if (existing.exists) return false;
      transaction.create(alertRef, {
        id: alertRef.id,
        boilerId,
        hourEnd: Timestamp.fromDate(latestHour.hourEnd),
        normalizedBunkerGallons: latestHour.gallons,
        thresholdGallons: threshold,
        pressurePsi: latestHour.pressurePsi,
        recipientUids: notificationRecipientUids,
        status: "pending",
        createdAt: FieldValue.serverTimestamp(),
      });
      return true;
    });
    if (!created) return;

    const tokenSnapshot = await db.collection("notification_tokens")
      .where("uid", "in", notificationRecipientUids)
      .get();
    const tokens = tokenSnapshot.docs
      .filter((doc) => doc.data().active === true)
      .map((doc) => text(doc.data().token))
      .filter((token) => token.length > 0);
    if (tokens.length === 0) {
      await alertRef.update({status: "no_registered_devices", updatedAt: FieldValue.serverTimestamp()});
      return;
    }

    const pressureText = latestHour.pressurePsi == null
      ? "presión no disponible"
      : `${latestHour.pressurePsi.toFixed(0)} PSI`;
    const response = await getMessaging().sendEachForMulticast({
      tokens: [...new Set(tokens)],
      notification: {
        title: `Alarma de búnker: ${boilerId}`,
        body: `${latestHour.gallons.toFixed(0)} gal/h supera el límite de ${threshold} gal/h (${pressureText}).`,
      },
      data: {
        type: "normalized_bunker_alarm",
        boilerId,
        hourEnd: latestHour.hourEnd.toISOString(),
        normalizedBunkerGallons: latestHour.gallons.toFixed(2),
        thresholdGallons: threshold.toString(),
      },
    });
    await alertRef.update({
      status: "sent",
      notificationCount: response.successCount,
      failedNotificationCount: response.failureCount,
      sentAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  },
);
