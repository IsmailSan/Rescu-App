import 'package:get/get.dart';

import '../../model/deal_model.dart';
import '../../repository/deal_repo.dart';
import '../../service/analytics_service.dart';
import '../../service/cart_service.dart';
import '../../util/log_service.dart';

class DealDetailsController extends GetxController {
  final DealRepo dealRepo;
  final CartService cartService;
  final AnalyticsService analytics;

  DealDetailsController({
    required this.dealRepo,
    required this.cartService,
    required this.analytics,
  });

  final _deal = Rxn<DealModel>();
  DealModel? get deal => _deal.value;

  final _isLoading = false.obs;
  bool get isLoading => _isLoading.value;

  final _errorMessage = RxnString();
  String? get errorMessage => _errorMessage.value;

  final _quantityLeft = RxnInt();
  int? get quantityLeft => _quantityLeft.value;

  Worker? _cartWorker;

  final isExpired = false.obs;

  @override
  void onInit() {
    super.onInit();
    _initDeal();
  }

  Future<void> _initDeal() async {
    // 1. If passed via in-memory arguments (e.g. from home feed)
    if (Get.arguments is DealModel) {
      final passedDeal = Get.arguments as DealModel;
      _deal.value = passedDeal;
      _onDealLoaded(passedDeal);
      return;
    }

    // 2. If opened via deep link (arguments is null), parse id from parameters
    final idParam = Get.parameters['id'];
    final id = int.tryParse(idParam ?? '');
    if (id != null) {
      _isLoading.value = true;
      try {
        final fetched = await dealRepo.fetchById(id);
        if (isClosed) return;
        _deal.value = fetched;
        _onDealLoaded(fetched);
      } catch (e) {
        if (isClosed) return;
        _errorMessage.value = 'Could not load deal #$id';
      } finally {
        if (!isClosed) {
          _isLoading.value = false;
        }
      }
    } else {
      _errorMessage.value = 'Invalid deal parameter';
    }
  }

  void _onDealLoaded(DealModel loadedDeal) {
    _quantityLeft.value = loadedDeal.quantityLeft;
    isExpired.value = loadedDeal.isExpired;
    analytics.logEvent('deal_details_view', {
      'deal_id': loadedDeal.id,
      'source': Get.parameters['source'] ?? 'unknown',
    });
    // Whenever the cart changes, re-check this deal's remaining stock so the
    // details screen never shows stale availability.
    _cartWorker?.dispose();
    _cartWorker = ever(cartService.itemCount, (_) => _recheckAvailability());
  }

  void markExpired() {
    isExpired.value = true;
  }

  @override
  void onClose() {
    _cartWorker?.dispose();
    super.onClose();
  }

  Future<void> _recheckAvailability() async {
    final currentDeal = _deal.value;
    if (currentDeal == null) return;
    LogService.log('re-checking availability for deal ${currentDeal.id}');
    final fresh = await dealRepo.fetchById(currentDeal.id);
    if (isClosed) return;
    _quantityLeft.value = fresh.quantityLeft;
  }

  void addToCart() {
    final currentDeal = _deal.value;
    if (currentDeal == null) return;
    if (isExpired.value || currentDeal.isExpired) {
      isExpired.value = true;
      if (Get.context != null && Get.key.currentState?.overlay != null) {
        Get.snackbar(
          'Deal expired',
          'This flash sale has ended and can no longer be added to your bag.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
      }
      return;
    }
    cartService.add(currentDeal);
    if (Get.context != null && Get.key.currentState?.overlay != null) {
      Get.snackbar(
        'Added to bag',
        '${currentDeal.name} — pick up ${currentDeal.pickupWindow.label}',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    }
  }
}
