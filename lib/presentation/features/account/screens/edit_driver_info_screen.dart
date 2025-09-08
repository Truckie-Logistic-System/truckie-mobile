import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../domain/entities/driver.dart';
import '../../../common_widgets/spinner_date_picker.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../viewmodels/account_viewmodel.dart';

class EditDriverInfoScreen extends StatefulWidget {
  final Driver driver;

  const EditDriverInfoScreen({super.key, required this.driver});

  @override
  State<EditDriverInfoScreen> createState() => _EditDriverInfoScreenState();
}

class _EditDriverInfoScreenState extends State<EditDriverInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identityNumberController = TextEditingController();
  final _driverLicenseNumberController = TextEditingController();
  final _cardSerialNumberController = TextEditingController();
  final _placeOfIssueController = TextEditingController();
  final _licenseClassController = TextEditingController();

  DateTime _dateOfIssue = DateTime.now();
  DateTime _dateOfExpiry = DateTime.now().add(const Duration(days: 365 * 5));
  DateTime _dateOfPassing = DateTime.now();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeFormValues();
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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => getIt<AccountViewModel>()),
        ChangeNotifierProvider(create: (_) => getIt<AuthViewModel>()),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Chỉnh sửa thông tin tài xế'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Consumer<AccountViewModel>(
          builder: (context, viewModel, _) {
            if (viewModel.status == AccountStatus.updating) {
              return const Center(child: CircularProgressIndicator());
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTextField(
                      controller: _identityNumberController,
                      label: 'Số CMND/CCCD',
                      icon: Icons.badge,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng nhập số CMND/CCCD';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _driverLicenseNumberController,
                      label: 'Số GPLX',
                      icon: Icons.credit_card,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng nhập số GPLX';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _cardSerialNumberController,
                      label: 'Số thẻ',
                      icon: Icons.credit_card,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng nhập số thẻ';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
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
                    const SizedBox(height: 16),
                    _buildDateField(
                      label: 'Ngày cấp',
                      icon: Icons.date_range,
                      date: _dateOfIssue,
                      onTap: () => _selectDate(context, _dateOfIssue, (date) {
                        setState(() {
                          _dateOfIssue = date;
                        });
                      }),
                    ),
                    const SizedBox(height: 16),
                    _buildDateField(
                      label: 'Ngày hết hạn',
                      icon: Icons.date_range,
                      date: _dateOfExpiry,
                      onTap: () => _selectDate(context, _dateOfExpiry, (date) {
                        setState(() {
                          _dateOfExpiry = date;
                        });
                      }),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
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
                    const SizedBox(height: 16),
                    _buildDateField(
                      label: 'Ngày sát hạch',
                      icon: Icons.date_range,
                      date: _dateOfPassing,
                      onTap: () => _selectDate(context, _dateOfPassing, (date) {
                        setState(() {
                          _dateOfPassing = date;
                        });
                      }),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () => _updateDriverInfo(viewModel),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Cập nhật thông tin'),
                    ),
                    if (viewModel.status == AccountStatus.updateError) ...[
                      const SizedBox(height: 16),
                      Text(
                        viewModel.errorMessage,
                        style: const TextStyle(color: AppColors.error),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      validator: validator,
    );
  }

  Widget _buildDateField({
    required String label,
    required IconData icon,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
        child: Text(dateFormat.format(date)),
      ),
    );
  }

  Future<void> _selectDate(
    BuildContext context,
    DateTime initialDate,
    Function(DateTime) onDateSelected,
  ) async {
    // Sử dụng CupertinoDatePicker trên iOS và custom date picker trên Android
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      // iOS date picker
      await _showIOSDatePicker(context, initialDate, onDateSelected);
    } else {
      // Android date picker
      await _showAndroidDatePicker(context, initialDate, onDateSelected);
    }
  }

  Future<void> _showAndroidDatePicker(
    BuildContext context,
    DateTime initialDate,
    Function(DateTime) onDateSelected,
  ) async {
    // Sử dụng spinner date picker tùy chỉnh
    await showSpinnerDatePicker(
      context: context,
      initialDate: initialDate,
      onDateSelected: onDateSelected,
    );
  }

  Future<void> _showIOSDatePicker(
    BuildContext context,
    DateTime initialDate,
    Function(DateTime) onDateSelected,
  ) async {
    DateTime selectedDate = initialDate;

    await showModalBottomSheet(
      context: context,
      builder: (BuildContext builder) {
        return Container(
          height: MediaQuery.of(context).copyWith().size.height / 3,
          color: Colors.white,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Hủy'),
                  ),
                  TextButton(
                    onPressed: () {
                      onDateSelected(selectedDate);
                      Navigator.pop(context);
                    },
                    child: const Text('Xong'),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initialDate,
                  onDateTimeChanged: (DateTime newDate) {
                    selectedDate = newDate;
                  },
                  minimumDate: DateTime(1900),
                  maximumDate: DateTime(2100),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateDriverInfo(AccountViewModel viewModel) async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final success = await viewModel.updateDriverInfo(
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
          // Try to fetch updated driver information if AuthViewModel is available
          final authViewModel = Provider.of<AuthViewModel>(
            context,
            listen: false,
          );
          if (authViewModel.user != null) {
            await viewModel.getDriverInfo(authViewModel.user!.id);
          }
        } catch (e) {
          // If AuthViewModel is not available, just continue
          debugPrint('Could not access AuthViewModel: $e');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cập nhật thông tin thành công'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    }
  }
}
