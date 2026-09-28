import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../service/analytics_service.dart';

/// Wraps a deal widget to track impression analytics.
///
/// Triggers a `deal_impression` event when the deal is ≥50% visible for at least
/// 1 continuous second. If the user scrolls away before 1 full second, the timer
/// is cancelled immediately.
///
/// If the deal has already received an impression in this app session, the
/// [VisibilityDetector] is completely bypassed to avoid unnecessary layout overhead.
class DealImpressionTracker extends StatefulWidget {
  final int dealId;
  final String source;
  final int position;
  final Widget child;

  const DealImpressionTracker({
    super.key,
    required this.dealId,
    required this.source,
    required this.position,
    required this.child,
  });

  @override
  State<DealImpressionTracker> createState() => _DealImpressionTrackerState();
}

class _DealImpressionTrackerState extends State<DealImpressionTracker> {
  Timer? _timer;
  bool _impressed = false;

  @override
  void initState() {
    super.initState();
    _checkAlreadyImpressed();
  }

  void _checkAlreadyImpressed() {
    if (Get.isRegistered<AnalyticsService>()) {
      _impressed = Get.find<AnalyticsService>().hasImpressed(widget.dealId);
    }
  }

  @override
  void didUpdateWidget(covariant DealImpressionTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dealId != widget.dealId) {
      _cancelTimer();
      _checkAlreadyImpressed();
    }
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _startTimer() {
    if (_impressed || _timer != null) return;
    _timer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      _impressed = true;
      _cancelTimer();
      if (Get.isRegistered<AnalyticsService>()) {
        Get.find<AnalyticsService>().recordDealImpression(
          dealId: widget.dealId,
          source: widget.source,
          position: widget.position,
        );
      }
    });
  }

  @override
  void dispose() {
    _cancelTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If already impressed during this session, bypass VisibilityDetector for performance
    if (_impressed) {
      return widget.child;
    }

    return VisibilityDetector(
      key: Key('deal_impression_${widget.source}_${widget.dealId}_${widget.position}'),
      onVisibilityChanged: (info) {
        if (_impressed) return;
        if (info.visibleFraction >= 0.5) {
          _startTimer();
        } else {
          _cancelTimer();
        }
      },
      child: widget.child,
    );
  }
}
