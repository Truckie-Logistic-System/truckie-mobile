import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/driver.dart';

abstract class DriverRepository {
  /// Get driver information by user ID
  Future<Either<Failure, Driver>> getDriverByUserId(String userId);

  /// Update driver information
  Future<Either<Failure, Driver>> updateDriverInfo(
    String driverId,
    Map<String, dynamic> driverInfo,
  );
}
