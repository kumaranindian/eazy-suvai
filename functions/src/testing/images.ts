// Generated test images for the media tests (M02).
import sharp from "sharp";

/** A solid-colour image of the given size and format. */
export function image(width: number, height: number, format: "jpeg" | "png" | "webp"): Promise<Buffer> {
  return sharp({ create: { width, height, channels: 3, background: "#e07020" } })
    .toFormat(format)
    .toBuffer();
}

/** A JPEG with camera EXIF, a GPS position and the given orientation tag. */
export function exifJpeg(width: number, height: number, orientation: number): Promise<Buffer> {
  return sharp({ create: { width, height, channels: 3, background: "#2080e0" } })
    .jpeg()
    .withExif({
      IFD0: { Make: "TestPhone", Model: "Camera 1" },
      IFD3: { GPSLatitudeRef: "N", GPSLatitude: "13/1 5/1 0/1" },
    })
    .withMetadata({ orientation })
    .toBuffer();
}

/** The start of a PDF file, as uploaded with a `.jpg` name. */
export const pdfBytes = Buffer.from("%PDF-1.7\n1 0 obj\n<< /Type /Catalog >>\nendobj\n", "latin1");
