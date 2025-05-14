import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;

class StorageService extends GetxService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadFile({
    required File file,
    required String folder,
    String? fileName,
  }) async {
    try {
      final String fileExtension = path.extension(file.path);
      final String uniqueFileName = fileName ?? '${DateTime.now().millisecondsSinceEpoch}$fileExtension';
      final String storagePath = '$folder/$uniqueFileName';

      final Reference storageRef = _storage.ref().child(storagePath);
      final UploadTask uploadTask = storageRef.putFile(file);
      final TaskSnapshot taskSnapshot = await uploadTask;
      
      return await taskSnapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading file: $e');
      rethrow;
    }
  }

  Future<void> deleteFile(String fileUrl) async {
    try {
      final Reference storageRef = _storage.refFromURL(fileUrl);
      await storageRef.delete();
    } catch (e) {
      debugPrint('Error deleting file: $e');
      rethrow;
    }
  }

  Future<String> getDownloadUrl(String filePath) async {
    try {
      return await _storage.ref().child(filePath).getDownloadURL();
    } catch (e) {
      debugPrint('Error getting download URL: $e');
      rethrow;
    }
  }
} 