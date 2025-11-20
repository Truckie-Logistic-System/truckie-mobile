import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:capstone_mobile/domain/repositories/issue_repository.dart';
import 'package:get_it/get_it.dart';

/// Dialog for driver to confirm return delivery at pickup point
/// Follows MVVM pattern - Widget handles UI only, repository handles business logic
class ReturnConfirmationDialog extends StatefulWidget {
  final String issueId;
  final VoidCallback onConfirmed;

  const ReturnConfirmationDialog({
    Key? key,
    required this.issueId,
    required this.onConfirmed,
  }) : super(key: key);

  @override
  State<ReturnConfirmationDialog> createState() => _ReturnConfirmationDialogState();
}

class _ReturnConfirmationDialogState extends State<ReturnConfirmationDialog> {
  final List<File> _photos = [];
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  final int _maxPhotos = 5;
  
  final IssueRepository _issueRepository = GetIt.I<IssueRepository>();

  /// Capture photo from camera
  Future<void> _capturePhoto() async {
    if (_photos.length >= _maxPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tối đa $_maxPhotos ảnh')),
      );
      return;
    }

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );

      if (photo != null) {
        setState(() {
          _photos.add(File(photo.path));
        });
      }
    } catch (e) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể chụp ảnh')),
      );
    }
  }

  /// Remove photo from list
  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
    });
  }

  /// Upload photos and confirm return delivery
  Future<void> _confirmReturn() async {
    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chụp ít nhất 1 ảnh')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Confirm return delivery with photos (files)
      await _issueRepository.confirmReturnDelivery(
        issueId: widget.issueId,
        returnDeliveryImages: _photos, // Pass File objects directly
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Đã xác nhận trả hàng thành công'),
          backgroundColor: Colors.green,
        ),
      );

      // Close dialog and trigger callback
      Navigator.of(context).pop();
      widget.onConfirmed();
    } catch (e) {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.assignment_return,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Xác nhận trả hàng về đơn vị vận chuyển',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!_isLoading)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),

            // Instructions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Chụp ảnh xác nhận đã trả hàng về đơn vị vận chuyển tại điểm lấy hàng',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Photo grid
            if (_photos.isNotEmpty)
              Container(
                height: 120,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photos.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: FileImage(_photos[index]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 12,
                          child: GestureDetector(
                            onTap: () => _removePhoto(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

            // Add photo button
            if (_photos.length < _maxPhotos)
              Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _capturePhoto,
                  icon: const Icon(Icons.camera_alt),
                  label: Text('Chụp ảnh (${_photos.length}/$_maxPhotos)'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

            // Empty state
            if (_photos.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      Icons.photo_camera,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Chưa có ảnh nào',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      child: const Text('Hủy'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading || _photos.isEmpty ? null : _confirmReturn,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Xác nhận'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: Theme.of(context).primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
