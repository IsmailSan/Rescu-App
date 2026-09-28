import 'dart:async';

import 'package:get/get.dart';

import '../model/cart_item_model.dart';
import '../model/deal_model.dart';
import '../model/reservation_model.dart';
import '../repository/order_repo.dart';
import '../service/api_exception.dart';
import '../util/log_service.dart';

class CartService extends GetxService {
  final OrderRepo? orderRepo;
  Timer? _reservationMonitor;

  final items = <CartItemModel>[].obs;
  final itemCount = 0.obs;

  CartService({this.orderRepo}) {
    _reservationMonitor = Timer.periodic(const Duration(seconds: 1), (_) {
      _expireReservationLines();
    });
  }

  OrderRepo? get _resolvedOrderRepo =>
      orderRepo ?? (Get.isRegistered<OrderRepo>() ? Get.find<OrderRepo>() : null);

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

  Future<void> add(DealModel deal) async {
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

      final previousQty = existing.quantity;
      final previousReservation = existing.reservation;
      existing.quantity++;
      _recount();
      items.refresh();

      try {
        await _replaceReservation(
          existing,
          previousReservation: previousReservation,
          previousQuantity: previousQty,
        );
      } catch (_) {
        // _replaceReservation handles rollback notices.
      }
      return;
    }

    final item = CartItemModel(deal: deal);
    items.add(item);
    _recount();

    try {
      final repo = _resolvedOrderRepo;
      if (repo == null) {
        return;
      }
      item.reservation = await repo.reserve(deal.id, quantity: item.quantity);
      items.refresh();
    } on ApiException catch (e) {
      items.remove(item);
      _recount();
      _showNotice('Reservation unavailable', e.message, duration: const Duration(seconds: 3));
      LogService.error('cart: reservation failed for deal ${deal.id}', e);
    }
  }

  Future<void> _replaceReservation(
    CartItemModel item, {
    required ReservationModel? previousReservation,
    required int previousQuantity,
  }) async {
    final repo = _resolvedOrderRepo;
    if (repo == null) return;

    try {
      if (previousReservation != null) {
        await repo.releaseReservation(previousReservation.id);
      }
      final fresh = await repo.reserve(item.deal.id, quantity: item.quantity);
      item.reservation = fresh;
      items.refresh();
    } on ApiException catch (e) {
      item.quantity = previousQuantity;
      item.reservation = previousReservation;
      _recount();
      items.refresh();
      _showNotice('Reservation unavailable', e.message, duration: const Duration(seconds: 3));
      LogService.error('cart: failed to adjust reservation for deal ${item.deal.id}', e);
    }
  }

  Future<void> _releaseReservation(String reservationId) async {
    final repo = _resolvedOrderRepo;
    if (repo == null) return;
    try {
      await repo.releaseReservation(reservationId);
    } on ApiException catch (e) {
      LogService.error('cart: failed to release reservation $reservationId', e);
    }
  }

  void _expireReservationLines() {
    if (items.isEmpty) return;

    final expiredItems = items.where((item) => item.reservation != null && item.reservation!.isExpired).toList();
    if (expiredItems.isEmpty) return;

    for (final item in expiredItems) {
      final reservationId = item.reservation?.id;
      final dealName = item.deal.name;
      items.removeWhere((entry) => entry.deal.id == item.deal.id);
      if (reservationId != null) {
        _releaseReservation(reservationId);
      }
      _showNotice(
        'Reservation expired',
        '$dealName was removed from your bag because its reservation expired.',
        duration: const Duration(seconds: 3),
      );
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
      final reservationId = item.reservation?.id;
      if (reservationId != null) {
        _releaseReservation(reservationId);
      }
      items.removeWhere((i) => i.deal.id == item.deal.id);
      _showNotice(
        'Deal expired',
        '${item.deal.name} was removed from your bag as the flash sale ended.',
        duration: const Duration(seconds: 3),
      );
    }
    _recount();
  }

  Future<void> decrement(int dealId) async {
    final existing = items.firstWhereOrNull((i) => i.deal.id == dealId);
    if (existing == null) return;

    if (existing.quantity <= 1) {
      await remove(dealId);
      return;
    }

    final previousReservation = existing.reservation;
    final previousQuantity = existing.quantity;
    existing.quantity--;
    _recount();
    items.refresh();

    try {
      await _replaceReservation(
        existing,
        previousReservation: previousReservation,
        previousQuantity: previousQuantity,
      );
    } catch (_) {
      // _replaceReservation handles rollback.
    }
  }

  Future<void> remove(int dealId) async {
    final existing = items.firstWhereOrNull((i) => i.deal.id == dealId);
    if (existing == null) return;

    final reservationId = existing.reservation?.id;
    if (reservationId != null) {
      await _releaseReservation(reservationId);
    }
    items.removeWhere((i) => i.deal.id == dealId);
    _recount();
  }

  Future<void> clear() async {
    for (final item in List<CartItemModel>.from(items)) {
      final reservationId = item.reservation?.id;
      if (reservationId != null) {
        await _releaseReservation(reservationId);
      }
    }
    items.clear();
    _recount();
  }

  num get total => items.fold(0, (sum, i) => sum + i.lineTotal);

  void _recount() {
    itemCount.value = items.fold(0, (sum, i) => sum + i.quantity);
  }

  @override
  void onClose() {
    _reservationMonitor?.cancel();
    super.onClose();
  }
}
