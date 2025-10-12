import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../core/errors/failures.dart';
import '../../entities/driver.dart';
import '../../repositories/driver_repository.dart';

class UpdateDriverInfoUseCase {
  final DriverRepository repository;

  UpdateDriverInfoUseCase(this.repository);

  Future<Either<Failure, Driver>> call(UpdateDriverInfoParams params) async {
    return await repository.updateDriverInfo(
      params.driverId,
      params.driverInfo,
    );
  }
}

class UpdateDriverInfoParams extends Equatable {
  final String driverId;
  final Map<String, dynamic> driverInfo;

  const UpdateDriverInfoParams({
    required this.driverId,
    required this.driverInfo,
  });

  @override
  List<Object?> get props => [driverId, driverInfo];
}
