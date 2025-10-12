import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../domain/entities/order_with_details.dart';
import '../viewmodels/order_list_viewmodel.dart';
import '../viewmodels/pre_delivery_documentation_viewmodel.dart';
import '../widgets/order_detail/pre_delivery_documentation_section.dart';
import '../../../../presentation/theme/app_colors.dart';

class PreDeliveryDocumentationScreen extends StatefulWidget {
  final OrderWithDetails order;

  const PreDeliveryDocumentationScreen({Key? key, required this.order})
    : super(key: key);

  // Named route for navigation
  static const routeName = '/pre-delivery-documentation';

  @override
  State<PreDeliveryDocumentationScreen> createState() =>
      _PreDeliveryDocumentationScreenState();
}

class _PreDeliveryDocumentationScreenState
    extends State<PreDeliveryDocumentationScreen> {
  late final PreDeliveryDocumentationViewModel _viewModel;
  late final OrderListViewModel _orderListViewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = getIt<PreDeliveryDocumentationViewModel>();
    _orderListViewModel = getIt<OrderListViewModel>();
  }

  @override
  void dispose() {
    // Tải lại danh sách đơn hàng khi màn hình xác nhận đóng gói bị đóng
    _orderListViewModel.getDriverOrders();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _viewModel),
        ChangeNotifierProvider.value(value: _orderListViewModel),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Xác nhận đóng gói và seal'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: PreDeliveryDocumentationSection(
            order: widget.order,
            onSubmitSuccess: () {
              // Tải lại danh sách đơn hàng trước khi quay lại
              _orderListViewModel.getDriverOrders();
              // Navigate back with success result
              Navigator.of(context).pop(true);
            },
          ),
        ),
      ),
    );
  }
}
