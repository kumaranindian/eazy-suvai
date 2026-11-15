import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Print-ready PDFs with the QR code (FR-050): an A4 poster and an A6
/// table card. Both show the restaurant's name and logo, the code, "Scan to
/// view our menu" and the short `/q/` URL as text, in the brand font
/// (Poppins, bundled) and the restaurant's theme colour.
enum QrTemplate {
  poster(PdfPageFormat.a4),
  tableCard(PdfPageFormat.a6);

  const QrTemplate(this.format);

  final PdfPageFormat format;
}

/// The words printed on the templates (from the app's localizations).
class QrPdfText {
  const QrPdfText({required this.scanToView, required this.orVisit});

  /// "Scan to view our menu".
  final String scanToView;

  /// "or visit" before the short URL.
  final String orVisit;
}

/// Everything a template needs.
class QrPdfInput {
  const QrPdfInput({
    required this.restaurantName,
    required this.qrPng,
    required this.shortUrl,
    required this.text,
    required this.regularFont,
    required this.boldFont,
    this.logo,
    this.primary = const PdfColor.fromInt(0xFFA8550A),
    this.onPrimary = PdfColors.white,
  });

  final String restaurantName;
  final Uint8List qrPng;
  final String shortUrl;
  final QrPdfText text;
  final ByteData regularFont;
  final ByteData boldFont;

  /// The logo in any format `image` reads; converted to PNG for the PDF.
  final Uint8List? logo;

  /// The theme's primary colour and the readable colour on it (FR-060).
  final PdfColor primary;
  final PdfColor onPrimary;
}

/// `#RRGGBB` → [PdfColor], or [fallback].
PdfColor pdfColorFromHex(String? hex, PdfColor fallback) {
  final m = RegExp(r'^#?([0-9A-Fa-f]{6})$').firstMatch(hex ?? '');
  if (m == null) return fallback;
  return PdfColor.fromInt(0xFF000000 | int.parse(m.group(1)!, radix: 16));
}

Uint8List? _logoPng(Uint8List? bytes) {
  if (bytes == null) return null;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final small = decoded.width > 600
      ? img.copyResize(decoded, width: 600)
      : decoded;
  return Uint8List.fromList(img.encodePng(small));
}

/// Builds the PDF for [template].
Future<Uint8List> buildQrPdf(
  QrTemplate template,
  QrPdfInput input, {
  bool compress = true,
}) async {
  final regular = pw.Font.ttf(input.regularFont);
  final bold = pw.Font.ttf(input.boldFont);
  final doc = pw.Document(
    compress: compress,
    title: '${input.restaurantName} – ${input.text.scanToView}',
    author: input.restaurantName,
    creator: 'EazySuvai',
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );
  final qr = pw.MemoryImage(input.qrPng);
  final logoPng = _logoPng(input.logo);
  final logo = logoPng == null ? null : pw.MemoryImage(logoPng);
  final poster = template == QrTemplate.poster;
  // Points: the A4 page is 595 × 842, A6 is 298 × 420.
  final margin = poster ? 40.0 : 18.0;
  final qrSide = poster ? 340.0 : 180.0;
  final nameSize = poster ? 34.0 : 17.0;
  final scanSize = poster ? 28.0 : 14.0;
  final urlSize = poster ? 16.0 : 9.0;
  final logoSide = poster ? 96.0 : 44.0;

  doc.addPage(
    pw.Page(
      pageFormat: template.format,
      margin: pw.EdgeInsets.zero,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Header band in the theme colour: logo and name.
          pw.Container(
            color: input.primary,
            padding: pw.EdgeInsets.symmetric(
              horizontal: margin,
              vertical: poster ? 28 : 12,
            ),
            child: pw.Column(
              children: [
                if (logo != null)
                  pw.Container(
                    width: logoSide,
                    height: logoSide,
                    margin: pw.EdgeInsets.only(bottom: poster ? 14 : 6),
                    padding: pw.EdgeInsets.all(poster ? 8 : 4),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(poster ? 18 : 8),
                    ),
                    child: pw.Image(logo, fit: pw.BoxFit.contain),
                  ),
                pw.Text(
                  input.restaurantName,
                  textAlign: pw.TextAlign.center,
                  maxLines: 2,
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: nameSize,
                    color: input.onPrimary,
                  ),
                ),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Padding(
              padding: pw.EdgeInsets.symmetric(horizontal: margin),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    input.text.scanToView,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: scanSize,
                      color: PdfColors.grey900,
                    ),
                  ),
                  pw.SizedBox(height: poster ? 24 : 10),
                  pw.Container(
                    width: qrSide,
                    height: qrSide,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        color: input.primary,
                        width: poster ? 3 : 1.5,
                      ),
                      borderRadius: pw.BorderRadius.circular(poster ? 16 : 8),
                    ),
                    padding: pw.EdgeInsets.all(poster ? 10 : 5),
                    child: pw.Image(qr),
                  ),
                  pw.SizedBox(height: poster ? 24 : 10),
                  pw.Text(
                    input.text.orVisit,
                    style: pw.TextStyle(
                      fontSize: urlSize * 0.85,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    input.shortUrl,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: urlSize,
                      color: PdfColors.grey900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          pw.Container(height: poster ? 14 : 6, color: input.primary),
        ],
      ),
    ),
  );
  return doc.save();
}
