import 'dart:io';


import '../../../../data/repositories/driver_onboarding_repository.dart';
import '../../../../domain/entities/driver.dart';
import '../../../common_widgets/base_viewmodel.dart';

/// ViewModel for driver onboarding flow.
/// Handles password change and face image upload.
class DriverOnboardingViewModel extends BaseViewModel {
  final DriverOnboardingRepository _repository;

  DriverOnboardingViewModel({
    required DriverOnboardingRepository repository,
  }) : _repository = repository;

  // State
  bool _isLoading = false;
  String _errorMessage = '';
  Driver? _updatedDriver;

  // Password fields
  String _currentPassword = '';
  String _newPassword = '';
  String _confirmPassword = '';
  bool _isPasswordValid = false;

  // Face image
  File? _faceImageFile;
  String? _faceImageUrl;
  bool _isFaceDetected = false;

  // Getters
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  Driver? get updatedDriver => _updatedDriver;
  String get currentPassword => _currentPassword;
  String get newPassword => _newPassword;
  String get confirmPassword => _confirmPassword;
  bool get isPasswordValid => _isPasswordValid;
  File? get faceImageFile => _faceImageFile;
  String? get faceImageUrl => _faceImageUrl;
  bool get isFaceDetected => _isFaceDetected;

  /// Check if all onboarding requirements are met
  bool get canSubmit =>
      _isPasswordValid &&
      _faceImageFile != null &&
      _isFaceDetected &&
      !_isLoading;

  /// Set current password (from login)
  void setCurrentPassword(String password) {
    _currentPassword = password;
    notifyListeners();
  }

  /// Update new password
  void setNewPassword(String password) {
    _newPassword = password;
    _validatePassword();
    notifyListeners();
  }

  /// Update confirm password
  void setConfirmPassword(String password) {
    _confirmPassword = password;
    _validatePassword();
    notifyListeners();
  }

  /// Validate password requirements
  void _validatePassword() {
    _errorMessage = '';

    if (_newPassword.isEmpty) {
      _isPasswordValid = false;
      return;
    }

    if (_newPassword.length < 6) {
      _errorMessage = 'Mật khẩu phải có ít nhất 6 ký tự';
      _isPasswordValid = false;
      return;
    }

    if (_newPassword == _currentPassword) {
      _errorMessage = 'Mật khẩu mới phải khác mật khẩu hiện tại';
      _isPasswordValid = false;
      return;
    }

    if (_newPassword != _confirmPassword) {
      _errorMessage = 'Mật khẩu xác nhận không khớp';
      _isPasswordValid = false;
      return;
    }

    _isPasswordValid = true;
  }

  /// Set face image file (before upload)
  void setFaceImageFile(File file) {
    _faceImageFile = file;
    _faceImageUrl = null; // Reset URL when new file is set
    notifyListeners();
  }

  /// Set face detection result
  void setFaceDetected(bool detected) {
    _isFaceDetected = detected;
    if (!detected) {
      _errorMessage = 'Không phát hiện khuôn mặt. Vui lòng chụp lại.';
    } else {
      _errorMessage = '';
    }
    notifyListeners();
  }

  /// Submit onboarding (change password + upload face image + activate account)
  /// This now sends both password and image file in a single multipart request
  Future<bool> submitOnboarding() async {
    // Validate all fields
    if (!_isPasswordValid) {
      _errorMessage = 'Vui lòng nhập mật khẩu hợp lệ';
      notifyListeners();
      return false;
    }

    if (_faceImageFile == null) {
      _errorMessage = 'Vui lòng chụp ảnh khuôn mặt';
      notifyListeners();
      return false;
    }

    if (!_isFaceDetected) {
      _errorMessage = 'Không phát hiện khuôn mặt trong ảnh';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final result = await _repository.submitOnboardingWithImage(
        currentPassword: _currentPassword,
        newPassword: _newPassword,
        confirmPassword: _confirmPassword,
        faceImageFile: _faceImageFile!,
      );

      return result.fold(
        (failure) {
          _errorMessage = failure.message;
          _isLoading = false;
          notifyListeners();
          return false;
        },
        (driver) {
          _updatedDriver = driver;
          _isLoading = false;
          notifyListeners();
          return true;
        },
      );
    } catch (e) {
      _errorMessage = 'Lỗi kích hoạt tài khoản: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  /// Reset all state
  void reset() {
    _isLoading = false;
    _errorMessage = '';
    _updatedDriver = null;
    _currentPassword = '';
    _newPassword = '';
    _confirmPassword = '';
    _isPasswordValid = false;
    _faceImageFile = null;
    _faceImageUrl = null; // Keep for backward compatibility
    _isFaceDetected = false;
    notifyListeners();
  }
}
