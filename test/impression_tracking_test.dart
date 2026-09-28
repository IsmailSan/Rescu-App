import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rescu/feature/shared_widget/deal_impression_tracker.dart';
import 'package:rescu/service/analytics_service.dart';
import 'package:rescu/service/fake_api_service.dart';
import 'package:visibility_detector/visibility_detector.dart';

class MockFakeApiService extends FakeApiService {
  final List<List<Map<String, dynamic>>> deliveredBatches = [];

  @override
  Future<void> sendAnalyticsBatch(List<Map<String, dynamic>> events) async {
    deliveredBatches.add(List.from(events));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  VisibilityDetectorController.instance.updateInterval = Duration.zero;

  group('F-2 · Impression tracking — AnalyticsService', () {
    late MockFakeApiService mockApi;
    late AnalyticsService analytics;

    setUp(() {
      Get.reset();
      mockApi = MockFakeApiService();
      analytics = AnalyticsService(fakeApi: mockApi);
      Get.put<AnalyticsService>(analytics);
    });

    tearDown(() {
      analytics.onClose();
      Get.reset();
    });

    test('deduplicates deal impressions to at most once per session', () {
      expect(analytics.hasImpressed(101), isFalse);

      analytics.recordDealImpression(dealId: 101, source: 'home_feed', position: 0);
      expect(analytics.hasImpressed(101), isTrue);
      expect(analytics.events.length, 1);
      expect(analytics.events.first.name, 'deal_impression');
      expect(analytics.events.first.properties['deal_id'], 101);
      expect(analytics.events.first.properties['source'], 'home_feed');
      expect(analytics.events.first.properties['position'], 0);

      // Attempt second impression from another screen (e.g. search or flash rail)
      analytics.recordDealImpression(dealId: 101, source: 'search', position: 3);
      expect(analytics.events.length, 1, reason: 'Duplicate impression must be rejected');
    });

    test('batches and delivers automatically when 10 events accumulate', () async {
      expect(mockApi.deliveredBatches, isEmpty);

      // Log 9 events
      for (int i = 1; i <= 9; i++) {
        analytics.recordDealImpression(dealId: i, source: 'home_feed', position: i);
      }
      expect(mockApi.deliveredBatches, isEmpty);
      expect(analytics.pendingBatchCount, 9);

      // Log the 10th event -> triggers batch delivery
      analytics.recordDealImpression(dealId: 10, source: 'home_feed', position: 10);

      await Future.delayed(Duration.zero);
      expect(mockApi.deliveredBatches.length, 1);
      expect(mockApi.deliveredBatches.first.length, 10);
      expect(analytics.pendingBatchCount, 0);
    });

    test('batches and delivers after 15 seconds from first unsent event', () async {
      expect(mockApi.deliveredBatches, isEmpty);

      // Log 3 events
      analytics.recordDealImpression(dealId: 1, source: 'flash_rail', position: 0);
      analytics.recordDealImpression(dealId: 2, source: 'flash_rail', position: 1);
      analytics.recordDealImpression(dealId: 3, source: 'flash_rail', position: 2);

      expect(mockApi.deliveredBatches, isEmpty);
      expect(analytics.pendingBatchCount, 3);

      // Calling flushBatch delivers whatever is pending
      await analytics.flushBatch();
      expect(mockApi.deliveredBatches.length, 1);
      expect(mockApi.deliveredBatches.first.length, 3);
      expect(analytics.pendingBatchCount, 0);
    });
  });

  group('F-2 · Impression tracking — DealImpressionTracker widget', () {
    late MockFakeApiService mockApi;
    late AnalyticsService analytics;

    setUp(() {
      Get.reset();
      mockApi = MockFakeApiService();
      analytics = AnalyticsService(fakeApi: mockApi);
      Get.put<AnalyticsService>(analytics);
    });

    tearDown(() {
      analytics.onClose();
      Get.reset();
    });

    testWidgets('fires deal_impression when visible for at least 1 second', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DealImpressionTracker(
              dealId: 50,
              source: 'home_feed',
              position: 2,
              child: const SizedBox(width: 200, height: 200, child: Text('Deal 50')),
            ),
          ),
        ),
      );

      // Initially rendered and visibility detected
      await tester.pump(const Duration(milliseconds: 100));
      expect(analytics.hasImpressed(50), isFalse);

      // Fast-forward 1 second to trigger impression
      await tester.pump(const Duration(seconds: 1));

      expect(analytics.hasImpressed(50), isTrue);
      expect(analytics.events.any((e) => e.properties['deal_id'] == 50), isTrue);

      // Fast-forward 15 seconds to flush batch timer
      await tester.pump(const Duration(seconds: 15));
    });

    testWidgets('cancels timer if widget is disposed or scrolled away before 1 second', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DealImpressionTracker(
              dealId: 60,
              source: 'home_feed',
              position: 0,
              child: const SizedBox(width: 200, height: 200, child: Text('Deal 60')),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      // Remove widget before 1 second has elapsed (simulating scrolling off screen)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SizedBox.shrink()),
        ),
      );

      // Fast forward past the 1 second mark
      await tester.pump(const Duration(seconds: 2));

      expect(analytics.hasImpressed(60), isFalse, reason: 'Impression must not fire if scrolled away before 1s');
    });
  });
}
