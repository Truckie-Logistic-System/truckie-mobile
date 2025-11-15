import 'dart:io';
import 'package:flutter/foundation.dart';

import '../../../../domain/entities/order_detail.dart';
import '../../../../domain/usecases/orders/upload_seal_image_usecase.dart';

enum PreDeliveryDocumentationState { initial, loading, success, error }

class PreDeliveryDocumentationViewModel extends ChangeNotifier {
  final DocumentLoadingAndSealUseCase _documentLoadingAndSealUseCase;

  PreDeliveryDocumentationState _state = PreDeliveryDocumentationState.initial;
  String _errorMessage = '';
  List<File> _packingProofImages = [];
  File? _sealImage;
  VehicleSeal? _selectedSeal;

  PreDeliveryDocumentationState get state => _state;
  String get errorMessage => _errorMessage;
  List<File> get packingProofImages => _packingProofImages;
  File? get sealImage => _sealImage;
  VehicleSeal? get selectedSeal => _selectedSeal;

  PreDeliveryDocumentationViewModel({
    required DocumentLoadingAndSealUseCase documentLoadingAndSealUseCase,
  }) : _documentLoadingAndSealUseCase = documentLoadingAndSealUseCase;

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

  void setSelectedSeal(VehicleSeal? seal) {
    _selectedSeal = seal;
    notifyListeners();
  }

  void clearImages() {
    _packingProofImages = [];
    _sealImage = null;
    _selectedSeal = null;
    notifyListeners();
  }

  void clearSealImage() {
    _sealImage = null;
    notifyListeners();
  }

  void resetState() {
    _state = PreDeliveryDocumentationState.initial;
    _errorMessage = '';
    _packingProofImages = [];
    _sealImage = null;
    _selectedSeal = null;
    notifyListeners();
  }

  Future<bool> submitDocumentation({
    required String vehicleAssignmentId,
  }) async {
    // Validate seal selection
    if (_selectedSeal == null) {
      _state = PreDeliveryDocumentationState.error;
      _errorMessage = 'Vui lòng chọn seal';
      notifyListeners();
      return false;
    }

    // Validate packing proof images
    if (_packingProofImages.isEmpty) {
      _state = PreDeliveryDocumentationState.error;
      _errorMessage = 'Vui lòng chụp ít nhất một ảnh hàng hóa';
      notifyListeners();
      return false;
    }

    // Validate seal image
    if (_sealImage == null) {
      _state = PreDeliveryDocumentationState.error;
      _errorMessage = 'Vui lòng chụp ảnh seal';
      notifyListeners();
      return false;
    }

    _state = PreDeliveryDocumentationState.loading;
    notifyListeners();

    final result = await _documentLoadingAndSealUseCase(
      vehicleAssignmentId: vehicleAssignmentId,
      sealCode: _selectedSeal!.sealCode,
      packingProofImages: _packingProofImages,
      sealImage: _sealImage!,
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
