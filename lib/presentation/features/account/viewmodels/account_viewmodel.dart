import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../../domain/entities/driver.dart';
import '../../../../domain/usecases/auth/change_password_usecase.dart';
import '../../../../domain/usecases/auth/get_driver_info_usecase.dart';
import '../../../../domain/usecases/auth/update_driver_info_usecase.dart';
import '../../../common_widgets/base_viewmodel.dart';

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

class AccountViewModel extends BaseViewModel {
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
    if (_status == AccountStatus.loading) return; // Tránh gọi nhiều lần

    _status = AccountStatus.loading;
    notifyListeners();

    final result = await _getDriverInfoUseCase(const GetDriverInfoParams());

    result.fold(
      (failure) async {
        _status = AccountStatus.error;
        _errorMessage = failure.message;

        // Sử dụng handleUnauthorizedError từ BaseViewModel
        final shouldRetry = await handleUnauthorizedError(failure.message);
        if (shouldRetry) {
          // Nếu refresh token thành công, thử lại
          // debugPrint('Token refreshed, retrying to get driver info...');
          await getDriverInfo(userId);
          return;
        }

        notifyListeners();
      },
      (driver) {
        _status = AccountStatus.loaded;
        _driver = driver;
        notifyListeners();
      },
    );
  }

  // Force refresh driver info - bỏ qua kiểm tra loading state
  Future<void> refreshDriverInfo(String userId) async {
    debugPrint('🔄 AccountViewModel: Force refreshing driver info...');
    _status = AccountStatus.loading;
    notifyListeners();

    final result = await _getDriverInfoUseCase(const GetDriverInfoParams());

    result.fold(
      (failure) async {
        _status = AccountStatus.error;
        _errorMessage = failure.message;

        // Sử dụng handleUnauthorizedError từ BaseViewModel
        final shouldRetry = await handleUnauthorizedError(failure.message);
        if (shouldRetry) {
          // Nếu refresh token thành công, thử lại
          debugPrint('🔄 AccountViewModel: Token refreshed, retrying force refresh...');
          await refreshDriverInfo(userId);
          return;
        }

        notifyListeners();
      },
      (driver) {
        _status = AccountStatus.loaded;
        _driver = driver;
        debugPrint('✅ AccountViewModel: Force refresh completed');
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
      (failure) async {
        _status = AccountStatus.updateError;
        _errorMessage = failure.message;

        // Sử dụng handleUnauthorizedError từ BaseViewModel
        final shouldRetry = await handleUnauthorizedError(failure.message);
        if (shouldRetry) {
          // Nếu refresh token thành công, thử lại
          return updateDriverInfo(
            driverId: driverId,
            identityNumber: identityNumber,
            driverLicenseNumber: driverLicenseNumber,
            cardSerialNumber: cardSerialNumber,
            placeOfIssue: placeOfIssue,
            dateOfIssue: dateOfIssue,
            dateOfExpiry: dateOfExpiry,
            licenseClass: licenseClass,
            dateOfPassing: dateOfPassing,
          );
        }

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

    final result = await _changePasswordUseCase(
      ChangePasswordParams(
        username: username,
        oldPassword: oldPassword,
        newPassword: newPassword,
        confirmNewPassword: confirmNewPassword,
      ),
    );

    return result.fold(
      (failure) async {
        _status = AccountStatus.passwordError;
        _errorMessage = failure.message;

        // Sử dụng handleUnauthorizedError từ BaseViewModel
        final shouldRetry = await handleUnauthorizedError(failure.message);
        if (shouldRetry) {
          // Nếu refresh token thành công, thử lại
          return changePassword(
            username: username,
            oldPassword: oldPassword,
            newPassword: newPassword,
            confirmNewPassword: confirmNewPassword,
          );
        }

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
