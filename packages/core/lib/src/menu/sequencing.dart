import 'menu_models.dart';

/// One entry of an ordered list: a document id and its `sequence`.
typedef Sequenced = ({String id, int sequence});

/// New `sequence` values after moving the entry at [from] to [to] in
/// [current] (ordered by display position). [to] is the index in the
/// resulting list (after removing the moved entry).
///
/// Only changed documents are returned. Normally that is just the moved one,
/// placed halfway between its new neighbours. When there is no room left
/// between them, the whole list is renumbered with gaps of
/// [MenuLimits.sequenceGap], so later moves are single writes again.
Map<String, int> sequencesAfterMove(List<Sequenced> current, int from, int to) {
  if (from < 0 || from >= current.length) {
    throw RangeError.index(from, current, 'from');
  }
  final list = [...current];
  final moved = list.removeAt(from);
  final target = to.clamp(0, list.length);
  list.insert(target, moved);
  if (target == from) return const {};

  final prev = target > 0 ? list[target - 1].sequence : null;
  final next = target < list.length - 1 ? list[target + 1].sequence : null;
  int? single;
  if (prev == null && next == null) {
    single = moved.sequence;
  } else if (next == null) {
    single = prev! + MenuLimits.sequenceGap;
  } else if (prev == null) {
    if (next >= 2) single = next ~/ 2;
  } else if (next - prev >= 2) {
    single = prev + (next - prev) ~/ 2;
  }
  if (single != null) return {moved.id: single};
  return renumbered(list);
}

/// `sequence` values that put [ordered] on the 1000-gap grid; only the
/// entries whose value changes.
Map<String, int> renumbered(List<Sequenced> ordered) => {
  for (var i = 0; i < ordered.length; i++)
    if (ordered[i].sequence != (i + 1) * MenuLimits.sequenceGap)
      ordered[i].id: (i + 1) * MenuLimits.sequenceGap,
};

/// Sorts by `sequence`, then by id so ties are stable everywhere.
int compareSequenced(Sequenced a, Sequenced b) {
  final s = a.sequence.compareTo(b.sequence);
  return s != 0 ? s : a.id.compareTo(b.id);
}
