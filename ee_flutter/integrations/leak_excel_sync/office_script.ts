interface Delivery {
  status: string;
  batchId: string;
  cursorStartUtc: string;
  cursorEndUtc: string;
  rowCount: number;
}

interface Dataset {
  columns: string[];
  rows: (string | number | boolean)[][];
}

interface LeakPayload {
  schemaVersion: number;
  collection: string;
  generatedAtUtc: string;
  timezone: string;
  delivery: Delivery;
  dataset: Dataset;
}

function main(workbook: ExcelScript.Workbook, payloadJson: string): string {
  const payload = JSON.parse(payloadJson) as LeakPayload;
  if (payload.collection !== "leak_reports") {
    throw new Error("El payload no corresponde a reportes de fugas.");
  }
  if (payload.delivery.status !== "ready") {
    return payloadJson;
  }
  if (!payload.dataset.columns.length || payload.dataset.columns[0] !== "id") {
    throw new Error("El dataset de fugas no contiene la clave id.");
  }

  const sheetName = "App_Fugas";
  const tableName = "tblAppFugas";
  let sheet = workbook.getWorksheet(sheetName);
  if (!sheet) sheet = workbook.addWorksheet(sheetName);

  let table = workbook.getTable(tableName);
  if (!table) {
    const headerRange = sheet.getRangeByIndexes(
      0,
      0,
      1,
      payload.dataset.columns.length,
    );
    headerRange.setValues([payload.dataset.columns]);
    table = sheet.addTable(headerRange, true);
    table.setName(tableName);
  }

  const currentHeaders = table.getHeaderRowRange().getValues()[0].map(String);
  if (JSON.stringify(currentHeaders) !== JSON.stringify(payload.dataset.columns)) {
    throw new Error("Las columnas de App_Fugas no coinciden con el payload.");
  }

  const existingRows = table.getRangeBetweenHeaderAndTotal().getValues();
  const rowById = new Map<string, number>();
  existingRows.forEach((row, index) => rowById.set(String(row[0]), index));

  const updates: {index: number; row: (string | number | boolean)[]}[] = [];
  const additions: (string | number | boolean)[][] = [];
  payload.dataset.rows.forEach((row) => {
    const existingIndex = rowById.get(String(row[0]));
    if (existingIndex === undefined) additions.push(row);
    else updates.push({index: existingIndex, row});
  });

  if (additions.length) table.addRows(-1, additions);
  updates.forEach(({index, row}) => {
    table
      .getRangeBetweenHeaderAndTotal()
      .getCell(index, 0)
      .getResizedRange(0, row.length - 1)
      .setValues([row]);
  });
  sheet.getUsedRange()?.getFormat().autofitColumns();

  return JSON.stringify({
    schemaVersion: payload.schemaVersion,
    collection: payload.collection,
    generatedAtUtc: payload.generatedAtUtc,
    timezone: payload.timezone,
    delivery: {
      ...payload.delivery,
      status: "acknowledged",
      acknowledgedAtUtc: new Date().toISOString(),
      insertedRows: additions.length,
      updatedRows: updates.length,
    },
  });
}
