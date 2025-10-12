import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/services/system_ui_service.dart';
import '../../../../core/services/token_storage_service.dart';
import '../../../../core/utils/responsive_extensions.dart';
import '../../../../presentation/common_widgets/responsive_grid.dart';
import '../../../../presentation/common_widgets/responsive_layout_builder.dart';
import '../../../../presentation/common_widgets/skeleton_loader.dart';
import '../../../../presentation/features/auth/viewmodels/auth_viewmodel.dart';
import '../widgets/index.dart';

/// Màn hình trang chủ của ứng dụng
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AuthViewModel _authViewModel;

  @override
  void initState() {
    super.initState();
    _authViewModel = getIt<AuthViewModel>();

    // Đảm bảo token được refresh khi vào màn hình
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_authViewModel.status == AuthStatus.authenticated) {
        _authViewModel.forceRefreshToken();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Tải lại thông tin tài xế khi màn hình được hiển thị lại
    if (_authViewModel.status == AuthStatus.authenticated) {
      _authViewModel.refreshDriverInfo();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _authViewModel,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Truckie Driver'),
          centerTitle: true,
          automaticallyImplyLeading: false, // Loại bỏ nút back
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {
                // TODO: Hiển thị thông báo
              },
            ),
          ],
        ),
        body: Consumer<AuthViewModel>(
          builder: (context, authViewModel, _) {
            final user = authViewModel.user;
            final driver = authViewModel.driver;

            // Always show content, use skeleton loaders when data is not available
            return SafeArea(
              // Đặt bottom: false vì đã xử lý trong MainScreen
              bottom: false,
              child: SingleChildScrollView(
                // Thêm padding bottom để đảm bảo nội dung không bị che bởi navigation bar
                padding: SystemUiService.getContentPadding(context),
                child: ResponsiveLayoutBuilder(
                  builder: (context, sizingInformation) {
                    // Use different layouts based on screen size
                    if (sizingInformation.isTablet) {
                      // Tablet layout with 2 columns
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Driver info with skeleton loading
                          if (user == null || driver == null)
                            const DriverInfoSkeletonCard()
                          else
                            DriverInfoCard(user: user, driver: driver),
                          SizedBox(height: 24.h),

                          // Location tracking card
                          if (user != null && driver != null)
                            GestureDetector(
                              onTap: () async {
                                final tokenStorage =
                                    getIt<TokenStorageService>();
                                final token = tokenStorage.getAccessToken();
                                if (token != null) {
                                  Navigator.of(context).pushNamed(
                                    AppRoutes.driverLocation,
                                    arguments: {
                                      'vehicleId': driver.id,
                                      'licensePlateNumber':
                                          driver.userResponse.phoneNumber ??
                                          'Không có biển số',
                                      'jwtToken': token,
                                    },
                                  );
                                }
                              },
                              child: Card(
                                elevation: 4,
                                margin: EdgeInsets.symmetric(horizontal: 16.w),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(16.r),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on,
                                        color: Colors.blue,
                                        size: 32,
                                      ),
                                      SizedBox(width: 16.w),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Theo dõi vị trí xe',
                                              style: TextStyle(
                                                fontSize: 18.sp,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            SizedBox(height: 4.h),
                                            Text(
                                              'Bật theo dõi vị trí xe để chia sẻ với điều phối',
                                              style: TextStyle(
                                                fontSize: 14.sp,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.arrow_forward_ios,
                                        color: Colors.blue,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          SizedBox(height: 16.h),

                          // Use ResponsiveGrid for tablet layout
                          ResponsiveGrid(
                            smallScreenColumns: 1,
                            mediumScreenColumns: 2,
                            largeScreenColumns: 2,
                            horizontalSpacing: 16.w,
                            verticalSpacing: 16.h,
                            children: [
                              // Statistics with skeleton loading
                              if (user == null || driver == null)
                                const StatisticsSkeletonCard()
                              else
                                const StatisticsCard(),

                              // Current delivery with skeleton loading
                              if (user == null || driver == null)
                                const DeliverySkeletonCard()
                              else
                                const CurrentDeliveryCard(),
                            ],
                          ),
                          SizedBox(height: 24.h),

                          // Recent orders with skeleton loading
                          if (user == null || driver == null)
                            const OrdersSkeletonList(itemCount: 2)
                          else
                            const RecentOrdersCard(),
                        ],
                      );
                    } else {
                      // Phone layout with single column
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Driver info with skeleton loading
                          if (user == null || driver == null)
                            const DriverInfoSkeletonCard()
                          else
                            DriverInfoCard(user: user, driver: driver),
                          SizedBox(height: 24.h),

                          // Statistics with skeleton loading
                          if (user == null || driver == null)
                            const StatisticsSkeletonCard()
                          else
                            const StatisticsCard(),
                          SizedBox(height: 24.h),

                          // Current delivery with skeleton loading
                          if (user == null || driver == null)
                            const DeliverySkeletonCard()
                          else
                            const CurrentDeliveryCard(),
                          SizedBox(height: 24.h),

                          // Recent orders with skeleton loading
                          if (user == null || driver == null)
                            const OrdersSkeletonList(itemCount: 2)
                          else
                            const RecentOrdersCard(),
                        ],
                      );
                    }
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
