import 'package:dartz/dartz.dart';

import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/driver.dart';
import '../../domain/repositories/driver_repository.dart';
import '../datasources/driver_data_source.dart';

class DriverRepositoryImpl implements DriverRepository {
  final DriverDataSource dataSource;

  DriverRepositoryImpl({required this.dataSource});

  @override
  Future<Either<Failure, Driver>> getDriverByUserId(String userId) async {
    try {
      final driver = await dataSource.getDriverByUserId(userId);
      return Right(driver);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Driver>> updateDriverInfo(
    String driverId,
    Map<String, dynamic> driverInfo,
  ) async {
    try {
      final driver = await dataSource.updateDriverInfo(driverId, driverInfo);
      return Right(driver);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
