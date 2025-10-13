import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OCRService {
  static final OCRService _instance = OCRService._internal();
  factory OCRService() => _instance;
  OCRService._internal();

  TextRecognizer? _latinOptimizedRecognizer;  // Google ML Kit tối ưu cho Latin script
  TextRecognizer? _defaultRecognizer;         // Google ML Kit mặc định (fallback)

  /// Khởi tạo OCR service với dual recognizer strategy
  void initialize() {
    // Khởi tạo Latin-optimized recognizer (tối ưu cho odometer)
    _latinOptimizedRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    // Khởi tạo default recognizer (fallback đảm bảo hoạt động)
    _defaultRecognizer = TextRecognizer();
  }

  /// Trích xuất số từ ảnh odometer
  /// Ưu tiên: Google ML Kit Latin-optimized -> Default Fallback
  /// Trả về chuỗi số đầu tiên tìm thấy hoặc null nếu không tìm thấy
  Future<String?> extractOdometerReading(File imageFile) async {
    // Kiểm tra chất lượng ảnh trước khi xử lý OCR
    final qualityCheck = await _checkImageQuality(imageFile);
    if (!qualityCheck.isValid) {
      print('⚠️ ${qualityCheck.warning}');
      // Vẫn tiếp tục OCR nhưng với cảnh báo
    }

    // Thử với Latin-optimized recognizer trước (Google ML Kit tối ưu cho odometer)
    String? result = await _tryLatinOptimizedOCR(imageFile);

    if (result != null && result.isNotEmpty) {
      print('✅ Latin-optimized OCR thành công: $result');
      return result;
    }

    // Fallback: Thử với default recognizer
    print('🔄 Latin-optimized OCR thất bại, chuyển sang Default OCR...');
    result = await _tryDefaultOCR(imageFile);

    if (result != null && result.isNotEmpty) {
      print('✅ Default OCR thành công: $result');
      return result;
    }

    print('❌ Cả Latin-optimized và Default OCR đều thất bại');
    return null;
  }

  /// Thử OCR với Google ML Kit tối ưu cho Latin script (odometer)
  Future<String?> _tryLatinOptimizedOCR(File imageFile) async {
    try {
      // Khởi tạo nếu chưa có
      _latinOptimizedRecognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
      
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _latinOptimizedRecognizer!.processImage(inputImage);

      print('📝 [LATIN-OPTIMIZED] OCR Raw text: ${recognizedText.text}');
      print('📝 [LATIN-OPTIMIZED] OCR All blocks:');
      for (var block in recognizedText.blocks) {
        print('  Block: ${block.text}');
        for (var line in block.lines) {
          print('    Line: ${line.text}');
        }
      }
      
      // Tìm kiếm các pattern số trong text với phân tích theo vị trí
      final extractedNumbers = _extractNumbersWithContext(recognizedText);
      
      print('🔢 [LATIN-OPTIMIZED] OCR Extracted numbers: $extractedNumbers');
      
      if (extractedNumbers.isNotEmpty) {
        // Trả về số phù hợp nhất (thường là số odometer)
        final result = _findBestOdometerNumber(extractedNumbers);
        print('✅ [LATIN-OPTIMIZED] OCR Best match: $result');
        return result;
      }
      
      print('❌ [LATIN-OPTIMIZED] OCR No numbers found');
      return null;
    } catch (e) {
      print('❌ [LATIN-OPTIMIZED] OCR Error: $e');
      return null;
    }
  }

  /// Thử OCR với Google ML Kit mặc định (fallback)
  Future<String?> _tryDefaultOCR(File imageFile) async {
    try {
      // Khởi tạo nếu chưa có
      _defaultRecognizer ??= TextRecognizer();
      
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _defaultRecognizer!.processImage(inputImage);

      print('📝 [DEFAULT] OCR Raw text: ${recognizedText.text}');
      print('📝 [DEFAULT] OCR All blocks:');
      for (var block in recognizedText.blocks) {
        print('  Block: ${block.text}');
        for (var line in block.lines) {
          print('    Line: ${line.text}');
        }
      }
      
      // Tìm kiếm các pattern số trong text với phân tích theo vị trí
      final extractedNumbers = _extractNumbersWithContext(recognizedText);
      
      print('🔢 [DEFAULT] OCR Extracted numbers: $extractedNumbers');
      
      if (extractedNumbers.isNotEmpty) {
        // Trả về số phù hợp nhất (thường là số odometer)
        final result = _findBestOdometerNumber(extractedNumbers);
        print('✅ [DEFAULT] OCR Best match: $result');
        return result;
      }
      
      print('❌ [DEFAULT] OCR No numbers found');
      return null;
    } catch (e) {
      print('❌ [DEFAULT] OCR Error: $e');
      return null;
    }
  }


  /// Trích xuất tất cả các số từ text với context
  List<String> _extractNumbersWithContext(RecognizedText recognizedText) {
    Set<String> numbers = {};
    Map<String, int> numberPriority = {}; // Lưu độ ưu tiên của mỗi số
    
    // Các từ khóa odometer (ưu tiên cao nhất)
    final odometerKeywords = ['ODO', 'MILES', 'MILE', 'KM', 'KM/H', 'ODOMETER'];
    
    // Tìm các dòng có chứa từ khóa odometer
    for (var block in recognizedText.blocks) {
      for (var line in block.lines) {
        String lineText = line.text.toUpperCase();
        
        // Kiểm tra xem dòng có chứa từ khóa odometer không
        bool hasOdometerKeyword = odometerKeywords.any((keyword) => lineText.contains(keyword));
        
        if (hasOdometerKeyword) {
          print('🎯 Found odometer line: ${line.text}');
          
          // Trích xuất số từ dòng này
          String cleanLine = line.text.replaceAll(RegExp(r'[^\d\s]'), ' ');
          // Ghép các số đơn lẻ (7 0 4 4 1 2 5 -> 7044125)
          String compactNumber = cleanLine.replaceAll(RegExp(r'\s+'), '');
          
          if (compactNumber.isNotEmpty && compactNumber.length >= 5) {
            numbers.add(compactNumber);
            numberPriority[compactNumber] = 100; // Ưu tiên cao nhất
            print('✅ Extracted from odometer line: $compactNumber');
          }
        }
      }
    }
    
    // Tìm các số nằm gần text "ODO", "MILES", "KM" (trong cùng block hoặc block kế bên)
    for (int i = 0; i < recognizedText.blocks.length; i++) {
      var block = recognizedText.blocks[i];
      String blockText = block.text.toUpperCase();
      
      // Kiểm tra block có từ khóa không
      bool hasKeyword = odometerKeywords.any((keyword) => blockText.contains(keyword));
      
      if (hasKeyword) {
        // Tìm số trong block này và block kế bên
        for (int j = i - 1; j <= i + 1; j++) {
          if (j >= 0 && j < recognizedText.blocks.length) {
            var nearBlock = recognizedText.blocks[j];
            String cleanBlock = nearBlock.text.replaceAll(RegExp(r'[^\d\s]'), ' ');
            String compactNumber = cleanBlock.replaceAll(RegExp(r'\s+'), '');
            
            if (compactNumber.isNotEmpty && compactNumber.length >= 5) {
              numbers.add(compactNumber);
              numberPriority[compactNumber] = 90; // Ưu tiên cao
              print('🔍 Found number near keyword: $compactNumber');
            }
          }
        }
      }
    }
    
    // Tìm tất cả các số dài (5-7 chữ số) - bao gồm cả trường hợp chỉ chụp số odometer
    var allNumbers = _extractNumbers(recognizedText.text);
    for (var num in allNumbers) {
      if (num.length >= 5 && num.length <= 7) {
        numbers.add(num);
        numberPriority[num] = 50; // Ưu tiên trung bình
      }
    }
    
    // Nếu vẫn chưa có số nào, thử tìm số dài nhất (fallback cho ảnh cắt)
    if (numbers.isEmpty) {
      var allNumbers = _extractNumbers(recognizedText.text);
      var longNumbers = allNumbers.where((num) => num.length >= 4).toList();

      if (longNumbers.isNotEmpty) {
        // Sắp xếp theo độ dài giảm dần
        longNumbers.sort((a, b) => b.length.compareTo(a.length));

        // Lọc số hợp lệ (4-8 chữ số, không phải số quá nhỏ)
        var validLongNumbers = longNumbers.where((num) {
          String clean = num.replaceAll(RegExp(r'[.,]'), '');
          return clean.length >= 4 && clean.length <= 8 && clean != '0' && clean != '00' && clean != '000';
        }).toList();

        if (validLongNumbers.isNotEmpty) {
          numbers.add(validLongNumbers.first);
          numberPriority[validLongNumbers.first] = 25; // Ưu tiên thấp nhưng vẫn khả thi
          print('🔢 Ảnh cắt fallback - dùng số dài nhất hợp lệ: ${validLongNumbers.first}');
        } else if (longNumbers.isNotEmpty) {
          // Nếu không có số hợp lệ, lấy số dài nhất bất kể
          numbers.add(longNumbers.first);
          numberPriority[longNumbers.first] = 20; // Ưu tiên rất thấp
          print('🔢 Ảnh cắt emergency fallback - dùng số dài nhất: ${longNumbers.first}');
        }
      }
    }
    
    // Sắp xếp theo độ ưu tiên
    var sortedNumbers = numbers.toList();
    sortedNumbers.sort((a, b) {
      int priorityA = numberPriority[a] ?? 0;
      int priorityB = numberPriority[b] ?? 0;
      if (priorityA != priorityB) {
        return priorityB.compareTo(priorityA); // Ưu tiên cao hơn lên trước
      }
      // Nếu cùng độ ưu tiên, ưu tiên số dài hơn
      return b.length.compareTo(a.length);
    });
    
    return sortedNumbers;
  }

  /// Trích xuất tất cả các số từ text
  List<String> _extractNumbers(String text) {
    // Làm sạch text - loại bỏ các ký tự đặc biệt nhưng giữ lại số và khoảng trắng
    String cleanText = text.replaceAll(RegExp(r'[^\d\s.,\-]'), ' ');
    
    // Xử lý các trường hợp số bị tách rời bởi khoảng trắng (ví dụ: "7 0 4 4 1 2 5")
    // Ghép các số đơn lẻ liền kề thành một số
    String compactText = cleanText.replaceAll(RegExp(r'(\d)\s+(?=\d)'), r'$1');
    
    // Tìm các pattern số khác nhau
    final List<RegExp> patterns = [
      RegExp(r'\b\d{5,8}\b'),           // Số 5-8 chữ số (odometer thông thường)
      RegExp(r'\b\d+[.,]\d+\b'),       // Số có dấu phẩy/chấm
      RegExp(r'\b\d{4,}\b'),           // Số từ 4 chữ số trở lên
      RegExp(r'\b\d+\b'),              // Bất kỳ số nào
    ];
    
    Set<String> numbers = {};
    
    for (RegExp pattern in patterns) {
      final matches = pattern.allMatches(compactText);
      numbers.addAll(matches.map((match) => match.group(0)!));
    }
    
    // Nếu không tìm thấy số nào, thử tìm trong text gốc
    if (numbers.isEmpty) {
      final directMatches = RegExp(r'\d+').allMatches(text);
      numbers.addAll(directMatches.map((match) => match.group(0)!));
    }
    
    return numbers.toList();
  }

  /// Tìm số phù hợp nhất cho odometer reading
  String _findBestOdometerNumber(List<String> numbers) {
    if (numbers.isEmpty) return '';
    
    // Lọc các số hợp lệ (4-7 chữ số) - mở rộng để bao gồm trường hợp chỉ chụp số
    var validNumbers = numbers.where((num) {
      String clean = num.replaceAll(RegExp(r'[.,]'), '');
      return clean.length >= 4 && clean.length <= 7;
    }).toList();
    
    // Nếu không có số hợp lệ, lấy số dài nhất
    if (validNumbers.isEmpty) {
      validNumbers = numbers;
    }
    
    // Sắp xếp theo độ ưu tiên
    validNumbers.sort((a, b) {
      String cleanA = a.replaceAll(RegExp(r'[.,]'), '');
      String cleanB = b.replaceAll(RegExp(r'[.,]'), '');
      
      // Ưu tiên 1: Số có 6 chữ số (odometer phổ biến nhất)
      bool aIs6Digits = cleanA.length == 6;
      bool bIs6Digits = cleanB.length == 6;
      
      if (aIs6Digits && !bIs6Digits) return -1;
      if (!aIs6Digits && bIs6Digits) return 1;
      
      // Ưu tiên 2: Số có 5-7 chữ số
      bool aIsOdometer = cleanA.length >= 5 && cleanA.length <= 7;
      bool bIsOdometer = cleanB.length >= 5 && cleanB.length <= 7;
      
      if (aIsOdometer && !bIsOdometer) return -1;
      if (!aIsOdometer && bIsOdometer) return 1;
      
      // Ưu tiên 3: Số dài hơn (trong khoảng 4-7)
      if (cleanA.length != cleanB.length) {
        return cleanB.length.compareTo(cleanA.length);
      }
      
      // Ưu tiên 4: Số có nhiều chữ số hơn (ưu tiên số thực, không phải số 0)
      int aNonZeroCount = cleanA.replaceAll('0', '').length;
      int bNonZeroCount = cleanB.replaceAll('0', '').length;
      
      if (aNonZeroCount != bNonZeroCount) {
        return bNonZeroCount.compareTo(aNonZeroCount);
      }
      
      // Ưu tiên 5: Số lớn hơn
      try {
        int intA = int.parse(cleanA);
        int intB = int.parse(cleanB);
        return intB.compareTo(intA);
      } catch (e) {
        return 0;
      }
    });
    
    // Làm sạch và format số tốt nhất
    return _cleanNumber(validNumbers.first);
  }

  /// Làm sạch số (loại bỏ dấu phẩy, chấm thừa)
  String _cleanNumber(String number) {
    // Loại bỏ dấu phẩy và chấm (thường là noise từ OCR)
    return number.replaceAll(RegExp(r'[.,]'), '');
  }

  /// Kiểm tra chất lượng ảnh trước khi OCR
  Future<_ImageQualityCheck> _checkImageQuality(File imageFile) async {
    try {
      // Kiểm tra kích thước file
      final fileSize = await imageFile.length();
      const minFileSize = 5 * 1024; // 5KB minimum
      const maxFileSize = 50 * 1024 * 1024; // 50MB maximum

      if (fileSize < minFileSize) {
        return _ImageQualityCheck(
          isValid: false,
          warning: 'Ảnh quá nhỏ (${(fileSize / 1024).toStringAsFixed(1)}KB), có thể ảnh hưởng đến độ chính xác OCR'
        );
      }

      if (fileSize > maxFileSize) {
        return _ImageQualityCheck(
          isValid: false,
          warning: 'Ảnh quá lớn (${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB), có thể chậm xử lý'
        );
      }

      return _ImageQualityCheck(isValid: true, warning: null);
    } catch (e) {
      print('Lỗi khi kiểm tra chất lượng ảnh: $e');
      return _ImageQualityCheck(isValid: true, warning: null); // Không block nếu có lỗi
    }
  }

  /// Giải phóng tài nguyên OCR
  void dispose() {
    try {
      _latinOptimizedRecognizer?.close();
      _defaultRecognizer?.close();
    } catch (e) {
      print('Lỗi khi dispose OCR: $e');
    }
  }
}

/// Model để lưu kết quả kiểm tra chất lượng ảnh
class _ImageQualityCheck {
  final bool isValid;
  final String? warning;

  _ImageQualityCheck({required this.isValid, this.warning});
}
