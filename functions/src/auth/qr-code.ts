import { randomInt } from "node:crypto";

/** FR-047: no 0/O, 1/I/L. Upper case; look-ups should upper-case input. */
export const QR_ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ";
export const QR_CODE_LENGTH = 8;

/**
 * A random, non-sequential QR short code (FR-047, BR-006).
 *
 * @param random Random integer source in [0, max). Injected by tests.
 * @return An 8-character code.
 */
export function generateQrCode(random: (max: number) => number = randomInt): string {
  let code = "";
  for (let i = 0; i < QR_CODE_LENGTH; i++) {
    code += QR_ALPHABET[random(QR_ALPHABET.length)];
  }
  return code;
}

export const QR_CODE_RE = new RegExp(`^[${QR_ALPHABET}]{${QR_CODE_LENGTH}}$`);
