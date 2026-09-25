import 'package:flutter_test/flutter_test.dart';
import 'package:rescu/feature/home/home_controller.dart';
import 'package:rescu/model/deal_model.dart';
import 'package:rescu/model/paged_response_model.dart';
import 'package:rescu/model/pickup_window_model.dart';
import 'package:rescu/repository/deal_repo.dart';
import 'package:rescu/service/fake_api_service.dart';

class MockDealRepo extends DealRepo {
  MockDealRepo() : super(api: FakeApiService());

  DealModel _createDeal(int id) {
    return DealModel(
      id: id,
      name: 'Deal $id',
      description: 'Desc',
      imageUrl: '',
      originalPrice: 100,
      price: 50,
      currencyCode: 'THB',
      quantityLeft: 5,
      storeId: 1,
      storeName: 'Store',
      storeAddress: 'Address',
      lat: 0,
      lng: 0,
      rating: 4.5,
      tags: [],
      pickupWindow: PickupWindowModel(
        start: DateTime.now(),
        end: DateTime.now().add(const Duration(hours: 2)),
      ),
      flashSaleEndsAt: null,
    );
  }

  @override
  Future<PagedResponseModel<DealModel>> fetchDeals({int page = 1}) async {
    // Simulate network latency: page 2 (loadMore) is slower than page 1 (refresh)
    if (page == 2) {
      await Future.delayed(const Duration(milliseconds: 100));
      return PagedResponseModel(
        items: List.generate(5, (i) => _createDeal(20 + i)),
        page: 2,
        totalPages: 3,
      );
    } else {
      await Future.delayed(const Duration(milliseconds: 20));
      return PagedResponseModel(
        items: List.generate(5, (i) => _createDeal(10 + i)),
        page: 1,
        totalPages: 3,
      );
    }
  }

  @override
  Future<List<DealModel>> fetchFlashDeals() async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomeController Tests', () {
    test('RES-104: loadMore followed by refresh does not cause duplicate deals', () async {
      final repo = MockDealRepo();
      final controller = HomeController(dealRepo: repo);

      // Initial state: page 1 loaded via refreshDeals (same as when the app is first opened)
      await controller.refreshDeals();
      expect(controller.deals.length, 5);

      // 1. User scrolls to bottom -> triggers loadMore (fetches page 2, 100ms delay)
      final loadMoreFuture = controller.loadMore();

      // 2. Shortly after, user pulls to refresh (fetches page 1, 20ms delay)
      final refreshFuture = controller.refreshDeals();

      await Future.wait([loadMoreFuture, refreshFuture]);

      // 3. User scrolls to bottom again for the next loadMore
      await controller.loadMore();

      final ids = controller.deals.map((d) => d.id).toList();
      final uniqueIds = ids.toSet().toList();

      // Verify that the stale loadMore response was discarded and no duplicates occurred
      expect(ids.length, equals(uniqueIds.length),
          reason: 'There should be no duplicate IDs after race condition fix!');
      expect(controller.deals.length, 10);
      expect(uniqueIds.length, 10);
    });
  });
}
