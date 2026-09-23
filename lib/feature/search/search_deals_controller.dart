import 'dart:async';
import 'package:get/get.dart';

import '../../model/deal_model.dart';
import '../../repository/deal_repo.dart';
import '../../util/log_service.dart';

class SearchDealsController extends GetxController {
  final DealRepo dealRepo;

  SearchDealsController({required this.dealRepo});

  final results = <DealModel>[].obs;
  final isLoading = false.obs;
  final hasSearched = false.obs;

  Timer? _debounceTimer;
  int _latestRequestId = 0;
  String _activeQuery = '';

  @override
  void onClose() {
    _debounceTimer?.cancel();
    super.onClose();
  }

  void onQueryChanged(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    _activeQuery = trimmed;

    if (trimmed.isEmpty) {
      _latestRequestId++;
      results.clear();
      hasSearched.value = false;
      isLoading.value = false;
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _search(trimmed);
    });
  }

  Future<void> _search(String query) async {
    final currentRequestId = ++_latestRequestId;
    isLoading.value = true;
    hasSearched.value = true;

    try {
      final found = await dealRepo.search(query);
      // Double guard: Ensure requestId is the newest AND query matches what is in the search box
      if (currentRequestId == _latestRequestId && query == _activeQuery) {
        results.assignAll(found);
      }
    } catch (e) {
      if (currentRequestId == _latestRequestId) {
        LogService.error('search failed', e);
      }
    } finally {
      if (currentRequestId == _latestRequestId) {
        isLoading.value = false;
      }
    }
  }
}
