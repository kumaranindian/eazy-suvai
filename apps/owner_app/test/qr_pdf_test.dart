import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:owner_app/features/qr/application/qr_image.dart';
import 'package:owner_app/features/qr/application/qr_pdf.dart';
import 'package:owner_app/features/qr/domain/qr_link.dart';
import 'package:pdf/pdf.dart';

import 'qr_image_test.dart' show sampleLogo;

ByteData font(String name) =>
    ByteData.sublistView(File('assets/fonts/$name').readAsBytesSync());

void main() {
  const url = 'https://menu.eazysuvai.com/q/AB3K7MNP';
  final qr = buildQrArtifact(QrJob(url, sampleLogo()));

  QrPdfInput input({Uint8List? logo}) => QrPdfInput(
    restaurantName: 'Spice Garden',
    qrPng: qr.png,
    shortUrl: shortUrlText(url),
    text: const QrPdfText(
      scanToView: 'Scan to view our menu',
      orVisit: 'or visit',
    ),
    regularFont: font('Poppins-Regular.ttf'),
    boldFont: font('Poppins-SemiBold.ttf'),
    logo: logo,
    primary: pdfColorFromHex('#A8550A', PdfColors.black),
  );

  List<double> mediaBox(String pdf) {
    final m = RegExp(r'/MediaBox\s*\[\s*([\d.\s]+)\]').firstMatch(pdf)!;
    return m.group(1)!.trim().split(RegExp(r'\s+')).map(double.parse).toList();
  }

  for (final (template, w, h) in [
    (QrTemplate.poster, 595.28, 841.89),
    (QrTemplate.tableCard, 297.64, 419.53),
  ]) {
    test('${template.name}: page size, QR image, brand font, logo', () async {
      final bytes = await buildQrPdf(
        template,
        input(logo: sampleLogo()),
        compress: false,
      );
      final pdf = latin1.decode(bytes);
      expect(pdf.startsWith('%PDF-'), isTrue);
      expect(RegExp('/Type\\s*/Page\\b').allMatches(pdf), hasLength(1));
      final box = mediaBox(pdf);
      expect(box[2], closeTo(w, 0.1));
      expect(box[3], closeTo(h, 0.1));
      // The full-size QR PNG is embedded (≥ 1024 px), plus the logo.
      expect(pdf, contains('/Width ${qr.render.size}'));
      expect(
        pdf,
        contains('/Width 512'),
      ); // the logo; each image also has a soft mask
      // Poppins is embedded (subset), not a standard PDF font.
      expect(pdf, contains('Poppins'));
      expect(pdf, isNot(contains('/Helvetica')));
    });
  }

  test('without a logo, only the QR image is embedded', () async {
    final pdf = latin1.decode(
      await buildQrPdf(QrTemplate.tableCard, input(), compress: false),
    );
    expect(pdf, contains('/Width ${qr.render.size}'));
    expect(pdf, isNot(contains('/Width 512')));
  });

  test('the embedded QR is the checked one: it decodes to the /q/ URL', () {
    expect(decodeQrImage(qr.png), url);
  });

  test('theme colours from hex, with a fallback', () {
    expect(pdfColorFromHex('#A8550A', PdfColors.black).toHex(), '#a8550aff');
    expect(pdfColorFromHex('nope', PdfColors.white), PdfColors.white);
  });
}
