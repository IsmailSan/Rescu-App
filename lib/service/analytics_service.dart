import 'dart:async';
import 'package:get/get.dart';

import '../util/log_service.dart';
import 'fake_api_service.dart';

class AnalyticsEvent {
  final String name;
  final Map<String, dynamic> properties;
  final DateTime at;

  AnalyticsEvent(this.name, this.properties) : at = DateTime.now();

  Map<String, dynamic> toJson() => {
        'name': name,
        'properties': properties,
        'at': at.toIso8601String(),
      };
}

/// In-memory analytics sink and batching dispatcher. Events are visible
/// on the debug screen (overflow menu on Home -> "Analytics debug") and
/// delivered in batches to [FakeApiService.sendAnalyticsBatch].
class AnalyticsService extends GetxService {
  final FakeApiService? fakeApi;
  final events = <AnalyticsEvent>[].obs;
  final Set<int> _impressedDealIds = <int>{};

  final List<Map<String, dynamic>> _pendingBatch = [];
  Timer? _batchTimer;

  AnalyticsService({this.fakeApi});

  int get pendingBatchCount => _pendingBatch.length;
  List<Map<String, dynamic>> get pendingBatch => List.unmodifiable(_pendingBatch);

  /// Checks if a deal has already received an impression in this app session.
  bool hasImpressed(int dealId) => _impressedDealIds.contains(dealId);

  /// Records a deal impression event if it hasn't already been impressed this session.
  void recordDealImpression({
    required int dealId,
    required String source,
    required int position,
  }) {
    if (_impressedDealIds.contains(dealId)) return;
    _impressedDealIds.add(dealId);

    logEvent('deal_impression', {
      'deal_id': dealId,
      'source': source,
      'position': position,
    });
  }

  void logEvent(String name, [Map<String, dynamic> properties = const {}]) {
    final event = AnalyticsEvent(name, properties);
    events.add(event);
    LogService.log('analytics: $name $properties');
    _queueEventForBatch(event);
  }

  void _queueEventForBatch(AnalyticsEvent event) {
    _pendingBatch.add(event.toJson());

    // Deliver when either 10 events have accumulated or 15 seconds have passed
    // since the first unsent event — whichever comes first.
    if (_pendingBatch.length >= 10) {
      flushBatch();
    } else if (_pendingBatch.length == 1) {
      _batchTimer?.cancel();
      _batchTimer = Timer(const Duration(seconds: 15), () {
        flushBatch();
      });
    }
  }

  /// Flushes any pending events immediately to [FakeApiService.sendAnalyticsBatch].
  Future<void> flushBatch() async {
    _batchTimer?.cancel();
    _batchTimer = null;
    if (_pendingBatch.isEmpty) return;

    final batch = List<Map<String, dynamic>>.from(_pendingBatch);
    _pendingBatch.clear();

    final api = fakeApi ?? (Get.isRegistered<FakeApiService>() ? Get.find<FakeApiService>() : null);
    if (api != null) {
      try {
        await api.sendAnalyticsBatch(batch);
      } catch (e) {
        LogService.error('analytics: failed to send batch', e);
      }
    }
  }

  void resetSession() {
    _impressedDealIds.clear();
    _pendingBatch.clear();
    _batchTimer?.cancel();
    _batchTimer = null;
  }

  @override
  void onClose() {
    _batchTimer?.cancel();
    super.onClose();
  }
}
