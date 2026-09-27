import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app_config.dart';
import '../shared_widget/countdown_text.dart';
import '../shared_widget/the_network_image.dart';
import 'deal_details_controller.dart';

class DealDetailsScreen extends GetView<DealDetailsController> {
  const DealDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading) {
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: AppConfig.primaryGreen),
          ),
        );
      }

      final deal = controller.deal;
      if (deal == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Deal Details')),
          body: Center(
            child: Text(
              controller.errorMessage ?? 'Deal not found',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        );
      }

      return Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 240,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background:
                    TheNetworkImage(url: deal.imageUrl, fit: BoxFit.cover),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(deal.name,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(deal.storeName,
                        style: TextStyle(
                            fontSize: 15, color: Colors.grey.shade700)),
                    Text(deal.storeAddress,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade500)),
                    if (deal.isFlashSale) ...[
                      const SizedBox(height: 12),
                      Obx(() {
                        final isExpired = controller.isExpired.value;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isExpired
                                ? Colors.grey.shade100
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isExpired
                                  ? Colors.grey.shade300
                                  : Colors.red.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isExpired
                                    ? Icons.timer_off_outlined
                                    : Icons.bolt,
                                color: isExpired
                                    ? Colors.grey.shade600
                                    : Colors.red.shade700,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isExpired
                                    ? 'Flash sale ended'
                                    : 'Flash sale ends in: ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isExpired
                                      ? Colors.grey.shade700
                                      : Colors.red.shade700,
                                ),
                              ),
                              if (!isExpired)
                                CountdownText(
                                  endsAt: deal.flashSaleEndsAt!,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.red.shade700,
                                  ),
                                  onExpired: () => controller.markExpired(),
                                ),
                            ],
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text('฿${deal.price.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppConfig.primaryGreen)),
                        const SizedBox(width: 8),
                        Text('฿${deal.originalPrice.toStringAsFixed(0)}',
                            style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade500,
                                decoration: TextDecoration.lineThrough)),
                        const Spacer(),
                        Obx(() => Chip(
                              avatar: const Icon(Icons.inventory_2_outlined,
                                  size: 16),
                              label: Text('${controller.quantityLeft ?? '-'} left'),
                            )),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE0E5E2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule,
                              color: AppConfig.primaryGreen),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Pickup window',
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.grey)),
                              Text(
                                '${deal.pickupWindow.label}'
                                '${deal.pickupWindow.isToday ? ' · today' : ''}',
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const Spacer(),
                          if (deal.pickupWindow.isOpenNow)
                            const Chip(
                              label: Text('Open now'),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('What you get',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(deal.description,
                        style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Colors.grey.shade800)),
                    if (deal.tags.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: deal.tags
                            .map((t) => Chip(
                                  label: Text(t),
                                  visualDensity: VisualDensity.compact,
                                ))
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomSheet: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          color: Colors.white,
          child: SizedBox(
            width: double.infinity,
            child: Obx(() {
              final isExpired = controller.isExpired.value;
              return FilledButton.icon(
                onPressed: isExpired ? null : controller.addToCart,
                icon: Icon(isExpired ? Icons.block : Icons.add_shopping_cart),
                label: Text(isExpired ? 'Deal expired' : 'Add to bag'),
                style: isExpired
                    ? FilledButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.grey.shade600,
                      )
                    : null,
              );
            }),
          ),
        ),
      );
    });
  }
}
