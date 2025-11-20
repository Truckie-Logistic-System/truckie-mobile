import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/sound_utils.dart';
import '../../../core/utils/image_compressor.dart';
import '../../../domain/entities/order_with_details.dart';
import '../../../domain/entities/order_detail.dart';
import '../../../domain/entities/issue.dart';
import '../../../domain/repositories/issue_repository.dart';
import '../../../domain/repositories/photo_completion_repository.dart';
import '../../../app/di/service_locator.dart';
import '../../theme/app_colors.dart';

/// Combined modal for reporting damage and/or order rejection issues
/// Allows driver to report one or both issue types in a single submission
class CombinedIssueReportModal extends StatefulWidget {
  final OrderWithDetails order;
  final VehicleAssignment vehicleAssignment;
  final double? currentLatitude;
  final double? currentLongitude;
  final IssueRepository issueRepository;
  final Function({required bool shouldNavigateToCarrier}) onReported;

  const CombinedIssueReportModal({
    super.key,
    required this.order,
    required this.vehicleAssignment,
    this.currentLatitude,
    this.currentLongitude,
    required this.issueRepository,
    required this.onReported,
  });

  @override
  State<CombinedIssueReportModal> createState() =>
      _CombinedIssueReportModalState();
}

class _CombinedIssueReportModalState extends State<CombinedIssueReportModal> {
  bool _isDamageExpanded = false;
  bool _isRejectionExpanded = false;
  bool _isSubmitting = false;

  // Damage section state
  final Set<String> _selectedDamageIds = {};
  List<File> _damageImages = []; // Shared images for all damage packages
  String _damageDescription = ''; // Single description for all damage packages
  IssueType? _selectedDamageType;
  List<IssueType> _damageTypes = [];

  // Rejection section state
  final Set<String> _selectedRejectionIds = {};

  // Delivery confirmation section state (for successful packages)
  List<File> _deliveryConfirmationImages = [];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadDamageTypes();
  }

  Future<void> _loadDamageTypes() async {
    try {
      final types = await widget.issueRepository.getActiveIssueTypes();
      final damageTypes =
          types.where((type) => type.issueCategory.value == 'DAMAGE').toList();

      setState(() {
        _damageTypes = damageTypes;
        if (damageTypes.isNotEmpty) {
          _selectedDamageType = damageTypes.first;
        }
      });
    } catch (e) {
    }
  }

  /// Get packages that belong to current driver's trip
  List<OrderDetail> get _currentTripPackages {
    return widget.order.orderDetails
        .where((od) => od.vehicleAssignmentId == widget.vehicleAssignment.id)
        .toList();
  }

  /// Get successful packages (not reported in damage or rejection)
  List<OrderDetail> get _successfulPackages {
    final reportedIds = {..._selectedDamageIds, ..._selectedRejectionIds};
    return _currentTripPackages
        .where((pkg) => !reportedIds.contains(pkg.id))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final packages = _currentTripPackages;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          _buildHeader(),

          // Explanatory text
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bạn có thể chọn một hoặc cả hai loại sự cố cùng lúc',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                left: 16,
                right: 16,
                top: 8,
              ),
              child: Column(
                children: [
                  // Damage section
                  _buildDamageSection(packages),
                  const SizedBox(height: 12),

                  // Rejection section
                  _buildRejectionSection(packages),
                  const SizedBox(height: 12),

                  // Delivery confirmation section (for successful packages)
                  if (_successfulPackages.isNotEmpty)
                    _buildDeliveryConfirmationSection(),
                  const SizedBox(height: 24),

                  // Submit button
                  _buildSubmitButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Báo cáo sự cố',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDamageSection(List<OrderDetail> packages) {
    return Card(
      elevation: 2,
      child: ExpansionTile(
        title: Row(
          children: [
            Icon(
              Icons.broken_image_outlined,
              color: _isDamageExpanded ? Colors.red : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(
              _selectedDamageIds.isNotEmpty 
                  ? 'Đã chọn: ${_selectedDamageIds.length} kiện'
                  : 'Chọn kiện hàng hư hại',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _selectedDamageIds.isNotEmpty ? Colors.red : null,
                fontSize: _selectedDamageIds.isNotEmpty ? 14 : null,
              ),
            ),
          ],
        ),
        initiallyExpanded: _isDamageExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            _isDamageExpanded = expanded;
          });
        },
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Package list
                const Text(
                  'Chọn kiện hàng hư hại:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...packages.map((package) =>
                    _buildDamagePackageItem(package)),
                
                // Shared images and description for all damaged packages
                if (_selectedDamageIds.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  
                  // Image picker section
                  const Text(
                    'Ảnh hư hại:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  if (_damageImages.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đã chọn ${_damageImages.length} ảnh',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _damageImages.length + 1,
                            itemBuilder: (context, index) {
                              if (index == _damageImages.length) {
                                return GestureDetector(
                                  onTap: _pickSharedDamageImages,
                                  child: Container(
                                    width: 100,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey[300]!, width: 2),
                                    ),
                                    child: Center(
                                      child: Icon(Icons.add_a_photo, size: 32, color: Colors.grey[400]),
                                    ),
                                  ),
                                );
                              }
                              
                              return Stack(
                                children: [
                                  Container(
                                    width: 100,
                                    height: 100,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      image: DecorationImage(
                                        image: FileImage(_damageImages[index]),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 12,
                                    child: GestureDetector(
                                      onTap: () => _removeSharedDamageImage(index),
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
                            },
                          ),
                        ),
                      ],
                    )
                  else
                    GestureDetector(
                      onTap: _pickSharedDamageImages,
                      child: Container(
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200, width: 2),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, size: 40, color: Colors.red.shade300),
                            const SizedBox(height: 8),
                            Text(
                              'Chụp ảnh hư hại',
                              style: TextStyle(fontSize: 14, color: Colors.red.shade700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // Description field
                  const Text(
                    'Mô tả tình trạng hư hại:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Mô tả chi tiết tình trạng hư hại của hàng hóa...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                      filled: true,
                      fillColor: Colors.red.shade50,
                    ),
                    maxLines: 3,
                    onChanged: (value) {
                      _damageDescription = value;
                    },
                    controller: TextEditingController(text: _damageDescription)
                      ..selection = TextSelection.fromPosition(
                        TextPosition(offset: _damageDescription.length),
                      ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDamagePackageItem(OrderDetail package) {
    final isSelected = _selectedDamageIds.contains(package.id);
    
    // VALIDATE: Disable nếu đã chọn ở rejection section
    final isDisabled = _selectedRejectionIds.contains(package.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected 
            ? Colors.red.shade400 
            : isDisabled 
              ? Colors.grey.shade300 
              : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
        color: isSelected 
          ? Colors.red.shade50 
          : isDisabled 
            ? Colors.grey.shade100 
            : Colors.white,
        boxShadow: isSelected ? [
          BoxShadow(
            color: Colors.red.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: Column(
        children: [
          CheckboxListTile(
            value: isSelected,
            enabled: !isDisabled, // Disable nếu đã chọn ở section khác
            onChanged: isDisabled ? null : (value) {
              setState(() {
                if (value == true) {
                  _selectedDamageIds.add(package.id);
                } else {
                  _selectedDamageIds.remove(package.id);
                }
              });
            },
            title: Row(
              children: [
                Flexible(
                  child: Tooltip(
                    message: package.trackingCode,
                    preferBelow: false,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.red.shade100 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        package.trackingCode,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: isSelected ? Colors.red.shade900 : Colors.grey.shade700,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),
                if (isDisabled) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock, size: 12, color: Colors.orange.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Trả',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          package.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.scale_outlined, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        '${package.weightBaseUnit ?? 0} ${package.unit}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            activeColor: Colors.red.shade700,
          ),
        ],
      ),
    );
  }

  Widget _buildRejectionSection(List<OrderDetail> packages) {
    return Card(
      elevation: 2,
      child: ExpansionTile(
        title: Row(
          children: [
            Icon(
              Icons.cancel_outlined,
              color: _isRejectionExpanded ? Colors.orange : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(
              _selectedRejectionIds.isNotEmpty 
                  ? 'Đã chọn: ${_selectedRejectionIds.length} kiện'
                  : 'Chọn kiện hàng bị trả',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _selectedRejectionIds.isNotEmpty ? Colors.orange : null,
                fontSize: _selectedRejectionIds.isNotEmpty ? 14 : null,
              ),
            ),
          ],
        ),
        initiallyExpanded: _isRejectionExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            _isRejectionExpanded = expanded;
          });
        },
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chọn kiện hàng bị người nhận từ chối:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...packages.map((package) =>
                    _buildRejectionPackageItem(package)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryConfirmationSection() {
    final successfulCount = _successfulPackages.length;
    final hasIssues = _selectedDamageIds.isNotEmpty || _selectedRejectionIds.isNotEmpty;
    
    return Card(
      elevation: 2,
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Colors.green.shade700,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Xác nhận giao hàng ($successfulCount kiện)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green.shade900,
                        ),
                      ),
                      if (hasIssues)
                        Text(
                          'Chụp ảnh xác nhận giao hàng cho các kiện không có vấn đề',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Info banner
            if (hasIssues)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Vui lòng chụp ảnh xác nhận giao hàng cho các kiện còn lại',
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 12),
            
            // Package list
            ...(_successfulPackages.asMap().entries.map((entry) {
              final index = entry.key;
              final pkg = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Kiện #${index + 1} - ${pkg.description}',
                        style: TextStyle(fontSize: 13, color: Colors.green.shade900),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            })),
            
            const SizedBox(height: 12),
            
            // Image picker
            const Text(
              'Ảnh xác nhận giao hàng *',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            
            if (_deliveryConfirmationImages.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Đã chọn ${_deliveryConfirmationImages.length} ảnh',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _deliveryConfirmationImages.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _deliveryConfirmationImages.length) {
                          return GestureDetector(
                            onTap: _pickDeliveryConfirmationImages,
                            child: Container(
                              width: 100,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!, width: 2),
                              ),
                              child: Center(
                                child: Icon(Icons.add_a_photo, size: 32, color: Colors.grey[400]),
                              ),
                            ),
                          );
                        }
                        
                        return Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: FileImage(_deliveryConfirmationImages[index]),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 12,
                              child: GestureDetector(
                                onTap: () => _removeDeliveryConfirmationImage(index),
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
                      },
                    ),
                  ),
                ],
              )
            else
              GestureDetector(
                onTap: _pickDeliveryConfirmationImages,
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!, width: 2),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo, size: 40, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'Chụp ảnh',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectionPackageItem(OrderDetail package) {
    final isSelected = _selectedRejectionIds.contains(package.id);
    
    // VALIDATE: Disable nếu đã chọn ở damage section
    final isDisabled = _selectedDamageIds.contains(package.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected 
            ? Colors.orange.shade400 
            : isDisabled 
              ? Colors.grey.shade300 
              : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
        color: isSelected 
          ? Colors.orange.shade50 
          : isDisabled 
            ? Colors.grey.shade100 
            : Colors.white,
        boxShadow: isSelected ? [
          BoxShadow(
            color: Colors.orange.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: CheckboxListTile(
        value: isSelected,
        enabled: !isDisabled, // Disable nếu đã chọn ở section khác
        onChanged: isDisabled ? null : (value) {
          setState(() {
            if (value == true) {
              _selectedRejectionIds.add(package.id);
            } else {
              _selectedRejectionIds.remove(package.id);
            }
          });
        },
        title: Row(
          children: [
            Flexible(
              child: Tooltip(
                message: package.trackingCode,
                preferBelow: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.orange.shade100 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    package.trackingCode,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isSelected ? Colors.orange.shade900 : Colors.grey.shade700,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            ),
            if (isDisabled) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, size: 12, color: Colors.red.shade700),
                    const SizedBox(width: 4),
                    Text(
                      'Hư',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      package.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.scale_outlined, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${package.weightBaseUnit ?? 0} ${package.unit}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        activeColor: Colors.red.shade700,
      ),
    );
  }

  Widget _buildSubmitButton() {
    final hasSelection =
        _selectedDamageIds.isNotEmpty || _selectedRejectionIds.isNotEmpty;
    final canSubmit = hasSelection && !_isSubmitting;

    // Validate damage packages have images (shared)
    final hasDamageIssues = _selectedDamageIds.isNotEmpty;
    final hasDamageImages = _damageImages.isNotEmpty;

    // Validate delivery confirmation photos if there are successful packages
    final needsDeliveryConfirmation = _successfulPackages.isNotEmpty;
    final hasDeliveryConfirmationPhotos = _deliveryConfirmationImages.isNotEmpty;

    String buttonText;
    if (!hasSelection) {
      buttonText = 'Chọn ít nhất 1 kiện hàng';
    } else if (_isSubmitting) {
      buttonText = 'Đang gửi báo cáo...';
    } else if (hasDamageIssues && !hasDamageImages) {
      buttonText = 'Vui lòng thêm ảnh hư hại';
    } else if (needsDeliveryConfirmation && !hasDeliveryConfirmationPhotos) {
      buttonText = 'Vui lòng thêm ảnh xác nhận giao hàng';
    } else {
      int totalCount = _selectedDamageIds.length + _selectedRejectionIds.length;
      buttonText = 'Xác nhận ($totalCount kiện)';
    }

    final bool isValid = canSubmit && 
        (!hasDamageIssues || hasDamageImages) && 
        (!needsDeliveryConfirmation || hasDeliveryConfirmationPhotos);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isValid ? _handleSubmit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: Colors.grey[300],
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                buttonText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _isSubmitting = true;
    });

    bool damageSuccess = false;
    bool rejectionSuccess = false;
    String? errorMessage;

    try {
      // Submit damage reports
      if (_selectedDamageIds.isNotEmpty) {
        try {
          await _submitDamageReports();
          damageSuccess = true;
        } catch (e) {
          errorMessage = 'Lỗi báo cáo hư hại: ${e.toString()}';
          throw e;
        }
      }

      // Submit rejection report
      if (_selectedRejectionIds.isNotEmpty) {
        try {
          await _submitRejectionReport();
          rejectionSuccess = true;
        } catch (e) {
          errorMessage = 'Lỗi báo cáo trả hàng: ${e.toString()}';
          throw e;
        }
      }

      // Upload delivery confirmation photos if any
      bool deliverySuccess = false;
      if (_deliveryConfirmationImages.isNotEmpty) {
        try {
          await _uploadDeliveryConfirmationPhotos();
          deliverySuccess = true;
        } catch (e) {
          errorMessage = 'Lỗi upload ảnh giao hàng: ${e.toString()}';
          throw e;
        }
      }

      if (mounted) {
        // Play success sound
        SoundUtils.playSuccessSound();

        // Show success message with details
        List<String> successParts = [];
        if (damageSuccess) successParts.add('${_selectedDamageIds.length} hư hại');
        if (rejectionSuccess) successParts.add('${_selectedRejectionIds.length} trả hàng');
        if (deliverySuccess) successParts.add('${_successfulPackages.length} giao thành công');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Đã hoàn thành: ${successParts.join(', ')}'),
            backgroundColor: Colors.green,
          ),
        );

        // Close modal
        Navigator.pop(context);

        // Navigation logic:
        // - Only damage → Navigate to carrier (navigation screen)
        // - Only rejection OR combined → Stay on order detail screen
        final bool onlyDamage = damageSuccess && !rejectionSuccess;
        
        // Trigger callback with navigation flag
        widget.onReported(shouldNavigateToCarrier: onlyDamage);
      }
    } catch (e) {
      if (mounted) {
        // Play error sound
        SoundUtils.playErrorSound();

        // Show detailed error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('❌ ${errorMessage ?? 'Lỗi không xác định'}'),
                if (damageSuccess || rejectionSuccess) ...[
                  const SizedBox(height: 4),
                  Text(
                    '✅ Đã báo cáo: ${damageSuccess ? '${_selectedDamageIds.length} hư hại' : ''}${damageSuccess && rejectionSuccess ? ', ' : ''}${rejectionSuccess ? '${_selectedRejectionIds.length} trả hàng' : ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 7),
          ),
        );

        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _submitDamageReports() async {
    if (_selectedDamageType == null) {
      throw Exception('Vui lòng chọn loại sự cố hư hại');
    }

    if (_damageImages.isEmpty) {
      throw Exception('Vui lòng thêm ảnh hư hại');
    }

    // Use single description for all damaged packages
    final description = _damageDescription.trim().isEmpty 
        ? 'Hàng bị hư hại' 
        : _damageDescription.trim();

    // Compress shared images once
    final compressedPaths = <String>[];
    for (final image in _damageImages) {
      final compressed = await ImageCompressor.compressImage(file: image);
      if (compressed != null) {
        compressedPaths.add(compressed.path);
      }
    }

    // Report damage for each selected package with same images and description
    for (final packageId in _selectedDamageIds) {
      await widget.issueRepository.reportDamageIssue(
        vehicleAssignmentId: widget.vehicleAssignment.id,
        issueTypeId: _selectedDamageType!.id,
        orderDetailId: packageId,
        description: description,
        damageImagePaths: compressedPaths, // Same images for all packages
        locationLatitude: widget.currentLatitude,
        locationLongitude: widget.currentLongitude,
      );
    }
  }

  Future<void> _submitRejectionReport() async {
    await widget.issueRepository.reportOrderRejection(
      vehicleAssignmentId: widget.vehicleAssignment.id,
      orderDetailIds: _selectedRejectionIds.toList(),
      locationLatitude: widget.currentLatitude,
      locationLongitude: widget.currentLongitude,
    );
  }

  Future<void> _pickSharedDamageImages() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Chụp ảnh'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 80,
                );
                if (image != null) {
                  setState(() {
                    _damageImages.add(File(image.path));
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Chọn từ thư viện'),
              onTap: () async {
                Navigator.pop(context);
                final List<XFile> images = await _picker.pickMultiImage(
                  imageQuality: 80,
                );
                if (images.isNotEmpty) {
                  setState(() {
                    _damageImages.addAll(
                      images.map((xfile) => File(xfile.path)),
                    );
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _removeSharedDamageImage(int index) {
    setState(() {
      _damageImages.removeAt(index);
    });
  }

  Future<void> _pickDeliveryConfirmationImages() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Chụp ảnh'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 80,
                );
                if (image != null) {
                  setState(() {
                    _deliveryConfirmationImages.add(File(image.path));
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Chọn từ thư viện'),
              onTap: () async {
                Navigator.pop(context);
                final List<XFile> images = await _picker.pickMultiImage(
                  imageQuality: 80,
                );
                if (images.isNotEmpty) {
                  setState(() {
                    _deliveryConfirmationImages.addAll(
                      images.map((xfile) => File(xfile.path)),
                    );
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _removeDeliveryConfirmationImage(int index) {
    setState(() {
      _deliveryConfirmationImages.removeAt(index);
    });
  }

  Future<void> _uploadDeliveryConfirmationPhotos() async {
    if (_deliveryConfirmationImages.isEmpty) return;

    // Compress images before upload
    final compressedImages = <File>[];
    for (final image in _deliveryConfirmationImages) {
      final compressed = await ImageCompressor.compressImage(file: image);
      if (compressed != null) {
        compressedImages.add(compressed);
      } else {
        compressedImages.add(image); // Use original if compression fails
      }
    }

    // Upload via PhotoCompletionRepository
    final photoCompletionRepository = getIt<PhotoCompletionRepository>();
    await photoCompletionRepository.uploadMultiplePhotoCompletion(
      vehicleAssignmentId: widget.vehicleAssignment.id,
      imageFiles: compressedImages,
      description: 'Xác nhận giao hàng thành công cho ${_successfulPackages.length} kiện',
    );
  }
}
