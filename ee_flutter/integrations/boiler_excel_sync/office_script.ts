type CellValue = string | number | boolean;

interface SyncDataset {
  headers: string[];
  rows: unknown[][];
}

interface SyncPayload {
  schemaVersion: number;
  generatedAtUtc: string;
  timezone: string;
  collection: string;
  mode?: string;
  delivery?: {
    status: string;
    batchId: string;
    cursorStartUtc: string;
    cursorEndUtc: string;
    targetLocalDate: string;
    rawRowCount: number;
    remainingDates?: string[];
    acknowledgedAtUtc?: string;
  };
  datasets: {
    raw: SyncDataset;
    intervals: SyncDataset;
    hourly: SyncDataset;
    daily: SyncDataset;
  };
}

interface MappingEntry {
  rowNumber: number;
  status: string;
}

interface DatasetSyncResult {
  created: number;
  updated: number;
}

const MASTER_SHEET = "Regist_inform";
const FIRST_MASTER_DATA_ROW_INDEX = 12;
const MASTER_COLUMN_COUNT = 16;
const MAPPING_SHEET = "App_Mapeo_Regist";
const FIRST_APP_SYNC_DATE = "2026-07-24";

function main(workbook: ExcelScript.Workbook, payloadJson: string): string {
  const payload = JSON.parse(payloadJson) as SyncPayload;
  validatePayload(payload);

  const datasetResults = {
    raw: upsertDatasetSheet(
      workbook,
      "App_Datos_Firestore",
      payload.datasets.raw,
      [0],
    ),
    intervals: upsertDatasetSheet(
      workbook,
      "App_Intervalos",
      payload.datasets.intervals,
      [0],
    ),
    hourly: upsertDatasetSheet(
      workbook,
      "App_Consumo_Horario",
      payload.datasets.hourly,
      [0, 3, 15],
    ),
    daily: upsertDatasetSheet(
      workbook,
      "App_Resumen_Diario",
      payload.datasets.daily,
      [0],
    ),
  };

  const result = syncMasterRows(
    workbook,
    payload.datasets.daily.rows,
    payload.generatedAtUtc,
  );
  writeControlSheet(workbook, payload, result, datasetResults);
  return buildAcknowledgement(payload);
}

function validatePayload(payload: SyncPayload): void {
  if (payload.schemaVersion !== 1 && payload.schemaVersion !== 2) {
    throw new Error(`Unsupported payload schema: ${payload.schemaVersion}`);
  }
  if (!payload.datasets?.raw || !payload.datasets?.daily) {
    throw new Error("The payload does not contain the required datasets.");
  }
}

function buildAcknowledgement(payload: SyncPayload): string {
  const emptyDataset: SyncDataset = { headers: [], rows: [] };
  return JSON.stringify({
    schemaVersion: 2,
    generatedAtUtc: new Date().toISOString(),
    timezone: payload.timezone,
    collection: payload.collection,
    mode: "acknowledgement",
    windowStartUtc: payload.delivery?.cursorEndUtc ?? "",
    affectedDates: [],
    delivery: {
      status: "acknowledged",
      batchId: payload.delivery?.batchId ?? "",
      cursorStartUtc: payload.delivery?.cursorStartUtc ?? "",
      cursorEndUtc: payload.delivery?.cursorEndUtc ?? "",
      targetLocalDate: payload.delivery?.targetLocalDate ?? "",
      rawRowCount: payload.delivery?.rawRowCount ?? 0,
      remainingDates: payload.delivery?.remainingDates ?? [],
      acknowledgedAtUtc: new Date().toISOString(),
    },
    datasets: {
      raw: emptyDataset,
      intervals: emptyDataset,
      hourly: emptyDataset,
      daily: emptyDataset,
    },
  });
}

function normalizeCell(value: unknown): CellValue {
  if (value === null || value === undefined) {
    return "";
  }
  if (
    typeof value === "string" ||
    typeof value === "number" ||
    typeof value === "boolean"
  ) {
    return value;
  }
  return JSON.stringify(value);
}

function normalizeRows(rows: unknown[][]): CellValue[][] {
  return rows.map((row) => row.map((value) => normalizeCell(value)));
}

function upsertDatasetSheet(
  workbook: ExcelScript.Workbook,
  sheetName: string,
  dataset: SyncDataset,
  keyIndexes: number[],
): DatasetSyncResult {
  const sheet =
    workbook.getWorksheet(sheetName) ?? workbook.addWorksheet(sheetName);

  if (dataset.headers.length === 0) {
    return { created: 0, updated: 0 };
  }
  const columnCount = dataset.headers.length;
  const existingUsed = sheet.getUsedRange(true);
  const hasExistingHeader =
    existingUsed !== undefined && existingUsed.getRowCount() > 0;
  const headerRange = sheet.getRangeByIndexes(
    0,
    0,
    1,
    columnCount,
  );
  if (hasExistingHeader) {
    const currentHeaders = headerRange.getValues()[0];
    for (let index = 0; index < columnCount; index += 1) {
      if (String(currentHeaders[index] ?? "") !== dataset.headers[index]) {
        throw new Error(
          `Header mismatch in ${sheetName}, column ${index + 1}.`,
        );
      }
    }
  } else {
    headerRange.setValues([dataset.headers]);
  }
  headerRange.getFormat().getFill().setColor("#1F1F1F");
  headerRange.getFormat().getFont().setColor("#FFFFFF");
  headerRange.getFormat().getFont().setBold(true);
  headerRange.getFormat().setWrapText(true);

  const rows = normalizeRows(dataset.rows);
  const existingByKey = new Map<string, number>();
  const usedAfterHeader = sheet.getUsedRange(true);
  let nextRowIndex = 1;
  if (usedAfterHeader && usedAfterHeader.getRowCount() > 1) {
    const lastRowIndex =
      usedAfterHeader.getRowIndex() + usedAfterHeader.getRowCount() - 1;
    const existingRows = sheet
      .getRangeByIndexes(1, 0, lastRowIndex, columnCount)
      .getValues();
    for (let offset = 0; offset < existingRows.length; offset += 1) {
      const key = datasetKey(existingRows[offset], keyIndexes);
      if (key) {
        existingByKey.set(key, offset + 1);
      }
    }
    nextRowIndex = lastRowIndex + 1;
  }

  let updated = 0;
  const rowsToAppend: CellValue[][] = [];
  for (const row of rows) {
    if (row.length !== columnCount) {
      throw new Error(
        `Invalid row width in ${sheetName}: ${row.length} != ${columnCount}.`,
      );
    }
    const key = datasetKey(row, keyIndexes);
    if (!key) {
      continue;
    }
    const existingRowIndex = existingByKey.get(key);
    if (existingRowIndex !== undefined) {
      sheet
        .getRangeByIndexes(existingRowIndex, 0, 1, columnCount)
        .setValues([row]);
      updated += 1;
    } else {
      rowsToAppend.push(row);
      existingByKey.set(key, nextRowIndex + rowsToAppend.length - 1);
    }
  }

  const chunkSize = 500;
  for (let offset = 0; offset < rowsToAppend.length; offset += chunkSize) {
    const chunk = rowsToAppend.slice(offset, offset + chunkSize);
    sheet
      .getRangeByIndexes(
        nextRowIndex + offset,
        0,
        chunk.length,
        columnCount,
      )
      .setValues(chunk);
  }
  const used = sheet.getUsedRange();
  if (used) {
    used.getFormat().autofitColumns();
  }
  sheet.getFreezePanes().freezeRows(1);
  return { created: rowsToAppend.length, updated };
}

function datasetKey(
  row: CellValue[],
  keyIndexes: number[],
): string {
  const parts = keyIndexes.map((index) => String(row[index] ?? "").trim());
  if (parts.some((part) => part === "")) {
    return "";
  }
  return parts.join("|");
}

function syncMasterRows(
  workbook: ExcelScript.Workbook,
  dailyRows: unknown[][],
  generatedAtUtc: string,
): {
  created: number;
  updated: number;
  conflicts: number;
  skipped: number;
} {
  const master = workbook.getWorksheet(MASTER_SHEET);
  if (!master) {
    throw new Error(`Worksheet ${MASTER_SHEET} was not found.`);
  }
  const mappingSheet =
    workbook.getWorksheet(MAPPING_SHEET) ?? workbook.addWorksheet(MAPPING_SHEET);
  const mapping = readMapping(mappingSheet);
  const existingRows = readExistingMasterRows(master);

  let created = 0;
  let updated = 0;
  let conflicts = 0;
  let skipped = 0;
  let nextRowIndex = findLastMasterRowIndex(master) + 1;

  for (const sourceRow of dailyRows) {
    const row = sourceRow.map((value) => normalizeCell(value));
    const syncKey = String(row[0] ?? "");
    if (!syncKey || row.length < 17) {
      skipped += 1;
      continue;
    }
    const mapped = mapping.get(syncKey);
    if (
      mapped?.status === "conflict_historical"
      && !isRecoverableAppRow(syncKey)
    ) {
      conflicts += 1;
      continue;
    }
    if (mapped && mapped.rowNumber >= FIRST_MASTER_DATA_ROW_INDEX + 1) {
      const rowIndex = mapped.rowNumber - 1;
      if (masterRowMatches(master, rowIndex, syncKey)) {
        writeMasterRow(master, rowIndex, row, false);
        updated += 1;
        continue;
      }
      mapping.set(syncKey, { rowNumber: 0, status: "mapping_invalid" });
      conflicts += 1;
      continue;
    }
    const existingRowIndex = existingRows.get(syncKey);
    if (
      existingRowIndex !== undefined
      && isRecoverableAppRow(syncKey)
    ) {
      writeMasterRow(master, existingRowIndex, row, false);
      mapping.set(syncKey, {
        rowNumber: existingRowIndex + 1,
        status: "managed",
      });
      updated += 1;
      continue;
    }
    if (existingRowIndex !== undefined) {
      mapping.set(syncKey, { rowNumber: 0, status: "conflict_historical" });
      conflicts += 1;
      continue;
    }

    writeMasterRow(master, nextRowIndex, row, true);
    mapping.set(syncKey, {
      rowNumber: nextRowIndex + 1,
      status: "managed",
    });
    existingRows.set(syncKey, nextRowIndex);
    nextRowIndex += 1;
    created += 1;
  }

  writeMapping(mappingSheet, mapping, generatedAtUtc);
  return { created, updated, conflicts, skipped };
}

function readMapping(sheet: ExcelScript.Worksheet): Map<string, MappingEntry> {
  const result = new Map<string, MappingEntry>();
  const used = sheet.getUsedRange(true);
  if (!used || used.getRowCount() < 2) {
    return result;
  }
  const values = used.getValues();
  for (let index = 1; index < values.length; index += 1) {
    const key = String(values[index][0] ?? "");
    const rowNumber = Number(values[index][1] ?? 0);
    const status = String(values[index][2] ?? "");
    if (key) {
      result.set(key, { rowNumber, status });
    }
  }
  return result;
}

function isRecoverableAppRow(syncKey: string): boolean {
  const dateIso = syncKey.slice(0, 10);
  return /^\d{4}-\d{2}-\d{2}$/.test(dateIso)
    && dateIso >= FIRST_APP_SYNC_DATE;
}

function writeMapping(
  sheet: ExcelScript.Worksheet,
  mapping: Map<string, MappingEntry>,
  generatedAtUtc: string,
): void {
  sheet.getUsedRange()?.clear(ExcelScript.ClearApplyTo.all);
  const rows: CellValue[][] = [
    ["syncKey", "rowNumber", "status", "lastSyncUtc"],
  ];
  for (const [key, entry] of mapping.entries()) {
    rows.push([key, entry.rowNumber, entry.status, generatedAtUtc]);
  }
  sheet.getRangeByIndexes(0, 0, rows.length, 4).setValues(rows);
  const header = sheet.getRange("A1:D1");
  header.getFormat().getFill().setColor("#1F1F1F");
  header.getFormat().getFont().setColor("#FFFFFF");
  header.getFormat().getFont().setBold(true);
  sheet.getUsedRange()?.getFormat().autofitColumns();
  sheet.getFreezePanes().freezeRows(1);
}

function readExistingMasterRows(
  sheet: ExcelScript.Worksheet,
): Map<string, number> {
  const result = new Map<string, number>();
  const lastRowIndex = findLastMasterRowIndex(sheet);
  if (lastRowIndex < FIRST_MASTER_DATA_ROW_INDEX) {
    return result;
  }
  const values = sheet
    .getRangeByIndexes(
      FIRST_MASTER_DATA_ROW_INDEX,
      0,
      lastRowIndex - FIRST_MASTER_DATA_ROW_INDEX + 1,
      7,
    )
    .getValues();
  for (let offset = 0; offset < values.length; offset += 1) {
    const dateIso = excelDateToIso(values[offset][0]);
    const boilerId = boilerIdFromMasterName(String(values[offset][6] ?? ""));
    if (dateIso && boilerId) {
      result.set(
        `${dateIso}|${boilerId}`,
        FIRST_MASTER_DATA_ROW_INDEX + offset,
      );
    }
  }
  return result;
}

function findLastMasterRowIndex(sheet: ExcelScript.Worksheet): number {
  const used = sheet.getUsedRange(true);
  if (!used) {
    return FIRST_MASTER_DATA_ROW_INDEX - 1;
  }
  return Math.max(
    FIRST_MASTER_DATA_ROW_INDEX - 1,
    used.getRowIndex() + used.getRowCount() - 1,
  );
}

function masterRowMatches(
  sheet: ExcelScript.Worksheet,
  rowIndex: number,
  syncKey: string,
): boolean {
  const values = sheet.getRangeByIndexes(rowIndex, 0, 1, 7).getValues()[0];
  const dateIso = excelDateToIso(values[0]);
  const boilerId = boilerIdFromMasterName(String(values[6] ?? ""));
  return `${dateIso}|${boilerId}` === syncKey;
}

function writeMasterRow(
  sheet: ExcelScript.Worksheet,
  rowIndex: number,
  source: CellValue[],
  isNew: boolean,
): void {
  const target = sheet.getRangeByIndexes(
    rowIndex,
    0,
    1,
    MASTER_COLUMN_COUNT,
  );
  if (isNew && rowIndex > FIRST_MASTER_DATA_ROW_INDEX) {
    target.copyFrom(
      sheet.getRangeByIndexes(
        rowIndex - 1,
        0,
        1,
        MASTER_COLUMN_COUNT,
      ),
      ExcelScript.RangeCopyType.all,
    );
  }

  const excelDate = isoDateToExcelSerial(String(source[1]));
  const excelRow = rowIndex + 1;
  target.setValues([
    [
      excelDate,
      "",
      "",
      "",
      numberOrBlank(source[5]),
      "",
      source[7],
      numberOrZero(source[8]),
      numberOrZero(source[9]),
      numberOrZero(source[10]),
      numberOrZero(source[11]),
      numberOrZero(source[12]),
      numberOrZero(source[13]),
      numberOrZero(source[14]),
      "",
      "",
    ],
  ]);
  sheet
    .getCell(rowIndex, 0)
    .setNumberFormat([["dd-mmm-yyyy"]]);
  sheet
    .getCell(rowIndex, 1)
    .setFormula(`=IF(A${excelRow}<>"",TEXT(A${excelRow},"dddd"),"")`);
  sheet.getCell(rowIndex, 2).setFormula(`=YEAR(A${excelRow})`);
  sheet.getCell(rowIndex, 3).setFormula(`=TEXT(A${excelRow},"MMM")`);
  sheet
    .getCell(rowIndex, 5)
    .setFormula(`=CONCATENATE("S ",WEEKNUM(A${excelRow}))`);
  sheet
    .getCell(rowIndex, 9)
    .setFormula(`=I${excelRow}-H${excelRow}`);
  sheet
    .getCell(rowIndex, 14)
    .setFormula(`=IFERROR((N${excelRow}*3.785)/1000,"")`);
  sheet
    .getCell(rowIndex, 15)
    .setFormula(`=IFERROR(M${excelRow}/O${excelRow},"")`);
}

function writeControlSheet(
  workbook: ExcelScript.Workbook,
  payload: SyncPayload,
  result: {
    created: number;
    updated: number;
    conflicts: number;
    skipped: number;
  },
  datasetResults: {
    raw: DatasetSyncResult;
    intervals: DatasetSyncResult;
    hourly: DatasetSyncResult;
    daily: DatasetSyncResult;
  },
): void {
  const sheet =
    workbook.getWorksheet("App_Control") ?? workbook.addWorksheet("App_Control");
  sheet.getUsedRange()?.clear(ExcelScript.ClearApplyTo.all);
  const rows: CellValue[][] = [
    ["Campo", "Valor"],
    ["Estado", result.conflicts > 0 ? "Completado con conflictos" : "Completado"],
    ["Ultima sincronizacion UTC", payload.generatedAtUtc],
    ["Zona horaria", payload.timezone],
    ["Coleccion Firestore", payload.collection],
    ["Filas crudas", payload.datasets.raw.rows.length],
    ["Intervalos", payload.datasets.intervals.rows.length],
    ["Filas horarias", payload.datasets.hourly.rows.length],
    ["Filas diarias", payload.datasets.daily.rows.length],
    ["Datos crudos nuevos", datasetResults.raw.created],
    ["Datos crudos actualizados", datasetResults.raw.updated],
    ["Intervalos nuevos", datasetResults.intervals.created],
    ["Intervalos actualizados", datasetResults.intervals.updated],
    ["Filas horarias nuevas", datasetResults.hourly.created],
    ["Filas horarias actualizadas", datasetResults.hourly.updated],
    ["Resumenes diarios nuevos", datasetResults.daily.created],
    ["Resumenes diarios actualizados", datasetResults.daily.updated],
    ["Filas nuevas en Regist_inform", result.created],
    ["Filas actualizadas en Regist_inform", result.updated],
    ["Conflictos historicos no sobrescritos", result.conflicts],
    ["Filas omitidas", result.skipped],
  ];
  sheet.getRangeByIndexes(0, 0, rows.length, 2).setValues(rows);
  const header = sheet.getRange("A1:B1");
  header.getFormat().getFill().setColor("#1F1F1F");
  header.getFormat().getFont().setColor("#FFFFFF");
  header.getFormat().getFont().setBold(true);
  sheet.getUsedRange()?.getFormat().autofitColumns();
}

function boilerIdFromMasterName(name: string): string {
  const normalized = name.trim().toLowerCase();
  if (normalized === "calalfa") {
    return "alfa_laval_1200";
  }
  if (normalized === "900distral") {
    return "distral_900";
  }
  if (normalized === "calcleaver") {
    return "cleaver_brooks_1200";
  }
  return "";
}

function isoDateToExcelSerial(value: string): number {
  const parts = value.split("-").map((part) => Number(part));
  if (parts.length !== 3 || parts.some((part) => !Number.isFinite(part))) {
    throw new Error(`Invalid ISO date: ${value}`);
  }
  return Date.UTC(parts[0], parts[1] - 1, parts[2]) / 86400000 + 25569;
}

function excelDateToIso(value: CellValue): string {
  if (typeof value === "number") {
    return new Date(Math.round((value - 25569) * 86400000))
      .toISOString()
      .slice(0, 10);
  }
  if (typeof value === "string" && /^\d{4}-\d{2}-\d{2}/.test(value)) {
    return value.slice(0, 10);
  }
  return "";
}

function numberOrZero(value: CellValue): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

function numberOrBlank(value: CellValue): number | string {
  if (value === "") {
    return "";
  }
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : "";
}
