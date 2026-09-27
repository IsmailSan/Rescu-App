import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'cart_service.dart';

/// Centralized 1-second pulse for flash sale countdowns across the entire app.
///
/// Using a single shared clock avoids spawning dozens of separate [Timer]
/// instances when browsing a feed with 100+ deals. Rebuilds are isolated
/// to leaf text widgets observing [clock].
class CountdownService extends GetxService {
  final ValueNotifier<DateTime> clock = ValueNotifier<DateTime>(DateTime.now());
  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      clock.value = now;
      _checkExpiredCartDeals();
    });
  }

  void _checkExpiredCartDeals() {
    if (Get.isRegistered<CartService>()) {
      Get.find<CartService>().removeExpiredDeals();
    }
  }

  @override
  void onClose() {
    _timer?.cancel();
    clock.dispose();
    super.onClose();
  }

  /// Formats remaining duration into `mm:ss`, or `hh:mm:ss` when above an hour.
  static String format(Duration duration) {
    if (duration <= Duration.zero) return '00:00';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}
