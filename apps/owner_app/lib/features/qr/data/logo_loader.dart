import 'package:core/core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Loads the bytes of the restaurant's logo (the 640 px WebP rendition) for
/// the QR centre and the PDFs. On web the bucket needs the CORS policy in
/// `storage.cors.json` (M02).
abstract class QrLogoLoader {
  Future<Uint8List?> load(ImageObject? logo);
}

class FirebaseQrLogoLoader implements QrLogoLoader {
  FirebaseQrLogoLoader(this._storage);

  final FirebaseStorage _storage;
  final _cache = <String, Future<Uint8List?>>{};

  @override
  Future<Uint8List?> load(ImageObject? logo) {
    final path = logo != null && logo.isReady ? logo.renditions!.w640 : null;
    if (path == null) return Future.value();
    return _cache.putIfAbsent(path, () async {
      try {
        return await _storage.ref(path).getData(4 * 1024 * 1024);
      } on Object {
        _cache.remove(path);
        rethrow;
      }
    });
  }
}

final qrLogoLoaderProvider = Provider<QrLogoLoader>(
  (ref) => FirebaseQrLogoLoader(FirebaseStorage.instance),
);

/// The bundled brand fonts for the PDFs (Poppins, SIL OFL).
class QrFonts {
  const QrFonts(this.regular, this.bold);

  final ByteData regular;
  final ByteData bold;
}

final qrFontsProvider = FutureProvider<QrFonts>((ref) async {
  final regular = await rootBundle.load('assets/fonts/Poppins-Regular.ttf');
  final bold = await rootBundle.load('assets/fonts/Poppins-SemiBold.ttf');
  return QrFonts(regular, bold);
});
