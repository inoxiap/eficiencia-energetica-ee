import {createHmac} from "node:crypto";

export function normalizeNationalId(value: unknown): string {
  if (typeof value !== "string") return "";
  return value.trim();
}

export function isValidEcuadorianNationalId(value: string): boolean {
  if (!/^\d{10}$/.test(value)) return false;
  const province = Number(value.slice(0, 2));
  const thirdDigit = Number(value[2]);
  if (province < 1 || province > 24 || thirdDigit >= 6) return false;

  const digits = [...value].map(Number);
  let total = 0;
  for (let index = 0; index < 9; index += 1) {
    let product = digits[index] * (index % 2 === 0 ? 2 : 1);
    if (product > 9) product -= 9;
    total += product;
  }
  const checkDigit = (10 - (total % 10)) % 10;
  return checkDigit === digits[9];
}

export function isAcceptedOperatorNationalId(
  value: string,
  allowTestIds = false,
): boolean {
  if (allowTestIds) return /^\d{10}$/.test(value);
  return isValidEcuadorianNationalId(value);
}

export function isValidPin(value: unknown): value is string {
  return typeof value === "string" && /^\d{4,6}$/.test(value);
}

export function credentialLookupId(
  nationalId: string,
  pepper: string,
): string {
  return createHmac("sha256", pepper).update(nationalId).digest("hex");
}
