import {readFileSync} from "node:fs";
import {resolve} from "node:path";

import {
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
} from "firebase/firestore";
import {afterAll, afterEach, beforeAll, describe, it} from "vitest";

let environment: RulesTestEnvironment;

beforeAll(async () => {
  environment = await initializeTestEnvironment({
    projectId: "eficiencia-energetica-ee-test",
    firestore: {
      rules: readFileSync(resolve(__dirname, "../../firestore.rules"), "utf8"),
    },
  });
});

afterEach(async () => {
  await environment.clearFirestore();
});

afterAll(async () => {
  await environment.cleanup();
});

function trapReport(uid: string) {
  return {
    id: "trap-1",
    sectionId: "refineria",
    equipmentName: "Equipo 1",
    calculationMethod: "direct",
    createdAt: serverTimestamp(),
    createdByUid: uid,
    updatedAt: serverTimestamp(),
    updatedByUid: uid,
    appVersion: "1.0.1+2",
    platform: "web",
    schemaVersion: 1,
    status: "synced",
    source: "manual",
  };
}

function leakReport(uid: string) {
  return {
    id: "leak-1",
    sectionId: "1",
    sectionCode: "1",
    sectionNameSnapshot: "REFINERIA",
    processCode: "",
    processNameSnapshot: "",
    equipmentCode: "",
    equipmentName: "",
    systemCode: "",
    systemNameSnapshot: "",
    destinationId: "",
    selectionDepth: "section",
    locationReference: "Linea 1",
    leakType: "steam",
    leakNumber: 1,
    tagNumber: "25",
    photoProvider: "cloudinary",
    photoUrl: "https://example.test/photo.jpg",
    workOrderCreated: false,
    workCompleted: false,
    createdAt: serverTimestamp(),
    createdByUid: uid,
    updatedAt: serverTimestamp(),
    updatedByUid: uid,
    appVersion: "1.0.1+2",
    platform: "android",
    schemaVersion: 2,
    status: "open",
    source: "manual",
  };
}

function pressureReading(uid: string) {
  return {
    id: "pressure-1",
    recordedAt: new Date(),
    pressureUnit: "psi",
    sectionId: "servicios_industriales",
    sectionNameSnapshot: "Servicios Industriales",
    equipmentName: "Distribuidores de vapor de calderas",
    equipmentNameNormalized: "distribuidores de vapor de calderas",
    cleaverDistributorPsi: {
      omega: 80,
      lambda: 81,
      omicron: 82,
      beta: 83,
      hydrogenation: 84,
    },
    distral900DistributorPsi: {
      soapPlant: 70,
      desmetTirtioux: 71,
      newLine: 72,
      cleaverInlet: 73,
      bleachers: 74,
      marino: 75,
      padLoading: 76,
      receptionTanks: 77,
      waterTank4: 78,
    },
    createdAt: serverTimestamp(),
    createdByUid: uid,
    updatedAt: serverTimestamp(),
    updatedByUid: uid,
    appVersion: "1.1.0+3",
    platform: "android",
    schemaVersion: 2,
    boilerPressurePsi: 155,
    boilerPressureUnit: "psi",
    status: "synced",
    source: "manual",
  };
}

function boilerReading(uid: string, mode = "cumulative_meter") {
  return {
    id: "alfa_laval_1200_2026072415",
    boilerId: "alfa_laval_1200",
    readingMode: mode,
    createdAt: serverTimestamp(),
    createdByUid: uid,
    updatedAt: serverTimestamp(),
    updatedByUid: uid,
    appVersion: "1.1.0+3",
    platform: "android",
    schemaVersion: 1,
    status: "synced",
    source: "manual",
  };
}

describe("Firestore rules", () => {
  it("allows public app update configuration reads", async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "app_config/mobile_app"), {
        enabled: true,
      });
    });
    const anonymous = environment.unauthenticatedContext().firestore();
    await assertSucceeds(getDoc(doc(anonymous, "app_config/mobile_app")));
  });

  it("rejects unauthenticated report creation", async () => {
    const anonymous = environment.unauthenticatedContext().firestore();
    await assertFails(
      setDoc(
        doc(anonymous, "steam_trap_sizing_reports/trap-1"),
        trapReport("operator-1"),
      ),
    );
  });

  it("allows an operator to create and read an own report", async () => {
    const operator = environment
      .authenticatedContext("operator-1", {role: "operator"})
      .firestore();
    const reference = doc(operator, "steam_trap_sizing_reports/trap-1");
    await assertSucceeds(setDoc(reference, trapReport("operator-1")));
    await assertSucceeds(getDoc(reference));
  });

  it("allows a signed-in user to create only their operator profile", async () => {
    const operator = environment.authenticatedContext("operator-1").firestore();
    await assertSucceeds(
      setDoc(doc(operator, "users/operator-1"), {
        id: "operator-1",
        displayName: "Operador Uno",
        nationalId: "1234567890",
        role: "operator",
        active: true,
        createdAt: serverTimestamp(),
        createdByUid: "operator-1",
        updatedAt: serverTimestamp(),
        updatedByUid: "operator-1",
        source: "self_registration",
      }),
    );
    await assertFails(
      setDoc(doc(operator, "users/admin-1"), {
        id: "admin-1",
        displayName: "Admin",
        nationalId: "1234567890",
        role: "admin",
        active: true,
        createdAt: serverTimestamp(),
        createdByUid: "operator-1",
        updatedAt: serverTimestamp(),
        updatedByUid: "operator-1",
        source: "self_registration",
      }),
    );
  });

  it("shares maintenance reports and limits workflow updates", async () => {
    const creator = environment.authenticatedContext("operator-1").firestore();
    const reference = doc(creator, "leak_reports/leak-1");
    await assertSucceeds(setDoc(reference, leakReport("operator-1")));

    const secondOperator = environment
      .authenticatedContext("operator-2")
      .firestore();
    const sharedReference = doc(secondOperator, "leak_reports/leak-1");
    await assertSucceeds(getDoc(sharedReference));
    await assertSucceeds(
      updateDoc(sharedReference, {
        workOrderCreated: true,
        workOrderCreatedAt: serverTimestamp(),
        workOrderCreatedByUid: "operator-2",
        workOrderCreatedByNameSnapshot: "Operador Dos",
        workCompleted: false,
        status: "work_order_created",
        updatedAt: serverTimestamp(),
        updatedByUid: "operator-2",
      }),
    );
    await assertFails(updateDoc(sharedReference, {sectionId: "dex"}));
  });

  it("accepts partial leak destinations and rejects orphan child codes", async () => {
    const operator = environment
      .authenticatedContext("operator-1", {role: "operator"})
      .firestore();
    const partial = leakReport("operator-1");
    partial.leakType = "condensate";
    await assertSucceeds(
      setDoc(doc(operator, "leak_reports/leak-partial"), partial),
    );

    const orphan = leakReport("operator-1");
    orphan.sectionId = "";
    orphan.sectionCode = "";
    orphan.processCode = "1";
    orphan.selectionDepth = "process";
    await assertFails(
      setDoc(doc(operator, "leak_reports/leak-orphan"), orphan),
    );
  });

  it("keeps schema 1 leak creation compatible during the app rollout", async () => {
    const operator = environment
      .authenticatedContext("operator-1", {role: "operator"})
      .firestore();
    const legacy: Record<string, unknown> = leakReport("operator-1");
    legacy.schemaVersion = 1;
    delete legacy.sectionCode;
    delete legacy.processCode;
    delete legacy.processNameSnapshot;
    delete legacy.equipmentCode;
    delete legacy.systemCode;
    delete legacy.systemNameSnapshot;
    delete legacy.destinationId;
    delete legacy.selectionDepth;
    delete legacy.leakNumber;
    await assertSucceeds(
      setDoc(doc(operator, "leak_reports/leak-legacy"), legacy),
    );
  });

  it("only permits sequential increments of the leak counter", async () => {
    const operator = environment
      .authenticatedContext("operator-1", {role: "operator"})
      .firestore();
    const counter = doc(operator, "maintenance_counters/leak_reports");
    await assertSucceeds(
      setDoc(counter, {
        nextNumber: 1,
        updatedAt: serverTimestamp(),
        updatedByUid: "operator-1",
      }),
    );
    await assertSucceeds(
      updateDoc(counter, {
        nextNumber: 2,
        updatedAt: serverTimestamp(),
        updatedByUid: "operator-1",
      }),
    );
    await assertFails(updateDoc(counter, {nextNumber: 4}));
    await assertFails(deleteDoc(counter));
  });

  it("rejects a forged createdByUid", async () => {
    const operator = environment
      .authenticatedContext("operator-1", {role: "operator"})
      .firestore();
    await assertFails(
      setDoc(
        doc(operator, "steam_trap_sizing_reports/trap-1"),
        trapReport("operator-2"),
      ),
    );
  });

  it("accepts complete pressure readings and rejects invalid pressure data", async () => {
    const operator = environment
      .authenticatedContext("operator-1", {role: "operator"})
      .firestore();
    const validReference = doc(
      operator,
      "steam_pressure_readings/pressure-1",
    );
    await assertSucceeds(
      setDoc(validReference, pressureReading("operator-1")),
    );
    await assertSucceeds(getDoc(validReference));

    const invalid = pressureReading("operator-1");
    invalid.cleaverDistributorPsi.omega = -1;
    await assertFails(
      setDoc(
        doc(operator, "steam_pressure_readings/pressure-invalid"),
        invalid,
      ),
    );
  });

  it("allows only cumulative boiler readings for new records", async () => {
    const operator = environment
      .authenticatedContext("operator-1", {role: "operator"})
      .firestore();
    await assertSucceeds(
      setDoc(
        doc(
          operator,
          "boiler_consumption_readings/alfa_laval_1200_2026072415",
        ),
        boilerReading("operator-1"),
      ),
    );
    await assertFails(
      setDoc(
        doc(
          operator,
          "boiler_consumption_readings/alfa_laval_1200_2026072416",
        ),
        boilerReading("operator-1", "interval_consumption"),
      ),
    );
  });

  it("allows signed-in users to read shared boiler readings", async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(
          context.firestore(),
          "boiler_consumption_readings/alfa_laval_1200_2026072415",
        ),
        {
          ...boilerReading("operator-1"),
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      );
    });
    const anotherOperator = environment
      .authenticatedContext("operator-2", {role: "operator"})
      .firestore();
    await assertSucceeds(
      getDoc(
        doc(
          anotherOperator,
          "boiler_consumption_readings/alfa_laval_1200_2026072415",
        ),
      ),
    );
  });

  it("allows admin reads but denies client deletion", async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "steam_trap_sizing_reports/trap-1"),
        {...trapReport("operator-1"), createdAt: new Date(), updatedAt: new Date()},
      );
    });
    const admin = environment
      .authenticatedContext("admin-1", {role: "admin"})
      .firestore();
    const reference = doc(admin, "steam_trap_sizing_reports/trap-1");
    await assertSucceeds(getDoc(reference));
    await assertFails(deleteDoc(reference));
  });
});
