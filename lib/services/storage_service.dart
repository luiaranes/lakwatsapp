import 'package:flutter/foundation.dart' show debugPrint;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  String _getMimeType(String fileExtension) {
    return switch (fileExtension.toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }

  Future<XFile?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      return image;
    } catch (e) {
      debugPrint('StorageService: Error picking image from gallery: $e');
      rethrow;
    }
  }

  Future<XFile?> pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
        preferredCameraDevice: CameraDevice.front,
      );
      return image;
    } catch (e) {
      debugPrint('StorageService: Error picking image from camera: $e');
      rethrow;
    }
  }

  Future<String?> uploadAvatar(XFile imageFile) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final fileExtension = imageFile.path.split('.').last.toLowerCase();
      final fileName = 'avatar.$fileExtension';
      final filePath = '$userId/$fileName';

      debugPrint('StorageService: Uploading avatar to $filePath');

      final bytes = await imageFile.readAsBytes();

      // Upload to Supabase Storage
      await _supabase.storage.from('avatars').uploadBinary(
        filePath,
        bytes,
        fileOptions: FileOptions(
          upsert: true,
          contentType: _getMimeType(fileExtension),
        ),
      );

      // Get the public URL
      final publicUrl = _supabase.storage.from('avatars').getPublicUrl(filePath);
      
      // Add cache-busting query parameter
      final urlWithCacheBust = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      
      debugPrint('StorageService: Avatar uploaded successfully: $urlWithCacheBust');
      return urlWithCacheBust;
    } catch (e) {
      debugPrint('StorageService: Error uploading avatar: $e');
      rethrow;
    }
  }

  Future<void> deleteAvatar() async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // List files in user's avatar folder
      final files = await _supabase.storage.from('avatars').list(path: userId);
      
      if (files.isNotEmpty) {
        final filePaths = files.map((f) => '$userId/${f.name}').toList();
        await _supabase.storage.from('avatars').remove(filePaths);
        debugPrint('StorageService: Avatar deleted successfully');
      }
    } catch (e) {
      debugPrint('StorageService: Error deleting avatar: $e');
      rethrow;
    }
  }

  Future<String?> uploadTripCover(String tripId, XFile imageFile) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final fileExtension = imageFile.path.split('.').last.toLowerCase();
      final fileName = 'cover.$fileExtension';
      final filePath = '$tripId/$fileName';

      final bytes = await imageFile.readAsBytes();

      await _supabase.storage.from('trip-covers').uploadBinary(
        filePath,
        bytes,
        fileOptions: FileOptions(
          upsert: true,
          contentType: _getMimeType(fileExtension),
        ),
      );

      final publicUrl = _supabase.storage.from('trip-covers').getPublicUrl(filePath);
      final urlWithCacheBust = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      
      return urlWithCacheBust;
    } catch (e) {
      debugPrint('StorageService: Error uploading trip cover: $e');
      rethrow;
    }
  }
}
