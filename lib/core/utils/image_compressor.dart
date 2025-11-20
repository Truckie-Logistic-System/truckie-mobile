import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';

/// Utility for compressing images before upload to reduce bandwidth and storage
/// Uses Flutter's built-in image codec for compression
class ImageCompressor {
  /// Compress an image file to reduce size
  /// 
  /// Parameters:
  /// - file: Input image file
  /// - quality: Compression quality (0-100, default 85)
  /// - maxWidth: Maximum width in pixels (default 1920)
  /// - maxHeight: Maximum height in pixels (default 1080)
  /// 
  /// Returns: Compressed image file or null if compression fails
  static Future<File?> compressImage({
    required File file,
    int quality = 85,
    int maxWidth = 1920,
    int maxHeight = 1080,
  }) async {
    try {
      // Get original file size
      final originalSize = await file.length();
      
      
      // If file is already small enough, return original
      if (originalSize < 500 * 1024) { // 500 KB
        return file;
      }
      
      // Read file bytes
      final bytes = await file.readAsBytes();
      
      // Decode image
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: maxWidth,
        targetHeight: maxHeight,
      );
      
      final frame = await codec.getNextFrame();
      final image = frame.image;
      // Convert to bytes with compression
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      
      if (byteData == null) {
        return file; // Return original if compression fails
      }
      
      // Write compressed image to temp file
      final tempDir = Directory.systemTemp;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempPath = '${tempDir.path}/compressed_$timestamp.jpg';
      final compressedFile = File(tempPath);
      
      await compressedFile.writeAsBytes(
        byteData.buffer.asUint8List(),
        flush: true,
      );
      
      // Get compressed size
      final compressedSize = await compressedFile.length();
      final compressionRatio = ((1 - compressedSize / originalSize) * 100).toStringAsFixed(1);
      
      // Clean up
      image.dispose();
      codec.dispose();
      
      return compressedFile;
    } catch (e, stackTrace) {
      return file; // Return original file if compression fails
    }
  }
  
  /// Compress multiple images in parallel
  static Future<List<File?>> compressMultiple({
    required List<File> files,
    int quality = 85,
    int maxWidth = 1920,
    int maxHeight = 1080,
  }) async {
    final futures = files.map((file) => compressImage(
      file: file,
      quality: quality,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    ));
    
    final results = await Future.wait(futures);
    
    final successCount = results.where((r) => r != null).length;
    return results;
  }
  
  /// Compress XFile (from image_picker) directly
  static Future<File?> compressXFile({
    required XFile xfile,
    int quality = 85,
    int maxWidth = 1920,
    int maxHeight = 1080,
  }) async {
    final file = File(xfile.path);
    return compressImage(
      file: file,
      quality: quality,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
  }
  
  /// Get image dimensions without loading full image
  static Future<Size?> getImageDimensions(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      
      final size = Size(image.width.toDouble(), image.height.toDouble());
      
      image.dispose();
      codec.dispose();
      
      return size;
    } catch (e) {
      return null;
    }
  }
  
  /// Check if image needs compression based on size
  static Future<bool> needsCompression(File file, {int maxSizeKB = 500}) async {
    try {
      final size = await file.length();
      return size > (maxSizeKB * 1024);
    } catch (e) {
      return false;
    }
  }
  
  /// Get file size in human-readable format
  static Future<String> getFileSizeString(File file) async {
    try {
      final bytes = await file.length();
      if (bytes < 1024) {
        return '${bytes} B';
      } else if (bytes < 1024 * 1024) {
        return '${(bytes / 1024).toStringAsFixed(1)} KB';
      } else {
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}

/// Size class for image dimensions
class Size {
  final double width;
  final double height;
  
  const Size(this.width, this.height);
  
  @override
  String toString() => '${width.toInt()}x${height.toInt()}';
}
