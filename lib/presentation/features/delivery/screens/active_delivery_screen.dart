import 'package:flutter/material.dart';

import '../../../../core/utils/responsive_extensions.dart';
import '../../../../presentation/common_widgets/responsive_layout_builder.dart';
import '../../../../presentation/theme/app_colors.dart';
import '../widgets/index.dart';

class ActiveDeliveryScreen extends StatelessWidget {
  const ActiveDeliveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Giao hàng hiện tại'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ResponsiveLayoutBuilder(
        builder: (context, sizingInformation) {
          return Column(
            children: [
              const DeliveryProgressWidget(
                remainingTime: '15 phút',
                distance: '2.5 km',
                progress: 0.7,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16.r),
                  child: sizingInformation.isTablet
                      ? _buildTabletLayout(context)
                      : _buildPhoneLayout(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const OrderInfoWidget(
          orderId: 'DH001',
          status: 'Đang giao',
          pickupTime: '09:15 - 15/09/2025',
          deliveryTime: '10:30 - 15/09/2025',
        ),
        SizedBox(height: 24.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const LocationInfoWidget(),
                  SizedBox(height: 24.h),
                  CustomerInfoWidget(
                    customerName: 'Nguyễn Thị B',
                    phoneNumber: '0987654321',
                    onCallPressed: () {
                      // TODO: Implement call functionality
                    },
                  ),
                ],
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                children: [
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16.r),
                      child: ActionButtonsWidget(
                        onViewMapPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/delivery-map',
                            arguments: 'DH001',
                          );
                        },
                        onCompleteDeliveryPressed: () {
                          _handleCompleteDelivery(context);
                        },
                        onReportIssuePressed: () {
                          _handleReportIssue(context);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPhoneLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const OrderInfoWidget(
          orderId: 'DH001',
          status: 'Đang giao',
          pickupTime: '09:15 - 15/09/2025',
          deliveryTime: '10:30 - 15/09/2025',
        ),
        SizedBox(height: 24.h),
        const LocationInfoWidget(),
        SizedBox(height: 24.h),
        CustomerInfoWidget(
          customerName: 'Nguyễn Thị B',
          phoneNumber: '0987654321',
          onCallPressed: () {
            // TODO: Implement call functionality
          },
        ),
        SizedBox(height: 24.h),
        ActionButtonsWidget(
          onViewMapPressed: () {
            Navigator.pushNamed(context, '/delivery-map', arguments: 'DH001');
          },
          onCompleteDeliveryPressed: () {
            _handleCompleteDelivery(context);
          },
          onReportIssuePressed: () {
            _handleReportIssue(context);
          },
        ),
      ],
    );
  }

  Future<void> _handleCompleteDelivery(BuildContext context) async {
    final confirmed = await CompleteDeliveryDialog.show(context);

    if (confirmed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã hoàn thành giao hàng'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  Future<void> _handleReportIssue(BuildContext context) async {
    final issue = await ReportIssueDialog.show(context);

    if (issue != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã báo cáo: $issue'),
          backgroundColor: AppColors.info,
        ),
      );
    }
  }
}
