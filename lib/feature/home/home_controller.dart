import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../../model/deal_model.dart';
import '../../repository/deal_repo.dart';
import '../../util/log_service.dart';

class HomeController extends GetxController {
  final DealRepo dealRepo;

  HomeController({required this.dealRepo});

  final deals = <DealModel>[].obs;
  final flashDeals = <DealModel>[].obs;
  final isLoading = true.obs;
  final todayOnly = false.obs;
  final scrollOffset = 0.0.obs;
  final hasScrolled = false.obs;
  final showScrollToTop = false.obs;

  final scrollController = ScrollController();
  final refreshController = RefreshController();

  int _page = 1;
  int _totalPages = 1;
  bool _isFetchingMore = false;
  bool _isRefreshing = false;
  int _epoch = 0;

  bool get hasMore => _page < _totalPages;

  List<DealModel> get visibleDeals => todayOnly.value
      ? deals.where((d) => d.pickupWindow.isToday).toList()
      : deals;

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_onScroll);
    _initialLoad();
  }

  void _onScroll() {
    final offset = scrollController.offset;
    final scrolled = offset > 4;
    if (hasScrolled.value != scrolled) {
      hasScrolled.value = scrolled;
    }
    final showTop = offset > 800;
    if (showScrollToTop.value != showTop) {
      showScrollToTop.value = showTop;
    }
  }

  Future<void> _initialLoad() async {
    isLoading.value = true;
    try {
      await Future.wait([refreshDeals(), _loadFlashDeals()]);
    } catch (e) {
      LogService.error('initial load failed', e);
    }
    isLoading.value = false;
  }

  Future<void> _loadFlashDeals() async {
    flashDeals.assignAll(await dealRepo.fetchFlashDeals());
  }

  Future<void> refreshDeals() async {
    final currentEpoch = ++_epoch;
    _isRefreshing = true;
    _isFetchingMore = false;

    try {
      final res = await dealRepo.fetchDeals(page: 1);
      if (currentEpoch != _epoch || isClosed) return;

      _page = 1;
      _totalPages = res.totalPages;
      deals.assignAll(res.items);
      refreshController.resetNoData();
      refreshController.refreshCompleted();
    } catch (e) {
      if (currentEpoch == _epoch && !isClosed) {
        refreshController.refreshFailed();
      }
    } finally {
      if (currentEpoch == _epoch) {
        _isRefreshing = false;
      }
    }
  }

  Future<void> loadMore() async {
    if (_isFetchingMore || _isRefreshing) return;
    if (!hasMore) {
      refreshController.loadNoData();
      return;
    }

    _isFetchingMore = true;
    final currentEpoch = _epoch;
    final targetPage = _page + 1;

    try {
      final res = await dealRepo.fetchDeals(page: targetPage);
      if (currentEpoch != _epoch || isClosed) return;

      _page = targetPage;
      _totalPages = res.totalPages;
      final existingIds = deals.map((d) => d.id).toSet();
      final newItems =
          res.items.where((d) => !existingIds.contains(d.id)).toList();
      deals.addAll(newItems);

      if (_page >= _totalPages) {
        refreshController.loadNoData();
      } else {
        refreshController.loadComplete();
      }
    } catch (e) {
      LogService.error('loadMore failed', e);
      if (currentEpoch == _epoch && !isClosed) {
        refreshController.loadFailed();
      }
    } finally {
      _isFetchingMore = false;
    }
  }

  void scrollToTop() {
    scrollController.animateTo(0,
        duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
  }

  @override
  void onClose() {
    scrollController.dispose();
    refreshController.dispose();
    super.onClose();
  }
}
