import type { ImageFormat } from "./policy";

/**
 * Detects JPEG, PNG or WebP from the file's first bytes (FRD §7.2: type is
 * checked by content, not by extension). Returns null for anything else,
 * for example a PDF renamed to `.jpg`.
 *
 * Mirrors `sniffImageFormat` in `packages/core/lib/src/media/image_sniffer.dart`.
 */
export function sniffImageFormat(bytes: Uint8Array): ImageFormat | null {
  const b = bytes;
  if (b.length >= 3 && b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff) return "jpeg";
  if (
    b.length >= 8 &&
    b[0] === 0x89 && b[1] === 0x50 && b[2] === 0x4e && b[3] === 0x47 &&
    b[4] === 0x0d && b[5] === 0x0a && b[6] === 0x1a && b[7] === 0x0a
  ) {
    return "png";
  }
  if (
    b.length >= 12 &&
    ascii(b, 0, 4) === "RIFF" &&
    ascii(b, 8, 4) === "WEBP"
  ) {
    return "webp";
  }
  return null;
}

function ascii(b: Uint8Array, start: number, length: number): string {
  return String.fromCharCode(...b.subarray(start, start + length));
}
