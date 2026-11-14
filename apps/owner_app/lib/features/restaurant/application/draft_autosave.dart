import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/restaurant_repository.dart';

/// What the "Saved" indicator shows.
enum SaveStatus {
  /// Nothing changed yet.
  idle,

  /// Changes waiting for the 1 s pause.
  pending,
  saving,
  saved,

  /// The last save failed; the changes are kept and retried on [DraftAutosave.flush].
  failed,

  /// Some fields are not valid; they are not saved until fixed.
  invalid,
}

@immutable
class DraftSaveState {
  const DraftSaveState(this.status, {this.error});

  final SaveStatus status;

  /// The error of the last failed save.
  final Object? error;
}

/// Autosave for draft profile edits (M03, FR-012).
///
/// Forms [stage] each valid field; after [debounce] without further edits
/// the staged fields are written in one update (with `draftUpdatedAt`).
/// Fields reported with [setInvalid] are not saved and the indicator says
/// why. Leaving the page saves anything still staged.
class DraftAutosave extends Notifier<DraftSaveState> {
  static const debounce = Duration(seconds: 1);

  final _pending = <String, Object?>{};
  final _invalid = <String>{};
  Timer? _timer;
  Future<void>? _inFlight;
  late RestaurantRepository _repo;
  String? _rid;

  @override
  DraftSaveState build() {
    _repo = ref.watch(restaurantRepositoryProvider);
    _rid = ref.watch(currentRestaurantIdProvider);
    ref.onDispose(() {
      _timer?.cancel();
      if (_pending.isNotEmpty) unawaited(_save());
    });
    return const DraftSaveState(SaveStatus.idle);
  }

  /// Whether anything is waiting to be saved.
  bool get hasPending => _pending.isNotEmpty;

  /// Stages [field] = [value] and restarts the 1 s timer.
  void stage(String field, Object? value) {
    _pending[field] = value;
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(_save()));
    _set(_invalid.isEmpty ? SaveStatus.pending : SaveStatus.invalid);
  }

  /// Marks a form field (any id) as invalid or valid again.
  void setInvalid(String fieldId, {required bool invalid}) {
    final changed = invalid ? _invalid.add(fieldId) : _invalid.remove(fieldId);
    if (!changed) return;
    if (_invalid.isNotEmpty) {
      _set(SaveStatus.invalid);
    } else if (state.status == SaveStatus.invalid) {
      _set(_pending.isNotEmpty ? SaveStatus.pending : SaveStatus.saved);
    }
  }

  /// Saves now (the "Save now" button, "Next" in the wizard, leaving a
  /// page). Completes when the write has finished or failed.
  Future<void> flush() async {
    _timer?.cancel();
    await _save();
  }

  Future<void> _save() async {
    while (_inFlight != null) {
      await _inFlight;
    }
    final rid = _rid;
    if (_pending.isEmpty || rid == null) return;
    final batch = Map<String, Object?>.of(_pending);
    _pending.clear();
    _set(SaveStatus.saving);
    final done = Completer<void>();
    _inFlight = done.future;
    try {
      await _repo.updateDraft(rid, batch);
      _set(
        _invalid.isNotEmpty
            ? SaveStatus.invalid
            : (_pending.isEmpty ? SaveStatus.saved : SaveStatus.pending),
      );
    } catch (e) {
      // Keep the changes for a retry, unless newer values were staged.
      for (final entry in batch.entries) {
        _pending.putIfAbsent(entry.key, () => entry.value);
      }
      _set(SaveStatus.failed, error: e);
    } finally {
      _inFlight = null;
      done.complete();
    }
  }

  void _set(SaveStatus status, {Object? error}) {
    if (!ref.mounted) return;
    state = DraftSaveState(status, error: error);
  }
}

final draftAutosaveProvider =
    NotifierProvider.autoDispose<DraftAutosave, DraftSaveState>(
      DraftAutosave.new,
    );
