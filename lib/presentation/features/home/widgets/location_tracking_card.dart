import 'package:flutter/material.dart';
import '../../../../app/app_routes.dart';
import '../../../../core/utils/responsive_extensions.dart';
import '../../../../presentation/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:provider/provider.dart';

class LocationTrackingCard extends StatelessWidget {
  const LocationTrackingCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    final driver = authViewModel.driver;
    final user = authViewModel.user;

    if (driver == null || user == null) {
      return const SizedBox.shrink();
    }

    final token = user.authToken;
    final vehicleId = driver.id; // Use driver ID as vehicle ID
    final licensePlate = driver.userResponse.phoneNumber ?? 'Không có biển số';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed(
            AppRoutes.driverLocation,
            arguments: {
              'vehicleId': vehicleId,
              'licensePlateNumber': licensePlate,
              'jwtToken': token,
            },
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Theo dõi vị trí xe',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const Icon(Icons.location_on, color: Colors.blue),
                ],
              ),
              SizedBox(height: 12.h),
              Text(
                'Biển số: $licensePlate',
                style: TextStyle(fontSize: 14.sp, color: Colors.black87),
              ),
              SizedBox(height: 8.h),
              Text(
                'ID xe: $vehicleId',
                style: TextStyle(fontSize: 14.sp, color: Colors.black54),
              ),
              SizedBox(height: 16.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 10.h),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'Bắt đầu theo dõi',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
