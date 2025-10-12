import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/driver.dart';

abstract class DriverRepository {
  /// Get driver information for the current authenticated user
  Future<Either<Failure, Driver>> getDriverInfo();

  /// Get driver information by user ID (legacy method)
  Future<Either<Failure, Driver>> getDriverByUserId(String userId);

  /// Update driver information
  Future<Either<Failure, Driver>> updateDriverInfo(
    String driverId,
    Map<String, dynamic> driverInfo,
  );
}
