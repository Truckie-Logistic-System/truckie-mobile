import 'package:dartz/dartz.dart';

import '../entities/location.dart';
import '../../core/errors/failures.dart';

abstract class LocationRepository {
  /// Lấy vị trí hiện tại
  Future<Either<Failure, LocationEntity>> getCurrentLocation();

  /// Cập nhật vị trí tài xế
  Future<Either<Failure, bool>> updateDriverLocation(LocationEntity location);

  /// Lấy địa chỉ từ tọa độ
  Future<Either<Failure, String>> getAddressFromCoordinates(
    double latitude,
    double longitude,
  );

  /// Lấy tọa độ từ địa chỉ
  Future<Either<Failure, LocationEntity>> getCoordinatesFromAddress(
    String address,
  );
}
