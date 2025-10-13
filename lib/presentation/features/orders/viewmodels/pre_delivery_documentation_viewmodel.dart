import 'dart:io';
import 'package:flutter/foundation.dart';

import '../../../../domain/usecases/orders/submit_pre_delivery_documentation_usecase.dart';

enum PreDeliveryDocumentationState { initial, loading, success, error }

class PreDeliveryDocumentationViewModel extends ChangeNotifier {
  final SubmitPreDeliveryDocumentationUseCase
  _submitPreDeliveryDocumentationUseCase;

  PreDeliveryDocumentationState _state = PreDeliveryDocumentationState.initial;
  String _errorMessage = '';
  List<File> _packingProofImages = [];
  File? _sealImage;
  String _sealCode = '';

  PreDeliveryDocumentationState get state => _state;
  String get errorMessage => _errorMessage;
  List<File> get packingProofImages => _packingProofImages;
  File? get sealImage => _sealImage;
  String get sealCode => _sealCode;

  PreDeliveryDocumentationViewModel({
    required SubmitPreDeliveryDocumentationUseCase
    submitPreDeliveryDocumentationUseCase,
  }) : _submitPreDeliveryDocumentationUseCase =
           submitPreDeliveryDocumentationUseCase;

  void addPackingProofImage(File image) {
    _packingProofImages.add(image);
    notifyListeners();
  }

  void removePackingProofImage(int index) {
    if (index >= 0 && index < _packingProofImages.length) {
      _packingProofImages.removeAt(index);
      notifyListeners();
    }
  }

  void setSealImage(File image) {
    _sealImage = image;
    notifyListeners();
  }

  void setSealCode(String code) {
    _sealCode = code;
    notifyListeners();
  }

  void clearImages() {
    _packingProofImages = [];
    _sealImage = null;
    notifyListeners();
  }

  void clearSealImage() {
    _sealImage = null;
    notifyListeners();
  }

  void resetState() {
    _state = PreDeliveryDocumentationState.initial;
    _errorMessage = '';
    notifyListeners();
  }

  Future<bool> submitPreDeliveryDocumentation({
    required String vehicleAssignmentId,
  }) async {
    if (_sealCode.isEmpty) {
      _state = PreDeliveryDocumentationState.error;
      _errorMessage = 'Vui lòng nhập mã seal';
      notifyListeners();
      return false;
    }

    // Validate that at least one image is provided
    if ((_packingProofImages.isEmpty || _packingProofImages.isEmpty) &&
        _sealImage == null) {
      _state = PreDeliveryDocumentationState.error;
      _errorMessage = 'Vui lòng chụp ít nhất một ảnh đóng gói hoặc ảnh seal';
      notifyListeners();
      return false;
    }

    _state = PreDeliveryDocumentationState.loading;
    notifyListeners();

    final result = await _submitPreDeliveryDocumentationUseCase(
      vehicleAssignmentId: vehicleAssignmentId,
      sealCode: _sealCode,
      packingProofImages: _packingProofImages.isEmpty
          ? null
          : _packingProofImages,
      sealImage: _sealImage,
    );

    return result.fold(
      (failure) {
        _state = PreDeliveryDocumentationState.error;
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (success) {
        _state = PreDeliveryDocumentationState.success;
        notifyListeners();
        return true;
      },
    );
  }
}
