import 'package:get/get.dart';

import '../model/cart_item_model.dart';
import '../model/deal_model.dart';
import '../util/log_service.dart';

/// App-wide cart. Lives for the whole session.
///
/// NOTE: the starter cart is purely local — it does not reserve stock on the
/// backend. See the "Reservations" feature task in PROBLEM.md.
class CartService extends GetxService {
  final items = <CartItemModel>[].obs;
  final itemCount = 0.obs;

  void _showNotice(String title, String message, {Duration duration = const Duration(seconds: 2)}) {
    if (Get.context != null && Get.key.currentState?.overlay != null) {
      Get.snackbar(
        title,
        message,
        snackPosition: SnackPosition.BOTTOM,
        duration: duration,
      );
    }
  }

  void add(DealModel deal) {
    if (deal.isExpired) {
      LogService.log('cart: cannot add expired deal ${deal.id}');
      _showNotice(
        'Deal expired',
        'This flash sale has ended and can no longer be added to your bag.',
        duration: const Duration(seconds: 2),
      );
      return;
    }

    final existing = items.firstWhereOrNull((i) => i.deal.id == deal.id);
    if (existing != null) {
      if (existing.quantity >= deal.quantityLeft) {
        LogService.log('cart: cannot add more of deal ${deal.id}');
        return;
      }
      existing.quantity++;
      items.refresh();
    } else {
      items.add(CartItemModel(deal: deal));
    }
    _recount();
  }

  /// Removes any flash sale deals that have expired while in the bag,
  /// presenting a visible notice to the user.
  void removeExpiredDeals() {
    if (items.isEmpty) return;
    final now = DateTime.now();
    final expiredItems = items.where((item) {
      final endsAt = item.deal.flashSaleEndsAt;
      return endsAt != null && now.isAfter(endsAt);
    }).toList();

    if (expiredItems.isEmpty) return;

    for (final item in expiredItems) {
      items.removeWhere((i) => i.deal.id == item.deal.id);
      _showNotice(
        'Deal expired',
        '${item.deal.name} was removed from your bag as the flash sale ended.',
        duration: const Duration(seconds: 3),
      );
    }
    _recount();
  }

  void decrement(int dealId) {
    final existing = items.firstWhereOrNull((i) => i.deal.id == dealId);
    if (existing == null) return;
    existing.quantity--;
    if (existing.quantity <= 0) {
      items.removeWhere((i) => i.deal.id == dealId);
    } else {
      items.refresh();
    }
    _recount();
  }

  void remove(int dealId) {
    items.removeWhere((i) => i.deal.id == dealId);
    _recount();
  }

  void clear() {
    items.clear();
    _recount();
  }

  num get total => items.fold(0, (sum, i) => sum + i.lineTotal);

  void _recount() {
    itemCount.value = items.fold(0, (sum, i) => sum + i.quantity);
  }
}
