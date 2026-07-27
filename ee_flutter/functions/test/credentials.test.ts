import {describe, expect, it} from "vitest";

import {
  credentialLookupId,
  isAcceptedOperatorNationalId,
  isValidEcuadorianNationalId,
  isValidPin,
  normalizeNationalId,
} from "../src/credentials";

describe("operator credentials", () => {
  it("validates Ecuadorian natural-person IDs", () => {
    expect(isValidEcuadorianNationalId("1710034065")).toBe(true);
    expect(isValidEcuadorianNationalId("1700000019")).toBe(true);
    expect(isValidEcuadorianNationalId("1710034064")).toBe(false);
    expect(isValidEcuadorianNationalId("1234512345")).toBe(false);
    expect(isValidEcuadorianNationalId("0010034065")).toBe(false);
  });

  it("accepts numeric PINs without normalizing them", () => {
    expect(isValidPin("0123")).toBe(true);
    expect(isValidPin("123456")).toBe(true);
    expect(isValidPin("123")).toBe(false);
    expect(isValidPin("12a4")).toBe(false);
  });

  it("allows arbitrary ten-digit IDs only in emulator mode", () => {
    expect(isAcceptedOperatorNationalId("1234512345", true)).toBe(true);
    expect(isAcceptedOperatorNationalId("1234512345", false)).toBe(false);
    expect(isAcceptedOperatorNationalId("12345", true)).toBe(false);
  });

  it("keeps leading zeroes in national IDs", () => {
    expect(normalizeNationalId(" 0123456789 ")).toBe("0123456789");
  });

  it("uses a keyed, non-reversible lookup identifier", () => {
    const first = credentialLookupId("1710034065", "pepper-one");
    const second = credentialLookupId("1710034065", "pepper-two");
    expect(first).toHaveLength(64);
    expect(first).not.toBe("1710034065");
    expect(first).not.toBe(second);
  });
});
