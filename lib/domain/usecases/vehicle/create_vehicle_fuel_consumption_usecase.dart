import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:decimal/decimal.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/vehicle_repository.dart';

class CreateVehicleFuelConsumptionUseCase {
  final VehicleRepository _repository;

  CreateVehicleFuelConsumptionUseCase(this._repository);

  Future<Either<Failure, bool>> call({
    required String vehicleAssignmentId,
    required Decimal odometerReadingAtStart,
    required File odometerAtStartImage,
  }) async {
    return await _repository.createVehicleFuelConsumption(
      vehicleAssignmentId: vehicleAssignmentId,
      odometerReadingAtStart: odometerReadingAtStart,
      odometerAtStartImage: odometerAtStartImage,
    );
  }
}
