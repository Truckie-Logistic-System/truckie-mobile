import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../core/errors/failures.dart';
import '../../entities/driver.dart';
import '../../repositories/driver_repository.dart';

class GetDriverInfoUseCase {
  final DriverRepository repository;

  GetDriverInfoUseCase(this.repository);

  Future<Either<Failure, Driver>> call(GetDriverInfoParams params) async {
    return await repository.getDriverByUserId(params.userId);
  }
}

class GetDriverInfoParams extends Equatable {
  final String userId;

  const GetDriverInfoParams({required this.userId});

  @override
  List<Object?> get props => [userId];
}
