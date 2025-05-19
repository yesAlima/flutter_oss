import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/source_model.dart';
import '../../services/source_service.dart';

class AdminSourcesController extends GetxController {
  final SourceService _sourceService = Get.find<SourceService>();

  final sources = <SourceModel>[].obs;
  final isLoading = true.obs;
  final searchController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    loadSources();
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  Future<void> loadSources() async {
    isLoading.value = true;
    try {
      final sourceList = await _sourceService.getAllSources();
      sources.value = sourceList;
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load sources: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  List<SourceModel> get filteredSources {
    final searchTerm = searchController.text.toLowerCase();
    return sources.where((source) {
      final name = source.name.toLowerCase();
      final description = source.description?.toLowerCase() ?? '';
      return name.contains(searchTerm) || description.contains(searchTerm);
    }).toList();
  }

  Future<void> deleteSource(String id) async {
    try {
      await _sourceService.deleteSource(id);
      sources.removeWhere((src) => src.id == id);
      Get.snackbar(
        'Success',
        'Source deleted successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to delete source: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void updateSourceInList(SourceModel updatedSource) {
    final index = sources.indexWhere((src) => src.id == updatedSource.id);
    if (index != -1) {
      sources[index] = updatedSource;
    }
  }
} 