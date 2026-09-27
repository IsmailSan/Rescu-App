import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rescu/feature/shared_widget/countdown_text.dart';
import 'package:rescu/model/cart_item_model.dart';
import 'package:rescu/model/deal_model.dart';
import 'package:rescu/model/pickup_window_model.dart';
import 'package:rescu/service/cart_service.dart';
import 'package:rescu/service/countdown_service.dart';

DealModel createDeal({
  required int id,
  required String name,
  DateTime? flashSaleEndsAt,
}) {
  return DealModel(
    id: id,
    name: name,
    description: 'Description',
    imageUrl: '',
    originalPrice: 100,
    price: 50,
    currencyCode: 'THB',
    quantityLeft: 5,
    storeId: 1,
    storeName: 'Bakery',
    storeAddress: '123 Bakery St',
    lat: 13.75,
    lng: 100.5,
    rating: 4.5,
    tags: ['bakery'],
    pickupWindow: PickupWindowModel(
      start: DateTime.now(),
      end: DateTime.now().add(const Duration(hours: 2)),
    ),
    flashSaleEndsAt: flashSaleEndsAt,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('F-1 · Live flash-sale countdowns', () {
    test('CountdownService.format formats mm:ss below 1 hour and hh:mm:ss above 1 hour', () {
      expect(CountdownService.format(const Duration(seconds: 45)), '00:45');
      expect(CountdownService.format(const Duration(minutes: 5, seconds: 8)), '05:08');
      expect(CountdownService.format(const Duration(minutes: 59, seconds: 59)), '59:59');
      expect(CountdownService.format(const Duration(hours: 1, minutes: 5, seconds: 3)), '01:05:03');
      expect(CountdownService.format(const Duration(hours: 2, minutes: 0, seconds: 0)), '02:00:00');
      expect(CountdownService.format(Duration.zero), '00:00');
      expect(CountdownService.format(const Duration(seconds: -10)), '00:00');
    });

    test('DealModel.isExpired correctly identifies active vs expired flash deals', () {
      final activeDeal = createDeal(
        id: 1,
        name: 'Active deal',
        flashSaleEndsAt: DateTime.now().add(const Duration(minutes: 30)),
      );
      expect(activeDeal.isFlashSale, isTrue);
      expect(activeDeal.isExpired, isFalse);

      final expiredDeal = createDeal(
        id: 2,
        name: 'Expired deal',
        flashSaleEndsAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      expect(expiredDeal.isFlashSale, isTrue);
      expect(expiredDeal.isExpired, isTrue);

      final regularDeal = createDeal(
        id: 3,
        name: 'Regular deal',
        flashSaleEndsAt: null,
      );
      expect(regularDeal.isFlashSale, isFalse);
      expect(regularDeal.isExpired, isFalse);
    });

    test('CartService rejects adding an expired flash deal', () {
      final cart = CartService();
      final expiredDeal = createDeal(
        id: 10,
        name: 'Expired Croissant',
        flashSaleEndsAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );

      cart.add(expiredDeal);
      expect(cart.items, isEmpty);
      expect(cart.itemCount.value, 0);
    });

    test('CartService.removeExpiredDeals automatically removes expired items and notifies', () {
      final cart = CartService();
      final activeDeal = createDeal(
        id: 20,
        name: 'Active Salad',
        flashSaleEndsAt: DateTime.now().add(const Duration(hours: 1)),
      );
      final expiredDeal = createDeal(
        id: 21,
        name: 'Flash Bento',
        flashSaleEndsAt: DateTime.now().subtract(const Duration(seconds: 5)),
      );

      cart.add(activeDeal);
      expect(cart.items.length, 1);

      // Simulate item that was active when added, but expired later
      cart.items.add(CartItemModel(deal: expiredDeal));
      cart.itemCount.value = cart.items.fold(0, (sum, i) => sum + i.quantity);

      expect(cart.items.any((i) => i.deal.id == 21), isTrue);
      expect(cart.itemCount.value, 2);

      // Trigger expiration sweep
      cart.removeExpiredDeals();

      expect(cart.items.any((i) => i.deal.id == 21), isFalse);
      expect(cart.items.any((i) => i.deal.id == 20), isTrue);
      expect(cart.itemCount.value, 1);
    });

    test('DealModel.fromJson parses flashSaleEndsAt in local time', () {
      final json = {
        'id': 99,
        'name': 'Sale Item',
        'pickupWindow': {
          'start': '2026-10-01T10:00:00.000Z',
          'end': '2026-10-01T12:00:00.000Z',
        },
        'flashSaleEndsAt': '2026-10-01T15:00:00.000Z',
      };
      final deal = DealModel.fromJson(json);
      expect(deal.flashSaleEndsAt, isNotNull);
      expect(deal.flashSaleEndsAt!.isUtc, isFalse);
    });

    testWidgets('CountdownText displays formatted remaining time and fires onExpired', (tester) async {
      Get.reset();
      final countdownService = Get.put(CountdownService());
      final baseTime = DateTime(2026, 1, 1, 12, 0, 0);
      countdownService.clock.value = baseTime;

      final targetTime = DateTime(2026, 1, 1, 12, 5, 30);
      bool expiredFired = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CountdownText(
              endsAt: targetTime,
              onExpired: () {
                expiredFired = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('05:30'), findsOneWidget);
      expect(expiredFired, isFalse);

      // Advance clock past expiration
      countdownService.clock.value = DateTime(2026, 1, 1, 12, 5, 31);
      await tester.pump();
      await tester.pump(Duration.zero);

      expect(find.text('00:00'), findsOneWidget);
      expect(expiredFired, isTrue);

      Get.reset();
    });
  });
}
