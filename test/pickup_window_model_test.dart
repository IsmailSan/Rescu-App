import 'package:flutter_test/flutter_test.dart';
import 'package:rescu/model/pickup_window_model.dart';

/// Tests for RES-106: Wrong pickup times; "Pickup today" filter misses deals.
///
/// Root cause: [PickupWindowModel.fromJson] called [DateTime.parse] on UTC
/// ISO-8601 strings without converting to local time. All downstream getters
/// ([label], [isToday], [isOpenNow]) then compared UTC datetimes against
/// [DateTime.now()] (local), producing wrong display times and a broken
/// "Pickup today" filter.
///
/// Fix: add `.toLocal()` at the parse site so every downstream consumer
/// receives a correctly-timezone-converted [DateTime].
///
/// All tests are **timezone-agnostic**: UTC payloads are always derived from
/// [DateTime.now()] so they produce the correct local result regardless of
/// which timezone the test machine or CI server runs in.
void main() {
  group('PickupWindowModel.fromJson — RES-106 timezone fix', () {
    // ── Helper ──────────────────────────────────────────────────────────────

    /// Builds a JSON payload whose UTC instants correspond to [localStart] and
    /// [localEnd] on the device's local clock. This keeps tests agnostic of
    /// the machine timezone.
    Map<String, String> jsonFrom(DateTime localStart, DateTime localEnd) => {
          'start': localStart.toUtc().toIso8601String(),
          'end': localEnd.toUtc().toIso8601String(),
        };

    // ── Conversion correctness ───────────────────────────────────────────────

    test('parsed datetimes are local, not UTC', () {
      final now = DateTime.now();
      final localStart = DateTime(now.year, now.month, now.day, 9, 0);
      final localEnd = DateTime(now.year, now.month, now.day, 11, 30);

      final model = PickupWindowModel.fromJson(jsonFrom(localStart, localEnd));

      // Core assertion that would have caught RES-106:
      // Before fix -> isUtc == true  (bug: raw UTC preserved)
      // After fix  -> isUtc == false (local conversion applied)
      expect(model.start.isUtc, isFalse,
          reason: 'start must be local after fromJson');
      expect(model.end.isUtc, isFalse,
          reason: 'end must be local after fromJson');
    });

    test('start and end wall-clock values match the original local times', () {
      final now = DateTime.now();
      final localStart = DateTime(now.year, now.month, now.day, 9, 0);
      final localEnd = DateTime(now.year, now.month, now.day, 11, 30);

      final model = PickupWindowModel.fromJson(jsonFrom(localStart, localEnd));

      expect(model.start.hour, 9,
          reason: 'start hour must be local 09:00, not the UTC equivalent');
      expect(model.start.minute, 0);
      expect(model.end.hour, 11,
          reason: 'end hour must be local 11:30, not the UTC equivalent');
      expect(model.end.minute, 30);
    });

    // ── label ────────────────────────────────────────────────────────────────

    test('label shows local wall-clock time', () {
      final now = DateTime.now();
      final localStart = DateTime(now.year, now.month, now.day, 9, 0);
      final localEnd = DateTime(now.year, now.month, now.day, 11, 30);

      final model = PickupWindowModel.fromJson(jsonFrom(localStart, localEnd));

      // Before fix: label showed UTC hour (e.g. "02:00 – 04:30" for UTC+7).
      // After fix:  label shows local hour.
      expect(model.label, '09:00 – 11:30');
    });

    test('label for an overnight window shows correct local times', () {
      final now = DateTime.now();
      // Overnight: starts 22:00, ends 01:00 next day (local).
      final localStart = DateTime(now.year, now.month, now.day, 22, 0);
      final localEnd = DateTime(now.year, now.month, now.day + 1, 1, 0);

      final model = PickupWindowModel.fromJson(jsonFrom(localStart, localEnd));

      expect(model.label, '22:00 – 01:00');
    });

    // ── isToday ──────────────────────────────────────────────────────────────

    test('isToday is true when pickup starts today (local time)', () {
      final now = DateTime.now();
      final localStart = DateTime(now.year, now.month, now.day, 9, 0);
      final localEnd = DateTime(now.year, now.month, now.day, 11, 0);

      final model = PickupWindowModel.fromJson(jsonFrom(localStart, localEnd));

      // Before fix: start.day was the UTC day, which could differ from
      // DateTime.now().day (local day) when UTC had already rolled over
      // midnight. This caused "Pickup today" to hide valid deals.
      expect(model.isToday, isTrue,
          reason: 'a window that starts today locally must be flagged as today');
    });

    test('isToday is false when pickup starts tomorrow (local time)', () {
      final now = DateTime.now();
      final localStart = DateTime(now.year, now.month, now.day + 1, 9, 0);
      final localEnd = DateTime(now.year, now.month, now.day + 1, 11, 0);

      final model = PickupWindowModel.fromJson(jsonFrom(localStart, localEnd));

      expect(model.isToday, isFalse,
          reason: "a window starting tomorrow must not be flagged as today");
    });

    // ── isOpenNow ────────────────────────────────────────────────────────────

    test('isOpenNow is true when current time is within the window', () {
      // Window: 1 hour ago -> 1 hour from now (local).
      final now = DateTime.now();
      final localStart = now.subtract(const Duration(hours: 1));
      final localEnd = now.add(const Duration(hours: 1));

      final model = PickupWindowModel.fromJson(jsonFrom(localStart, localEnd));

      // Before fix: comparing local now() with UTC start/end gave wrong result.
      expect(model.isOpenNow, isTrue,
          reason: 'store must appear open when current time is inside window');
    });

    test('isOpenNow is false when the window has already ended', () {
      final now = DateTime.now();
      final localStart = now.subtract(const Duration(hours: 3));
      final localEnd = now.subtract(const Duration(hours: 1));

      final model = PickupWindowModel.fromJson(jsonFrom(localStart, localEnd));

      expect(model.isOpenNow, isFalse,
          reason: 'store must appear closed when window has passed');
    });

    test('isOpenNow is false when the window has not started yet', () {
      final now = DateTime.now();
      final localStart = now.add(const Duration(hours: 1));
      final localEnd = now.add(const Duration(hours: 3));

      final model = PickupWindowModel.fromJson(jsonFrom(localStart, localEnd));

      expect(model.isOpenNow, isFalse,
          reason: 'store must appear closed when window has not started');
    });

    // ── Regression guard ─────────────────────────────────────────────────────

    test('regression: label must NOT display raw UTC hours', () {
      // Simulate Bangkok timezone (UTC+7).
      // Bakery opens 06:00-09:30 local = 23:00-02:30 UTC.
      // Before fix: label was "23:00 - 02:30". After fix: "06:00 - 09:30".
      //
      // Note: the label assertion is only verified on UTC+7 machines.
      // The isUtc assertion holds on any timezone.
      final model = PickupWindowModel.fromJson({
        'start': '2026-09-25T23:00:00.000Z', // 06:00 Bangkok (UTC+7)
        'end': '2026-09-26T02:30:00.000Z',   // 09:30 Bangkok (UTC+7)
      });

      // Must be local on any machine.
      expect(model.start.isUtc, isFalse);
      expect(model.end.isUtc, isFalse);

      // On UTC+7 machines, also verify the exact label.
      final offsetHours = DateTime.now().timeZoneOffset.inHours;
      if (offsetHours == 7) {
        expect(model.label, '06:00 – 09:30',
            reason: 'Bangkok user must see local bakery hours, not UTC');
        expect(model.label, isNot(contains('23:00')),
            reason: 'label must not expose raw UTC hour to the user');
      }
    });
  });
}
