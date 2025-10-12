import 'package:flutter/material.dart';

import '../widgets/map/index.dart';

class DeliveryMapScreen extends StatelessWidget {
  final String deliveryId;

  const DeliveryMapScreen({super.key, required this.deliveryId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bản đồ giao hàng'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          MapContentWidget(deliveryId: deliveryId),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomPanelWidget(
              onCallCustomer: () {
                // TODO: Implement call customer functionality
              },
              onUpdateStatus: () {
                // TODO: Implement update status functionality
              },
            ),
          ),
        ],
      ),
      floatingActionButton: MapActionButtons(
        onLocationPressed: () {
          // TODO: Implement current location functionality
        },
        onDirectionsPressed: () {
          // TODO: Implement directions functionality
        },
      ),
    );
  }
}
