import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../../core/services/service_locator.dart';
import '../../../../../core/utils/responsive_extensions.dart';
import '../../../../../domain/entities/driver.dart';
import '../../../../../presentation/theme/app_colors.dart';
import '../../../auth/viewmodels/auth_viewmodel.dart';
import '../../viewmodels/account_viewmodel.dart';
import 'date_picker_utils.dart';
import 'driver_info_date_field.dart';
import 'driver_info_form_field.dart';

/// Widget form chỉnh sửa thông tin tài xế
class DriverInfoForm extends StatefulWidget {
  final Driver driver;
  final GlobalKey<FormState> formKey;
  final Function(bool) onUpdateComplete;

  const DriverInfoForm({
    Key? key,
    required this.driver,
    required this.formKey,
    required this.onUpdateComplete,
  }) : super(key: key);

  @override
  State<DriverInfoForm> createState() => _DriverInfoFormState();
}

class _DriverInfoFormState extends State<DriverInfoForm> {
  final _identityNumberController = TextEditingController();
  final _driverLicenseNumberController = TextEditingController();
  final _cardSerialNumberController = TextEditingController();
  final _placeOfIssueController = TextEditingController();
  final _licenseClassController = TextEditingController();

  DateTime _dateOfIssue = DateTime.now();
  DateTime _dateOfExpiry = DateTime.now().add(const Duration(days: 365 * 5));
  DateTime _dateOfPassing = DateTime.now();

  bool _isLoading = false;

  // Use the singleton instances from GetIt
  late final AuthViewModel _authViewModel;
  late final AccountViewModel _accountViewModel;

  @override
  void initState() {
    super.initState();
    _initializeFormValues();
    _authViewModel = getIt<AuthViewModel>();
    _accountViewModel = getIt<AccountViewModel>();
  }

  void _initializeFormValues() {
    final driver = widget.driver;

    _identityNumberController.text = driver.identityNumber;
    _driverLicenseNumberController.text = driver.driverLicenseNumber;
    _cardSerialNumberController.text = driver.cardSerialNumber;
    _placeOfIssueController.text = driver.placeOfIssue;
    _licenseClassController.text = driver.licenseClass;

    _dateOfIssue = driver.dateOfIssue;
    _dateOfExpiry = driver.dateOfExpiry;
    _dateOfPassing = driver.dateOfPassing;
  }

  @override
  void dispose() {
    _identityNumberController.dispose();
    _driverLicenseNumberController.dispose();
    _cardSerialNumberController.dispose();
    _placeOfIssueController.dispose();
    _licenseClassController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPersonalInfoSection(),
          SizedBox(height: 24.h),
          _buildLicenseInfoSection(),
          SizedBox(height: 32.h),
          _buildSubmitButton(),
          if (_accountViewModel.status == AccountStatus.updateError) ...[
            SizedBox(height: 16.h),
            Text(
              _accountViewModel.errorMessage,
              style: TextStyle(color: AppColors.error, fontSize: 14.sp),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  /// Xây dựng phần thông tin cá nhân
  Widget _buildPersonalInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thông tin cá nhân',
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16.h),
        DriverInfoFormField(
          controller: _identityNumberController,
          label: 'Số CMND/CCCD',
          icon: Icons.badge,
          keyboardType: TextInputType.number,
          maxLength: 12,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Vui lòng nhập số CMND/CCCD';
            }
            return null;
          },
        ),
        SizedBox(height: 16.h),
        DriverInfoFormField(
          controller: _placeOfIssueController,
          label: 'Nơi cấp',
          icon: Icons.location_city,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Vui lòng nhập nơi cấp';
            }
            return null;
          },
        ),
      ],
    );
  }

  /// Xây dựng phần thông tin giấy phép
  Widget _buildLicenseInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thông tin giấy phép lái xe',
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16.h),
        DriverInfoFormField(
          controller: _driverLicenseNumberController,
          label: 'Số GPLX',
          icon: Icons.credit_card,
          keyboardType: TextInputType.text,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Vui lòng nhập số GPLX';
            }
            return null;
          },
        ),
        SizedBox(height: 16.h),
        DriverInfoFormField(
          controller: _cardSerialNumberController,
          label: 'Số thẻ',
          icon: Icons.credit_card,
          keyboardType: TextInputType.text,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Vui lòng nhập số thẻ';
            }
            return null;
          },
        ),
        SizedBox(height: 16.h),
        DriverInfoDateField(
          label: 'Ngày cấp',
          icon: Icons.date_range,
          date: _dateOfIssue,
          onTap: () => _selectDate(_dateOfIssue, (date) {
            setState(() {
              _dateOfIssue = date;
            });
          }),
        ),
        SizedBox(height: 16.h),
        DriverInfoDateField(
          label: 'Ngày hết hạn',
          icon: Icons.date_range,
          date: _dateOfExpiry,
          onTap: () => _selectDate(_dateOfExpiry, (date) {
            setState(() {
              _dateOfExpiry = date;
            });
          }),
        ),
        SizedBox(height: 16.h),
        DriverInfoFormField(
          controller: _licenseClassController,
          label: 'Hạng bằng',
          icon: Icons.class_,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Vui lòng nhập hạng bằng';
            }
            return null;
          },
        ),
        SizedBox(height: 16.h),
        DriverInfoDateField(
          label: 'Ngày sát hạch',
          icon: Icons.date_range,
          date: _dateOfPassing,
          onTap: () => _selectDate(_dateOfPassing, (date) {
            setState(() {
              _dateOfPassing = date;
            });
          }),
        ),
      ],
    );
  }

  /// Xây dựng nút cập nhật thông tin
  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : () => _updateDriverInfo(),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        minimumSize: Size(double.infinity, 48.h),
      ),
      child: _isLoading
          ? SizedBox(
              height: 20.h,
              width: 20.w,
              child: const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Text('Cập nhật thông tin', style: TextStyle(fontSize: 16.sp)),
    );
  }

  /// Hiển thị date picker
  Future<void> _selectDate(
    DateTime initialDate,
    Function(DateTime) onDateSelected,
  ) async {
    await DatePickerUtils.selectDate(context, initialDate, onDateSelected);
  }

  /// Cập nhật thông tin tài xế
  Future<void> _updateDriverInfo() async {
    if (widget.formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final success = await _accountViewModel.updateDriverInfo(
        driverId: widget.driver.id,
        identityNumber: _identityNumberController.text,
        driverLicenseNumber: _driverLicenseNumberController.text,
        cardSerialNumber: _cardSerialNumberController.text,
        placeOfIssue: _placeOfIssueController.text,
        dateOfIssue: _dateOfIssue,
        dateOfExpiry: _dateOfExpiry,
        licenseClass: _licenseClassController.text,
        dateOfPassing: _dateOfPassing,
      );

      setState(() {
        _isLoading = false;
      });

      if (success && mounted) {
        try {
          // Refresh driver info in both view models
          if (_authViewModel.user != null) {
            // First update the AccountViewModel
            await _accountViewModel.getDriverInfo(_authViewModel.user!.id);

            // Then update the AuthViewModel
            await _authViewModel.refreshDriverInfo();
          }
        } catch (e) {
          debugPrint('Error refreshing driver info: $e');
        }

        // Call the callback to notify parent that update is complete
        widget.onUpdateComplete(true);
      }
    }
  }
}
