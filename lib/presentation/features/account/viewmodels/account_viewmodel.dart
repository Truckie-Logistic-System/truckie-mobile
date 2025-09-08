import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../domain/entities/driver.dart';
import '../../../../domain/usecases/auth/change_password_usecase.dart';
import '../../../../domain/usecases/auth/get_driver_info_usecase.dart';
import '../../../../domain/usecases/auth/update_driver_info_usecase.dart';

enum AccountStatus {
  initial,
  loading,
  loaded,
  error,
  updating,
  updateSuccess,
  updateError,
  changingPassword,
  passwordChanged,
  passwordError,
}

class AccountViewModel extends ChangeNotifier {
  final GetDriverInfoUseCase _getDriverInfoUseCase;
  final UpdateDriverInfoUseCase _updateDriverInfoUseCase;
  final ChangePasswordUseCase? _changePasswordUseCase;

  AccountStatus _status = AccountStatus.initial;
  Driver? _driver;
  String _errorMessage = '';

  AccountViewModel({
    required GetDriverInfoUseCase getDriverInfoUseCase,
    required UpdateDriverInfoUseCase updateDriverInfoUseCase,
    ChangePasswordUseCase? changePasswordUseCase,
  }) : _getDriverInfoUseCase = getDriverInfoUseCase,
       _updateDriverInfoUseCase = updateDriverInfoUseCase,
       _changePasswordUseCase = changePasswordUseCase;

  AccountStatus get status => _status;
  Driver? get driver => _driver;
  String get errorMessage => _errorMessage;

  Future<void> getDriverInfo(String userId) async {
    _status = AccountStatus.loading;
    notifyListeners();

    final result = await _getDriverInfoUseCase(
      GetDriverInfoParams(userId: userId),
    );

    result.fold(
      (failure) {
        _status = AccountStatus.error;
        _errorMessage = failure.message;
        notifyListeners();
      },
      (driver) {
        _status = AccountStatus.loaded;
        _driver = driver;
        notifyListeners();
      },
    );
  }

  Future<bool> updateDriverInfo({
    required String driverId,
    required String identityNumber,
    required String driverLicenseNumber,
    required String cardSerialNumber,
    required String placeOfIssue,
    required DateTime dateOfIssue,
    required DateTime dateOfExpiry,
    required String licenseClass,
    required DateTime dateOfPassing,
  }) async {
    _status = AccountStatus.updating;
    notifyListeners();

    final dateFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'");

    final driverInfo = {
      "identityNumber": identityNumber,
      "driverLicenseNumber": driverLicenseNumber,
      "cardSerialNumber": cardSerialNumber,
      "placeOfIssue": placeOfIssue,
      "dateOfIssue": dateFormat.format(dateOfIssue),
      "dateOfExpiry": dateFormat.format(dateOfExpiry),
      "licenseClass": licenseClass,
      "dateOfPassing": dateFormat.format(dateOfPassing),
    };

    final result = await _updateDriverInfoUseCase(
      UpdateDriverInfoParams(driverId: driverId, driverInfo: driverInfo),
    );

    return result.fold(
      (failure) {
        _status = AccountStatus.updateError;
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (updatedDriver) {
        _status = AccountStatus.updateSuccess;
        _driver = updatedDriver;

        // Reset status after a short delay to allow UI to show success state
        Future.delayed(const Duration(seconds: 1), () {
          if (_status == AccountStatus.updateSuccess) {
            _status = AccountStatus.loaded;
            notifyListeners();
          }
        });

        notifyListeners();
        return true;
      },
    );
  }

  Future<bool> changePassword({
    required String username,
    required String oldPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) async {
    if (_changePasswordUseCase == null) {
      _status = AccountStatus.passwordError;
      _errorMessage = 'Chức năng đổi mật khẩu chưa được khởi tạo';
      notifyListeners();
      return false;
    }

    _status = AccountStatus.changingPassword;
    notifyListeners();

    final result = await _changePasswordUseCase!(
      ChangePasswordParams(
        username: username,
        oldPassword: oldPassword,
        newPassword: newPassword,
        confirmNewPassword: confirmNewPassword,
      ),
    );

    return result.fold(
      (failure) {
        _status = AccountStatus.passwordError;
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (success) {
        _status = AccountStatus.passwordChanged;

        // Reset status after a short delay to allow UI to show success state
        Future.delayed(const Duration(seconds: 1), () {
          if (_status == AccountStatus.passwordChanged) {
            _status = AccountStatus.loaded;
            notifyListeners();
          }
        });

        notifyListeners();
        return true;
      },
    );
  }
}
