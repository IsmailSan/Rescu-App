import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../service/countdown_service.dart';

/// Highly scoped live countdown text widget.
///
/// Subscribes strictly to [CountdownService.clock] via [ValueListenableBuilder],
/// so per-second ticks rebuild ONLY this text element, completely isolating
/// updates from parent cards and lists.
class CountdownText extends StatefulWidget {
  final DateTime endsAt;
  final TextStyle? style;
  final VoidCallback? onExpired;

  const CountdownText({
    super.key,
    required this.endsAt,
    this.style,
    this.onExpired,
  });

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  bool _expiredNotified = false;
  ValueNotifier<DateTime>? _localFallbackClock;

  ValueNotifier<DateTime> _getClock() {
    if (Get.isRegistered<CountdownService>()) {
      return Get.find<CountdownService>().clock;
    }
    return _localFallbackClock ??= ValueNotifier<DateTime>(DateTime.now());
  }

  @override
  void dispose() {
    _localFallbackClock?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultStyle = (widget.style ?? const TextStyle()).copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return ValueListenableBuilder<DateTime>(
      valueListenable: _getClock(),
      builder: (context, now, _) {
        final diff = widget.endsAt.difference(now);
        if (diff <= Duration.zero) {
          if (!_expiredNotified) {
            _expiredNotified = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                widget.onExpired?.call();
              }
            });
          }
          return Text(
            '00:00',
            style: defaultStyle,
          );
        }

        return Text(
          CountdownService.format(diff),
          style: defaultStyle,
        );
      },
    );
  }
}
