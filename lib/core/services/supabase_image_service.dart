import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class SupabaseImageService {
  static final _supabase = Supabase.instance.client;
  static const String _bucketName = 'drugs';

  /// Initialize the image service and create bucket if it doesn't exist
  static Future<void> initialize() async {
    try {
      // Check if bucket exists, if not create it
      final buckets = await _supabase.storage.listBuckets();
      final bucketExists = buckets.any((bucket) => bucket.name == _bucketName);

      if (!bucketExists) {
        try {
          await _supabase.storage.createBucket(
            _bucketName,
            const BucketOptions(
              public: true,
              allowedMimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
              fileSizeLimit: '5MB',
            ),
          );
          print('Created $_bucketName bucket successfully');
        } catch (bucketError) {
          print('Could not create bucket (this is normal if RLS is enabled): $bucketError');
          print('Please create the "$_bucketName" bucket manually in your Supabase dashboard');

          // Try to test if bucket exists by attempting to list files
          try {
            await _supabase.storage.from(_bucketName).list();
            print('$_bucketName bucket exists and is accessible');
          } catch (testError) {
            print('Warning: Cannot access $_bucketName bucket. Please ensure it exists in Supabase dashboard');
          }
        }
      } else {
        print('$_bucketName bucket already exists');
      }
    } catch (e) {
      print('Error during Supabase image service initialization: $e');
      print('Note: Service will continue to work if bucket exists manually');
    }
  }

  /// Pick image from gallery or camera
  static Future<XFile?> pickImage({
    required ImageSource source,
    int imageQuality = 80,
  }) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: imageQuality,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      return image;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  /// Upload image to Supabase bucket
  static Future<String?> uploadImage({
    required XFile imageFile,
    required String drugId,
    String? existingImageUrl,
  }) async {
    try {
      print('Starting image upload for drug: $drugId');

      // Delete existing image if provided
      if (existingImageUrl != null && existingImageUrl.isNotEmpty) {
        print('Deleting existing image: $existingImageUrl');
        await deleteImage(existingImageUrl);
      }

      // Generate unique filename
      final String fileExtension = path.extension(imageFile.name).toLowerCase();
      final String fileName = fileExtension.isEmpty
          ? '${drugId}_${DateTime.now().millisecondsSinceEpoch}.jpg'
          : '${drugId}_${DateTime.now().millisecondsSinceEpoch}$fileExtension';

      // Read file as bytes
      final Uint8List imageBytes = await imageFile.readAsBytes();
      print('Image size: ${imageBytes.length} bytes');

      // Upload to Supabase (no subfolder since bucket name is 'drugs')
      final uploadResponse = await _supabase.storage
          .from(_bucketName)
          .uploadBinary(fileName, imageBytes,
              fileOptions: const FileOptions(
                upsert: true,
                contentType: 'image/jpeg',
              ));

      print('Upload response: $uploadResponse');

      // Get public URL
      final String publicUrl = _supabase.storage
          .from(_bucketName)
          .getPublicUrl(fileName);

      print('Image uploaded successfully: $publicUrl');
      return publicUrl;

    } catch (e) {
      print('Error uploading image: $e');
      print('Error type: ${e.runtimeType}');
      return null;
    }
  }

  /// Upload image from file path
  static Future<String?> uploadImageFromPath({
    required String imagePath,
    required String drugId,
    String? existingImageUrl,
  }) async {
    try {
      final File imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        print('Image file does not exist: $imagePath');
        return null;
      }

      // Delete existing image if provided
      if (existingImageUrl != null && existingImageUrl.isNotEmpty) {
        await deleteImage(existingImageUrl);
      }

      // Generate unique filename
      final String fileExtension = path.extension(imagePath).toLowerCase();
      final String fileName = fileExtension.isEmpty
          ? '${drugId}_${DateTime.now().millisecondsSinceEpoch}.jpg'
          : '${drugId}_${DateTime.now().millisecondsSinceEpoch}$fileExtension';

      // Read file as bytes
      final Uint8List imageBytes = await imageFile.readAsBytes();

      // Upload to Supabase
      await _supabase.storage
          .from(_bucketName)
          .uploadBinary(fileName, imageBytes,
              fileOptions: const FileOptions(
                upsert: true,
                contentType: 'image/jpeg',
              ));

      // Get public URL
      final String publicUrl = _supabase.storage
          .from(_bucketName)
          .getPublicUrl(fileName);

      print('Image uploaded successfully: $publicUrl');
      return publicUrl;

    } catch (e) {
      print('Error uploading image from path: $e');
      return null;
    }
  }

  /// Delete image from Supabase bucket
  static Future<bool> deleteImage(String imageUrl) async {
    try {
      // Extract file path from URL
      final String filePath = _extractFilePathFromUrl(imageUrl);

      if (filePath.isEmpty) {
        print('Invalid image URL: $imageUrl');
        return false;
      }

      await _supabase.storage
          .from(_bucketName)
          .remove([filePath]);

      print('Image deleted successfully: $filePath');
      return true;

    } catch (e) {
      print('Error deleting image: $e');
      return false;
    }
  }

  /// Extract file path from Supabase public URL
  static String _extractFilePathFromUrl(String url) {
    try {
      final Uri uri = Uri.parse(url);
      final String path = uri.path;

      // Remove the bucket path prefix
      final String bucketPrefix = '/storage/v1/object/public/$_bucketName/';
      if (path.startsWith(bucketPrefix)) {
        return path.substring(bucketPrefix.length);
      }

      // Alternative format check
      final List<String> pathSegments = uri.pathSegments;
      if (pathSegments.length >= 5 && pathSegments[4] == _bucketName) {
        return pathSegments.skip(5).join('/');
      }

      return '';
    } catch (e) {
      print('Error extracting file path from URL: $e');
      return '';
    }
  }

  /// Show image picker dialog with fixed navigation
  static Future<XFile?> showImagePickerDialog(BuildContext context) async {
    XFile? selectedImage;

    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Select Image Source'),
          content: const Text('Choose how you want to add an image:'),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.photo_library),
              label: const Text('Gallery'),
              onPressed: () async {
                Navigator.of(dialogContext).pop(true);
                selectedImage = await pickImage(source: ImageSource.gallery);
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('Camera'),
              onPressed: () async {
                Navigator.of(dialogContext).pop(true);
                selectedImage = await pickImage(source: ImageSource.camera);
              },
            ),
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
          ],
        );
      },
    );

    return selectedImage;
  }

  /// Get optimized image URL with transformations
  static String getOptimizedImageUrl(String originalUrl, {
    int? width,
    int? height,
    int quality = 80,
  }) {
    try {
      final Uri uri = Uri.parse(originalUrl);
      final Map<String, String> queryParams = Map.from(uri.queryParameters);

      if (width != null) queryParams['width'] = width.toString();
      if (height != null) queryParams['height'] = height.toString();
      queryParams['quality'] = quality.toString();

      return uri.replace(queryParameters: queryParams).toString();
    } catch (e) {
      print('Error creating optimized URL: $e');
      return originalUrl;
    }
  }

  /// Check if image URL is valid
  static bool isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;

    try {
      final Uri uri = Uri.parse(url);
      return uri.isAbsolute && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Get cached network image widget
  static Widget buildNetworkImage({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    if (!isValidImageUrl(imageUrl)) {
      return errorWidget ?? const Icon(Icons.error);
    }

    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;

        return placeholder ?? Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        print('Error loading image: $error');
        return errorWidget ?? Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.broken_image,
            color: Colors.grey,
            size: 32,
          ),
        );
      },
    );
  }
}
