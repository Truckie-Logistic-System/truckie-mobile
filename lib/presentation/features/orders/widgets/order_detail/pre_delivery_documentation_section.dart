import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../../core/services/service_locator.dart';
import '../../../../../domain/entities/order_with_details.dart';
import '../../../../../presentation/theme/app_colors.dart';
import '../../viewmodels/pre_delivery_documentation_viewmodel.dart';

class PreDeliveryDocumentationSection extends StatefulWidget {
  final OrderWithDetails order;
  final VoidCallback? onSubmitSuccess;

  const PreDeliveryDocumentationSection({
    Key? key,
    required this.order,
    this.onSubmitSuccess,
  }) : super(key: key);

  @override
  State<PreDeliveryDocumentationSection> createState() =>
      _PreDeliveryDocumentationSectionState();
}

class _PreDeliveryDocumentationSectionState
    extends State<PreDeliveryDocumentationSection> {
  late final PreDeliveryDocumentationViewModel _viewModel;
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _viewModel = getIt<PreDeliveryDocumentationViewModel>();
  }

  Future<void> _pickPackingProofImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (image != null) {
        _viewModel.addPackingProofImage(File(image.path));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
    }
  }

  Future<void> _pickSealImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (image != null) {
        _viewModel.setSealImage(File(image.path));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
    }
  }

  void _showImageSourceOptions(bool isPackingProof) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Chụp ảnh mới'),
                onTap: () {
                  Navigator.pop(context);
                  if (isPackingProof) {
                    _pickPackingProofImage(ImageSource.camera);
                  } else {
                    _pickSealImage(ImageSource.camera);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Chọn từ thư viện'),
                onTap: () {
                  Navigator.pop(context);
                  if (isPackingProof) {
                    _pickPackingProofImage(ImageSource.gallery);
                  } else {
                    _pickSealImage(ImageSource.gallery);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String? _getVehicleAssignmentId() {
    if (widget.order.orderDetails.isEmpty) {
      return null;
    }
    final orderDetail = widget.order.orderDetails.first;
    if (orderDetail.vehicleAssignment == null) {
      return null;
    }
    return orderDetail.vehicleAssignment!.id;
  }

  Future<void> _submitDocumentation() async {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();

      final vehicleAssignmentId = _getVehicleAssignmentId();
      if (vehicleAssignmentId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm thấy thông tin phương tiện')),
        );
        return;
      }

      final result = await _viewModel.submitPreDeliveryDocumentation(
        vehicleAssignmentId: vehicleAssignmentId,
      );

      if (result && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Xác nhận hàng hóa thành công'),
            backgroundColor: Colors.green,
          ),
        );

        // Call the success callback if provided, otherwise pop the context
        if (widget.onSubmitSuccess != null) {
          widget.onSubmitSuccess!();
        } else {
          Navigator.of(context).pop(true); // Return success to previous screen
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<PreDeliveryDocumentationViewModel>(
        builder: (context, viewModel, _) {
          return Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Xác nhận hàng hóa và seal',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Mã seal',
                    hintText: 'Nhập mã seal',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập mã seal';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    if (value != null) {
                      viewModel.setSealCode(value);
                    }
                  },
                ),
                const SizedBox(height: 24),
                _buildPackingProofImagesSection(viewModel),
                const SizedBox(height: 24),
                _buildSealImageSection(viewModel),
                const SizedBox(height: 24),
                if (viewModel.state == PreDeliveryDocumentationState.error)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      viewModel.errorMessage,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        viewModel.state == PreDeliveryDocumentationState.loading
                        ? null
                        : _submitDocumentation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child:
                        viewModel.state == PreDeliveryDocumentationState.loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Xác nhận hàng hóa và seal'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPackingProofImagesSection(
    PreDeliveryDocumentationViewModel viewModel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Hình ảnh hàng hóa',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            if (viewModel.packingProofImages.isEmpty &&
                viewModel.sealImage == null)
              const Text(
                '(Bắt buộc)',
                style: TextStyle(fontSize: 12, color: Colors.red),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 120,
          decoration: BoxDecoration(
            border: Border.all(
              color:
                  viewModel.packingProofImages.isEmpty &&
                      viewModel.sealImage == null
                  ? Colors.red.shade300
                  : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: viewModel.packingProofImages.length + 1,
            itemBuilder: (context, index) {
              if (index == viewModel.packingProofImages.length) {
                return _buildAddImageButton(
                  () => _showImageSourceOptions(true),
                );
              }
              return _buildImageThumbnail(
                viewModel.packingProofImages[index],
                () => viewModel.removePackingProofImage(index),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSealImageSection(PreDeliveryDocumentationViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Hình ảnh seal',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            if (viewModel.packingProofImages.isEmpty &&
                viewModel.sealImage == null)
              const Text(
                '(Bắt buộc)',
                style: TextStyle(fontSize: 12, color: Colors.red),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 120,
          decoration: BoxDecoration(
            border: Border.all(
              color:
                  viewModel.packingProofImages.isEmpty &&
                      viewModel.sealImage == null
                  ? Colors.red.shade300
                  : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: viewModel.sealImage == null
              ? _buildAddImageButton(() => _showImageSourceOptions(false))
              : _buildImageThumbnail(
                  viewModel.sealImage!,
                  () => viewModel.clearSealImage(), // Clear just the seal image
                ),
        ),
      ],
    );
  }

  Widget _buildAddImageButton(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 100,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade400, width: 1),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate, size: 32, color: AppColors.primary),
            SizedBox(height: 8),
            Text('Thêm ảnh', style: TextStyle(color: AppColors.primary)),
          ],
        ),
      ),
    );
  }

  Widget _buildImageThumbnail(File image, VoidCallback onRemove) {
    return Stack(
      children: [
        Container(
          width: 100,
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(image: FileImage(image), fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: InkWell(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
