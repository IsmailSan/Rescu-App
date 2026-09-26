import 'package:intl/intl.dart';

/// A store's pickup window. The API sends instants as ISO-8601 UTC strings.
class PickupWindowModel {
  final DateTime start;
  final DateTime end;

  const PickupWindowModel({required this.start, required this.end});

  factory PickupWindowModel.fromJson(Map<String, dynamic> json) {
    // The API sends UTC ISO-8601 instants (e.g. "2026-09-25T23:00:00.000Z").
    // DateTime.parse() preserves the UTC flag, so .toLocal() converts to the
    // device timezone once at parse time. All downstream getters (label,
    // isToday, isOpenNow) then compare correctly against DateTime.now().
    return PickupWindowModel(
      start: DateTime.parse(json['start'] as String? ?? '').toLocal(),
      end: DateTime.parse(json['end'] as String? ?? '').toLocal(),
    );
  }

  /// Human readable label, e.g. "17:30 – 21:00".
  String get label =>
      '${DateFormat('HH:mm').format(start)} – ${DateFormat('HH:mm').format(end)}';

  /// Whether pickup starts today.
  bool get isToday => start.day == DateTime.now().day;

  /// Whether the store is currently accepting pickups.
  bool get isOpenNow {
    final now = DateTime.now();
    return now.isAfter(start) && now.isBefore(end);
  }

  Duration get untilStart => start.difference(DateTime.now());
}
