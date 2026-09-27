import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app_config.dart';
import '../../model/deal_model.dart';
import '../../routes/routes.dart';
import 'countdown_text.dart';
import 'the_network_image.dart';

/// Deal card used in the home feed and search results.
class DealCard extends StatefulWidget {
  final DealModel deal;
  final String source;

  const DealCard({super.key, required this.deal, this.source = 'home'});

  @override
  State<DealCard> createState() => _DealCardState();
}

class _DealCardState extends State<DealCard> {
  late final ValueNotifier<bool> _isExpired;

  @override
  void initState() {
    super.initState();
    _isExpired = ValueNotifier<bool>(widget.deal.isExpired);
  }

  @override
  void didUpdateWidget(covariant DealCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deal.id != widget.deal.id ||
        oldWidget.deal.flashSaleEndsAt != widget.deal.flashSaleEndsAt) {
      _isExpired.value = widget.deal.isExpired;
    }
  }

  @override
  void dispose() {
    _isExpired.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deal = widget.deal;
    return ValueListenableBuilder<bool>(
      valueListenable: _isExpired,
      builder: (context, isExpired, _) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          clipBehavior: Clip.hardEdge,
          color: Colors.white,
          elevation: 0.5,
          child: InkWell(
            onTap: isExpired
                ? () {
                    if (Get.context != null && Get.key.currentState?.overlay != null) {
                      Get.snackbar(
                        'Deal expired',
                        'This flash sale deal has ended.',
                        snackPosition: SnackPosition.BOTTOM,
                        duration: const Duration(seconds: 2),
                      );
                    }
                  }
                : () => Get.toNamed(
                      Routes.dealRoute(deal.id, source: widget.source),
                      arguments: deal,
                    ),
            child: Opacity(
              opacity: isExpired ? 0.6 : 1.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      TheNetworkImage(
                          url: deal.imageUrl,
                          height: 160,
                          width: double.infinity),
                      if (deal.isFlashSale)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isExpired
                                  ? Colors.grey.shade700
                                  : Colors.red.shade600,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: isExpired
                                ? const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.timer_off_outlined,
                                          color: Colors.white, size: 12),
                                      SizedBox(width: 4),
                                      Text(
                                        'EXPIRED',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.bolt,
                                          color: Colors.white, size: 13),
                                      const SizedBox(width: 2),
                                      const Text(
                                        'FLASH SALE · ',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      CountdownText(
                                        endsAt: deal.flashSaleEndsAt!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        onExpired: () {
                                          _isExpired.value = true;
                                        },
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${deal.quantityLeft} left',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(deal.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(deal.storeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12.5, color: Colors.grey.shade600)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.schedule,
                                size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text('Pick up ${deal.pickupWindow.label}',
                                style: TextStyle(
                                    fontSize: 12.5, color: Colors.grey.shade700)),
                            const Spacer(),
                            if (deal.rating != null) ...[
                              const Icon(Icons.star_rounded,
                                  size: 15, color: Colors.amber),
                              Text(deal.rating!.toStringAsFixed(1),
                                  style: const TextStyle(fontSize: 12.5)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text('฿${deal.price.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppConfig.primaryGreen)),
                            const SizedBox(width: 6),
                            Text('฿${deal.originalPrice.toStringAsFixed(0)}',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade500,
                                    decoration: TextDecoration.lineThrough)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppConfig.primaryGreen.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('-${deal.discountPercent}%',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppConfig.primaryGreen)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
