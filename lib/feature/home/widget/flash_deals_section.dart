import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app_config.dart';
import '../../../model/deal_model.dart';
import '../../../routes/routes.dart';
import '../../shared_widget/countdown_text.dart';
import '../../shared_widget/deal_impression_tracker.dart';
import '../../shared_widget/the_network_image.dart';

/// Horizontal flash-sale rail with live per-deal countdown timers.
class FlashDealsSection extends StatefulWidget {
  final List<DealModel> deals;

  const FlashDealsSection({super.key, required this.deals});

  @override
  State<FlashDealsSection> createState() => _FlashDealsSectionState();
}

class _FlashDealsSectionState extends State<FlashDealsSection>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final deals = widget.deals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(Icons.bolt, color: Colors.red, size: 20),
              SizedBox(width: 4),
              Text('Flash sales',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        SizedBox(
          height: 190,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: deals.length,
            itemBuilder: (context, index) {
              return _FlashDealRailCard(deal: deals[index], position: index);
            },
          ),
        ),
      ],
    );
  }
}

class _FlashDealRailCard extends StatefulWidget {
  final DealModel deal;
  final int position;
  const _FlashDealRailCard({required this.deal, required this.position});

  @override
  State<_FlashDealRailCard> createState() => _FlashDealRailCardState();
}

class _FlashDealRailCardState extends State<_FlashDealRailCard> {
  late final ValueNotifier<bool> _isExpired;

  @override
  void initState() {
    super.initState();
    _isExpired = ValueNotifier<bool>(widget.deal.isExpired);
  }

  @override
  void dispose() {
    _isExpired.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deal = widget.deal;
    return DealImpressionTracker(
      dealId: deal.id,
      source: 'flash_rail',
      position: widget.position,
      child: ValueListenableBuilder<bool>(
        valueListenable: _isExpired,
        builder: (context, isExpired, _) {
          return SizedBox(
            width: 200,
            child: Card(
              color: Colors.white,
              elevation: 0.5,
              clipBehavior: Clip.antiAlias,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: isExpired
                    ? () {
                        if (Get.context != null && Get.key.currentState?.overlay != null) {
                          Get.snackbar(
                            'Deal expired',
                            'This flash deal has ended.',
                            snackPosition: SnackPosition.BOTTOM,
                            duration: const Duration(seconds: 2),
                          );
                        }
                      }
                    : () => Get.toNamed(
                          Routes.dealRoute(deal.id, source: 'flash_rail'),
                          arguments: deal,
                        ),
                child: Opacity(
                  opacity: isExpired ? 0.6 : 1.0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TheNetworkImage(
                        url: deal.imageUrl,
                        height: 90,
                        width: double.infinity,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              deal.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              deal.storeName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11.5, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  '฿${deal.price.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppConfig.primaryGreen),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isExpired
                                        ? Colors.grey.shade200
                                        : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: isExpired
                                      ? Text(
                                          'Expired',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade600,
                                          ),
                                        )
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.timer_outlined,
                                              size: 11,
                                              color: Colors.red.shade700,
                                            ),
                                            const SizedBox(width: 2),
                                            CountdownText(
                                              endsAt: deal.flashSaleEndsAt!,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.red.shade700,
                                              ),
                                              onExpired: () {
                                                _isExpired.value = true;
                                              },
                                            ),
                                          ],
                                        ),
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
            ),
          );
        },
      ),
    );
  }
}
