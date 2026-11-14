import { generateQrCode, QR_ALPHABET, QR_CODE_RE } from "./qr-code";

describe("generateQrCode (FR-047)", () => {
  it("is 8 characters without ambiguous ones", () => {
    for (let i = 0; i < 500; i++) {
      const code = generateQrCode();
      expect(code).toMatch(QR_CODE_RE);
      expect(code).not.toMatch(/[01OIL]/);
    }
    expect(QR_ALPHABET).not.toMatch(/[01OIL]/);
  });

  it("uses the injected random source", () => {
    expect(generateQrCode(() => 0)).toBe("22222222");
  });

  it("is not sequential", () => {
    const codes = new Set(Array.from({ length: 1000 }, () => generateQrCode()));
    expect(codes.size).toBe(1000);
  });
});
