import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `exportMenu` result (M12, FR-105).
class MenuExportFiles {
  const MenuExportFiles({
    required this.fileBase,
    required this.json,
    required this.csv,
  });

  final String fileBase;
  final String json;
  final String csv;
}

/// The account callables (M12): export and deletion.
abstract class AccountRepository {
  Future<MenuExportFiles> exportMenu(String restaurantId);

  /// `requestAccountDeletion`: returns when the data will be deleted.
  Future<DateTime?> requestDeletion(String restaurantId, String confirmName);
}

class FunctionsAccountRepository implements AccountRepository {
  const FunctionsAccountRepository();

  @override
  Future<MenuExportFiles> exportMenu(String restaurantId) async {
    final r = await regionalFunctions
        .httpsCallable('exportMenu')
        .call<Map<String, dynamic>>({'restaurantId': restaurantId});
    final d = Map<String, dynamic>.from(r.data);
    return MenuExportFiles(
      fileBase: d['fileBase'] as String,
      json: d['json'] as String,
      csv: d['csv'] as String,
    );
  }

  @override
  Future<DateTime?> requestDeletion(
    String restaurantId,
    String confirmName,
  ) async {
    final r = await regionalFunctions
        .httpsCallable('requestAccountDeletion')
        .call<Map<String, dynamic>>({
          'restaurantId': restaurantId,
          'confirmName': confirmName,
        });
    return DateTime.tryParse('${r.data['purgeAfter']}');
  }
}

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => const FunctionsAccountRepository(),
);
