import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../core/errors/failures.dart';
import '../../entities/driver.dart';
import '../../repositories/driver_repository.dart';

class GetDriverInfoUseCase {
  final DriverRepository repository;

  GetDriverInfoUseCase(this.repository);

  Future<Either<Failure, Driver>> call(GetDriverInfoParams params) async {
    return await repository.getDriverInfo();
  }
}

class GetDriverInfoParams extends Equatable {
  // No parameters needed anymore as the API endpoint doesn't require userId
  const GetDriverInfoParams();

  @override
  List<Object?> get props => [];
}
