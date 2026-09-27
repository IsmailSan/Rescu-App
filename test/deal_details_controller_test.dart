import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rescu/feature/deal/deal_details_controller.dart';
import 'package:rescu/model/deal_model.dart';
import 'package:rescu/model/pickup_window_model.dart';
import 'package:rescu/repository/deal_repo.dart';
import 'package:rescu/service/analytics_service.dart';
import 'package:rescu/service/cart_service.dart';
import 'package:rescu/service/fake_api_service.dart';

class MockDealRepo extends DealRepo {
  MockDealRepo() : super(api: FakeApiService());

  @override
  Future<DealModel> fetchById(int id) async {
    if (id == 42) {
      return DealModel(
        id: 42,
        name: 'Croissant Deal',
        description: 'Delicious bakery deal',
        imageUrl: 'https://example.com/croissant.jpg',
        originalPrice: 100,
        price: 50,
        currencyCode: 'THB',
        quantityLeft: 3,
        storeId: 1,
        storeName: 'Bakery Store',
        storeAddress: '123 Bakery Lane',
        lat: 13.75,
        lng: 100.5,
        rating: 4.8,
        tags: ['bakery'],
        pickupWindow: PickupWindowModel(
          start: DateTime.now(),
          end: DateTime.now().add(const Duration(hours: 2)),
        ),
        flashSaleEndsAt: null,
      );
    }
    throw Exception('Deal not found');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDealRepo mockDealRepo;
  late CartService cartService;
  late AnalyticsService analytics;

  setUp(() {
    Get.reset();
    mockDealRepo = MockDealRepo();
    cartService = CartService();
    analytics = AnalyticsService();
  });

  tearDown(() {
    Get.reset();
  });

  group('DealDetailsController — RES-107 deep link fix', () {
    test('loads deal immediately when passed via Get.arguments (in-app tap)', () {
      final sampleDeal = DealModel(
        id: 10,
        name: 'In-app deal',
        description: 'Desc',
        imageUrl: '',
        originalPrice: 80,
        price: 40,
        currencyCode: 'THB',
        quantityLeft: 5,
        storeId: 1,
        storeName: 'Store',
        storeAddress: 'Address',
        lat: 0,
        lng: 0,
        rating: null,
        tags: [],
        pickupWindow: PickupWindowModel(
          start: DateTime.now(),
          end: DateTime.now().add(const Duration(hours: 1)),
        ),
        flashSaleEndsAt: null,
      );

      // Simulate navigation with memory arguments
      Get.routing.args = sampleDeal;

      final controller = DealDetailsController(
        dealRepo: mockDealRepo,
        cartService: cartService,
        analytics: analytics,
      );

      controller.onInit();

      expect(controller.isLoading, isFalse);
      expect(controller.deal, isNotNull);
      expect(controller.deal!.id, 10);
      expect(controller.quantityLeft, 5);

      controller.onClose();
    });

    test('fetches deal by id when arguments is null (deep link)', () async {
      // Simulate deep link: rescu://open/deal?id=42&source=push
      Get.routing.args = null;
      Get.parameters = {'id': '42', 'source': 'push'};

      final controller = DealDetailsController(
        dealRepo: mockDealRepo,
        cartService: cartService,
        analytics: analytics,
      );

      controller.onInit();

      // Initially loading
      expect(controller.isLoading, isTrue);
      expect(controller.deal, isNull);

      // Wait for async fetch to complete
      await Future.delayed(const Duration(milliseconds: 50));

      expect(controller.isLoading, isFalse);
      expect(controller.deal, isNotNull);
      expect(controller.deal!.id, 42);
      expect(controller.deal!.name, 'Croissant Deal');
      expect(controller.quantityLeft, 3);
      expect(controller.errorMessage, isNull);

      controller.onClose();
    });

    test('handles invalid deep link gracefully without throwing unhandled exception', () async {
      Get.routing.args = null;
      Get.parameters = {'id': '999', 'source': 'push'};

      final controller = DealDetailsController(
        dealRepo: mockDealRepo,
        cartService: cartService,
        analytics: analytics,
      );

      controller.onInit();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(controller.isLoading, isFalse);
      expect(controller.deal, isNull);
      expect(controller.errorMessage, contains('Could not load deal #999'));

      controller.onClose();
    });
  });
}
