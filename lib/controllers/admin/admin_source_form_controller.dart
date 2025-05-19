import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/source_service.dart';

class AdminSourceFormController extends GetxController {
  final SourceService _sourceService = Get.find<SourceService>();
  final formKey = GlobalKey<FormState>();

  final isLoading = false.obs;
  final isEditing = false.obs;
  String? sourceId;
  String? name;
  String? description;

  @override
  void onInit() {
    super.onInit();
    loadSource();
  }

  Future<void> loadSource() async {
    final sourceId = Get.arguments as String?;
    if (sourceId == null) return;

    isLoading.value = true;
    isEditing.value = true;
    this.sourceId = sourceId;

    try {
      final source = await _sourceService.getSource(sourceId);
      name = source.name;
      description = source.description;
      update();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load source: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> isSourceNameUnique(String name) async {
    final lowerName = name.trim().toLowerCase();
    final sources = await _sourceService.getAllSources();
    return !sources.any((s) =>
      s.name.trim().toLowerCase() == lowerName &&
      (!isEditing.value || s.id != sourceId)
    );
  }

  Future<void> saveSource() async {
    if (!formKey.currentState!.validate()) return;

    isLoading.value = true;
    try {
      final isUnique = await isSourceNameUnique(name!);
      if (!isUnique) {
        isLoading.value = false;
        Get.snackbar(
          'Error',
          'A source with this name already exists.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      if (isEditing.value) {
        await _sourceService.updateSource(
          sourceId!,
          name!,
          description: description,
        );
      } else {
        await _sourceService.createSource(
          name!,
          description: description,
        );
      }

      Get.back(result: true);
      Get.snackbar(
        'Success',
        'Source ${isEditing.value ? 'updated' : 'created'} successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to ${isEditing.value ? 'update' : 'create'} source: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a name';
    }
    return null;
  }

  String? validateDescription(String? value) {
    // Description is optional, so no validation needed
    return null;
  }
} 