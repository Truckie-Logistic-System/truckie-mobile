import 'package:dartz/dartz.dart';
import 'dart:io';
import 'package:decimal/decimal.dart';

import '../../core/errors/failures.dart';

abstract class VehicleRepository {
  /// Tạo mới bản ghi tiêu thụ nhiên liệu cho phương tiện
  Future<Either<Failure, bool>> createVehicleFuelConsumption({
    required String vehicleAssignmentId,
    required Decimal odometerReadingAtStart,
    required File odometerAtStartImage,
  });
}
