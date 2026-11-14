import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Turns a Storage path into something an `Image` can show.
abstract class StorageImageResolver {
  Future<ImageProvider> resolve(String path);
}

/// Resolves paths with `getDownloadURL` (the owner's read is allowed by
/// `storage.rules`). URLs are cached for the app's lifetime; renditions
/// never change because each upload gets a new folder.
///
/// On web the bucket needs a CORS policy for the app's origin
/// (`storage.cors.json`, see README).
class FirebaseStorageImageResolver implements StorageImageResolver {
  FirebaseStorageImageResolver(this._storage);

  final FirebaseStorage _storage;
  final _urls = <String, Future<String>>{};

  @override
  Future<ImageProvider> resolve(String path) async {
    final url = _urls.putIfAbsent(
      path,
      () => _storage.ref(path).getDownloadURL(),
    );
    try {
      return NetworkImage(await url);
    } on Object {
      _urls.remove(path);
      rethrow;
    }
  }
}

final storageImageResolverProvider = Provider<StorageImageResolver>(
  (ref) => FirebaseStorageImageResolver(FirebaseStorage.instance),
);
