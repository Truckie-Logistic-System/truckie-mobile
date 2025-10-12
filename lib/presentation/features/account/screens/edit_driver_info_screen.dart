import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/services/system_ui_service.dart';
import '../../../../core/utils/responsive_extensions.dart';
import '../../../../domain/entities/driver.dart';
import '../../../common_widgets/responsive_layout_builder.dart';
import '../../../theme/app_colors.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../viewmodels/account_viewmodel.dart';
import '../widgets/edit_driver_info/index.dart';

/// Màn hình chỉnh sửa thông tin tài xế
class EditDriverInfoScreen extends StatefulWidget {
  final Driver driver;

  const EditDriverInfoScreen({super.key, required this.driver});

  @override
  State<EditDriverInfoScreen> createState() => _EditDriverInfoScreenState();
}

class _EditDriverInfoScreenState extends State<EditDriverInfoScreen> {
  final _formKey = GlobalKey<FormState>();

  // Use the singleton instances from GetIt
  late final AuthViewModel _authViewModel;
  late final AccountViewModel _accountViewModel;

  @override
  void initState() {
    super.initState();
    _authViewModel = getIt<AuthViewModel>();
    _accountViewModel = getIt<AccountViewModel>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh sửa thông tin tài xế'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: _accountViewModel),
          ChangeNotifierProvider.value(value: _authViewModel),
        ],
        child: Consumer<AccountViewModel>(
          builder: (context, viewModel, _) {
            if (viewModel.status == AccountStatus.updating) {
              return const Center(child: CircularProgressIndicator());
            }

            return ResponsiveLayoutBuilder(
              builder: (context, sizingInformation) {
                return SingleChildScrollView(
                  padding: SystemUiService.getContentPadding(context),
                  child: Center(
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: sizingInformation.isTablet
                            ? 600.w
                            : double.infinity,
                      ),
                      child: Card(
                        elevation: sizingInformation.isTablet ? 4 : 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            sizingInformation.isTablet ? 16.r : 0,
                          ),
                        ),
                        margin: sizingInformation.isTablet
                            ? EdgeInsets.all(16.r)
                            : EdgeInsets.zero,
                        child: Padding(
                          padding: EdgeInsets.all(
                            sizingInformation.isTablet ? 24.r : 16.r,
                          ),
                          child: DriverInfoForm(
                            driver: widget.driver,
                            formKey: _formKey,
                            onUpdateComplete: (success) async {
                              if (success) {
                                // Fetch the updated driver info before navigating back
                                if (_authViewModel.user != null) {
                                  // Refresh the driver info in the account view model
                                  await _accountViewModel.getDriverInfo(
                                    _authViewModel.user!.id,
                                  );

                                  // Also refresh the auth view model's driver info
                                  await _authViewModel.refreshDriverInfo();
                                }

                                if (mounted) {
                                  // Show success message
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Cập nhật thông tin thành công',
                                      ),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );

                                  // Navigate back with result
                                  Navigator.of(context).pop(true);
                                }
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
