import 'package:equatable/equatable.dart';

class LocationEntity extends Equatable {
  final double latitude;
  final double longitude;
  final String? address;
  final DateTime timestamp;

  const LocationEntity({
    required this.latitude,
    required this.longitude,
    this.address,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [latitude, longitude, address, timestamp];
}
