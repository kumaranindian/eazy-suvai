import 'dart:typed_data';

/// The upload formats accepted by FR-102.
enum ImageFormat {
  jpeg('image/jpeg', 'jpg'),
  png('image/png', 'png'),
  webp('image/webp', 'webp');

  const ImageFormat(this.contentType, this.extension);

  final String contentType;

  /// File extension used in the Storage path (`original.<extension>`).
  final String extension;
}

/// Detects JPEG, PNG or WebP from the first bytes (FRD §7.2: by content,
/// not by name). Returns null for anything else, such as a renamed PDF.
///
/// Mirrors `sniffImageFormat` in `functions/src/media/image-types.ts`.
ImageFormat? sniffImageFormat(Uint8List b) {
  if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) {
    return ImageFormat.jpeg;
  }
  const png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  if (b.length >= 8 && _startsWith(b, 0, png)) return ImageFormat.png;
  if (b.length >= 12 &&
      _startsWith(b, 0, 'RIFF'.codeUnits) &&
      _startsWith(b, 8, 'WEBP'.codeUnits)) {
    return ImageFormat.webp;
  }
  return null;
}

/// Pixel size stored in the file header, read without decoding. Used to
/// refuse decompression bombs before decoding. Null if the header can't be
/// read. JPEG sizes ignore the EXIF orientation.
({int width, int height})? readImageHeaderSize(Uint8List b, ImageFormat f) {
  try {
    return switch (f) {
      ImageFormat.png => (width: _be32(b, 16), height: _be32(b, 20)),
      ImageFormat.jpeg => _jpegSize(b),
      ImageFormat.webp => _webpSize(b),
    };
  } on RangeError {
    return null;
  }
}

({int width, int height})? _jpegSize(Uint8List b) {
  var i = 2;
  while (i + 9 < b.length) {
    if (b[i] != 0xFF) return null;
    final marker = b[i + 1];
    if (marker == 0xFF) {
      i++; // fill byte
      continue;
    }
    // Markers without a length: TEM, RST0–7, SOI, EOI.
    if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD9)) {
      i += 2;
      continue;
    }
    // SOF0–SOF15, except DHT (C4), JPG (C8) and DAC (CC).
    if (marker >= 0xC0 &&
        marker <= 0xCF &&
        marker != 0xC4 &&
        marker != 0xC8 &&
        marker != 0xCC) {
      return (width: _be16(b, i + 7), height: _be16(b, i + 5));
    }
    i += 2 + _be16(b, i + 2);
  }
  return null;
}

({int width, int height})? _webpSize(Uint8List b) {
  final chunk = String.fromCharCodes(b.sublist(12, 16));
  switch (chunk) {
    case 'VP8 ':
      return (width: _le16(b, 26) & 0x3FFF, height: _le16(b, 28) & 0x3FFF);
    case 'VP8L':
      final bits = b[21] | (b[22] << 8) | (b[23] << 16) | (b[24] << 24);
      return (width: (bits & 0x3FFF) + 1, height: ((bits >> 14) & 0x3FFF) + 1);
    case 'VP8X':
      return (width: _le24(b, 24) + 1, height: _le24(b, 27) + 1);
  }
  return null;
}

bool _startsWith(Uint8List b, int offset, List<int> prefix) {
  for (var i = 0; i < prefix.length; i++) {
    if (b[offset + i] != prefix[i]) return false;
  }
  return true;
}

int _be16(Uint8List b, int i) => (b[i] << 8) | b[i + 1];
int _be32(Uint8List b, int i) =>
    (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
int _le16(Uint8List b, int i) => b[i] | (b[i + 1] << 8);
int _le24(Uint8List b, int i) => b[i] | (b[i + 1] << 8) | (b[i + 2] << 16);
