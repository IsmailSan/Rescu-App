import 'deal_model.dart';
import 'reservation_model.dart';

class CartItemModel {
  final DealModel deal;
  int quantity;

  ReservationModel? reservation;

  CartItemModel({required this.deal, this.quantity = 1, this.reservation});

  num get lineTotal => deal.price * quantity;

  String get reservationLeftText => reservationLeftTextAt(DateTime.now());

  String reservationLeftTextAt(DateTime now) {
    final reservationValue = reservation;
    if (reservationValue == null) return '';

    final remaining = reservationValue.expiresAt.toUtc().difference(now.toUtc());
    if (remaining <= Duration.zero) return 'Expired';

    final totalSeconds = remaining.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return 'Reserved ${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} left';
    }
    return 'Reserved ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} left';
  }
}
