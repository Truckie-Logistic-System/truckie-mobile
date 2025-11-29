import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart' as mlkit;

class OCRService {
  static final OCRService _instance = OCRService._internal();
  factory OCRService() => _instance;
  OCRService._internal();

  mlkit.TextRecognizer? _latinOptimizedRecognizer;  // Google ML Kit tối ưu cho Latin script
  mlkit.TextRecognizer? _defaultRecognizer;         // Google ML Kit mặc định (fallback)

  /// Khởi tạo OCR service với dual recognizer strategy
  void initialize() {
    // Khởi tạo Latin-optimized recognizer (tối ưu cho odometer)
    _latinOptimizedRecognizer = mlkit.TextRecognizer(script: mlkit.TextRecognitionScript.latin);

    // Khởi tạo default recognizer (fallback đảm bảo hoạt động)
    _defaultRecognizer = mlkit.TextRecognizer();
  }

  /// Trích xuất số từ ảnh odometer
  /// Ưu tiên: Google ML Kit Latin-optimized -> Default Fallback
  /// Trả về chuỗi số đầu tiên tìm thấy hoặc null nếu không tìm thấy
  Future<String?> extractOdometerReading(File imageFile) async {
    // Kiểm tra chất lượng ảnh trước khi xử lý OCR
    final qualityCheck = await _checkImageQuality(imageFile);
    if (!qualityCheck.isValid) {

      // Vẫn tiếp tục OCR nhưng với cảnh báo
    }

    // Thử với Latin-optimized recognizer trước (Google ML Kit tối ưu cho odometer)
    String? result = await _tryLatinOptimizedOCR(imageFile);

    if (result != null && result.isNotEmpty) {

      return result;
    }

    // Fallback: Thử với default recognizer

    result = await _tryDefaultOCR(imageFile);

    if (result != null && result.isNotEmpty) {

      return result;
    }

    return null;
  }

  /// Thử OCR với Google ML Kit tối ưu cho Latin script (odometer)
  Future<String?> _tryLatinOptimizedOCR(File imageFile) async {
    try {
      // Khởi tạo nếu chưa có
      _latinOptimizedRecognizer ??= mlkit.TextRecognizer(script: mlkit.TextRecognitionScript.latin);
      
      final inputImage = mlkit.InputImage.fromFile(imageFile);
      final recognizedText = await _latinOptimizedRecognizer!.processImage(inputImage);

      for (var block in recognizedText.blocks) {

        for (var line in block.lines) {

        }
      }
      
      // Tìm kiếm các pattern số trong text với phân tích theo vị trí
      final extractedNumbers = _extractNumbersWithContext(recognizedText);

      if (extractedNumbers.isNotEmpty) {
        // Trả về số phù hợp nhất (đã được sort theo priority trong _extractNumbersWithContext)
        final result = extractedNumbers.first;
        return result;
      }

      return null;
    } catch (e) {

      return null;
    }
  }

  /// Thử OCR với Google ML Kit mặc định (fallback)
  Future<String?> _tryDefaultOCR(File imageFile) async {
    try {
      // Khởi tạo nếu chưa có
      _defaultRecognizer ??= mlkit.TextRecognizer();
      
      final inputImage = mlkit.InputImage.fromFile(imageFile);
      final recognizedText = await _defaultRecognizer!.processImage(inputImage);

      for (var block in recognizedText.blocks) {

        for (var line in block.lines) {

        }
      }
      
      // Tìm kiếm các pattern số trong text với phân tích theo vị trí
      final extractedNumbers = _extractNumbersWithContext(recognizedText);

      if (extractedNumbers.isNotEmpty) {
        // Trả về số phù hợp nhất (đã được sort theo priority trong _extractNumbersWithContext)
        final result = extractedNumbers.first;

        return result;
      }

      return null;
    } catch (e) {

      return null;
    }
  }

  /// Trích xuất tất cả các số từ text với context
  List<String> _extractNumbersWithContext(mlkit.RecognizedText recognizedText) {
    Set<String> numbers = {};
    Map<String, int> numberPriority = {}; // Lưu độ ưu tiên của mỗi số
    
    // Các từ khóa odometer (ưu tiên cao nhất)
    final odometerKeywords = ['ODO', 'MILES', 'MILE', 'KM', 'KM/H', 'ODOMETER', 'START'];
    
    // **STRATEGY 1: Tìm block số lớn nhất (đó là odometer display)**
    // LCD odometer thường hiển thị số lớn nhất trong hình
    // Xử lý cả số nguyên và số thập phân (ví dụ: 874459.2)
    // RESPONSIVE FIX: Chấp nhận số từ 4-8 chữ số để phù hợp với các độ phân giải khác nhau
    String largestNumber = '';
    int largestNumberLength = 0;
    
    for (var block in recognizedText.blocks) {
      String blockText = block.text;
      // Tìm tất cả các số (bao gồm số thập phân)
      var numberMatches = RegExp(r'\d+[.,]?\d*').allMatches(blockText);
      for (var match in numberMatches) {
        String num = match.group(0)!;
        // Xóa dấu phẩy/chấm để tính độ dài
        String cleanNum = num.replaceAll(RegExp(r'[.,]'), '');
        
        // RESPONSIVE FIX: Chấp nhận số từ 4 chữ số (thay vì 5) để phù hợp với Small Phone
        if (cleanNum.length > largestNumberLength && cleanNum.length >= 4) {
          largestNumber = num; // FIX: Lưu số gốc (có dấu thập phân), không phải số đã xóa dấu
          largestNumberLength = cleanNum.length;
          
        }
      }
    }
    
    // RESPONSIVE FIX: Mở rộng range từ 5-7 thành 4-8 để chấp nhận các độ phân giải khác nhau
    if (largestNumber.isNotEmpty && largestNumberLength >= 4 && largestNumberLength <= 8) {
      numbers.add(largestNumber);
      numberPriority[largestNumber] = 95; // Ưu tiên rất cao
      
      
      // FIX: Nếu số lớn có 6 chữ số, thử tách thành số thập phân
      // Ví dụ: "874592" → "87459.2" (tách ở vị trí thứ 5)
      if (largestNumberLength == 6) {
        // Tách thành 2 phần: 5 chữ số + 1 chữ số (phần thập phân)
        String part1 = largestNumber.substring(0, 5);
        String part2 = largestNumber.substring(5);
        String decimalVersion = part1 + '.' + part2;
        
        numbers.add(decimalVersion);
        numberPriority[decimalVersion] = 96; // Ưu tiên cao hơn số nguyên
        
      }
    }
    
    // **STRATEGY 2: Tìm các dòng có chứa từ khóa odometer**
    for (var block in recognizedText.blocks) {
      for (var line in block.lines) {
        String lineText = line.text.toUpperCase();
        
        // Kiểm tra xem dòng có chứa từ khóa odometer không
        bool hasOdometerKeyword = odometerKeywords.any((keyword) => lineText.contains(keyword));
        
        if (hasOdometerKeyword) {

          // Trích xuất số từ dòng này
          String cleanLine = line.text.replaceAll(RegExp(r'[^\d\s.,\-]'), ' ');
          // FIX: GIỮ LẠI dấu phẩy/chấm (không xóa)
          // Ghép các số đơn lẻ (7 0 4 4 1 2 5 -> 7044125)
          String compactNumber = cleanLine.replaceAll(RegExp(r'\s+'), '');
          
          // RESPONSIVE FIX: Chấp nhận số từ 4 chữ số (thay vì 5) để phù hợp với Small Phone
          // Tính độ dài dựa trên số chữ số (bỏ dấu) để check
          String cleanNumForLength = compactNumber.replaceAll(RegExp(r'[.,]'), '');
          if (compactNumber.isNotEmpty && cleanNumForLength.length >= 4) {
            numbers.add(compactNumber);
            numberPriority[compactNumber] = 100; // Ưu tiên cao nhất

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

        // Tìm số trong block này và block kế bên (đặc biệt là block TIẾP THEO)
        for (int j = i - 1; j <= i + 2; j++) {
          if (j >= 0 && j < recognizedText.blocks.length) {
            var nearBlock = recognizedText.blocks[j];

            String cleanBlock = nearBlock.text.replaceAll(RegExp(r'[^\d\s.,\-]'), ' ');
            // FIX: GIỮ LẠI dấu phẩy/chấm (không xóa)
            // Chỉ xóa khoảng trắng
            String compactNumber = cleanBlock.replaceAll(RegExp(r'\s+'), '');
            
            // RESPONSIVE FIX: Chấp nhận số từ 4 chữ số (thay vì 5) để phù hợp với Small Phone
            // Tính độ dài dựa trên số chữ số (bỏ dấu) để check
            String cleanNumForLength = compactNumber.replaceAll(RegExp(r'[.,]'), '');
            if (compactNumber.isNotEmpty && cleanNumForLength.length >= 4) {
              numbers.add(compactNumber);
              numberPriority[compactNumber] = 90; // Ưu tiên cao

            }
          }
        }
      }
    }
    
    // Tìm tất cả các số dài - bao gồm cả trường hợp chỉ chụp số odometer
    var allNumbers = _extractNumbers(recognizedText.text);
    // RESPONSIVE FIX: Mở rộng range từ 5-7 thành 4-8 để chấp nhận các độ phân giải khác nhau
    for (var num in allNumbers) {
      if (num.length >= 4 && num.length <= 8) {
        numbers.add(num);
        numberPriority[num] = 50; // Ưu tiên trung bình
      }
    }
    
    // Xử lý trường hợp số bị tách rời (ví dụ: "873 15.6" thay vì "87315.6")
    // Tìm các cặp số gần nhau có thể ghép lại
    // FIX: Luôn thử ghép số tách rời, không chỉ khi numbers.isEmpty

    // FIX: Tìm "873" và "15.6" trong text gốc để ghép đúng thứ tự
    // Vì Set không giữ thứ tự, nên cần tìm lại từ text gốc
    String fullText = recognizedText.text;
    
    // Tìm tất cả số (bao gồm số có dấu thập phân) theo thứ tự xuất hiện
    var allNumbersOrdered = RegExp(r'\d+[.,]?\d*').allMatches(fullText)
        .map((m) => m.group(0)!)
        .toList();
    
    
    // Lọc số từ 2 chữ số trở lên (bao gồm số có dấu thập phân)
    var twoDigitNumbers = allNumbersOrdered.where((num) {
      String cleanNum = num.replaceAll(RegExp(r'[.,]'), '');
      return cleanNum.length >= 2 && cleanNum.length <= 4;
    }).toList();

    if (twoDigitNumbers.length >= 2) {
      // Thử ghép các số gần nhau
      for (int i = 0; i < twoDigitNumbers.length - 1; i++) {
        String num1 = twoDigitNumbers[i];
        String num2 = twoDigitNumbers[i + 1];
        
        // FIX: Xử lý ghép số có dấu thập phân
        // Nếu num1 không có dấu thập phân và num2 có dấu thập phân
        // → Ghép thành: num1 + num2 (ví dụ: "873" + "15.6" = "87315.6")
        String combined;
        if (!num1.contains(RegExp(r'[.,]')) && num2.contains(RegExp(r'[.,]'))) {
          // num1 là phần nguyên, num2 là phần thập phân
          combined = num1 + num2;
        } else if (!num1.contains(RegExp(r'[.,]')) && !num2.contains(RegExp(r'[.,]'))) {
          // Cả 2 đều không có dấu - kiểm tra nếu num2 < 200 (có thể là phần thập phân)
          try {
            int num2Value = int.parse(num2);
            if (num2Value < 200) {
              // num2 có thể là phần thập phân
              // Ví dụ: "873" + "156" → num2 = 156 → "15.6" → ghép thành "87315.6"
              // Cách: Chèn dấu thập phân vào vị trí thứ 2 từ cuối của num2
              String num2WithDecimal;
              if (num2.length >= 2) {
                // Chèn dấu trước chữ số cuối cùng
                // "156" → "15.6"
                num2WithDecimal = num2.substring(0, num2.length - 1) + '.' + num2.substring(num2.length - 1);
              } else {
                num2WithDecimal = num2;
              }
              combined = num1 + num2WithDecimal;
              
            } else {
              // Ghép bình thường
              combined = num1 + num2;
            }
          } catch (e) {
            combined = num1 + num2;
          }
        } else {
          // Ghép bình thường
          combined = num1 + num2;
        }
        
        String cleanCombined = combined.replaceAll(RegExp(r'[.,]'), '');
        
        
        // RESPONSIVE FIX: Mở rộng range từ 5-7 thành 4-8 để chấp nhận các độ phân giải khác nhau
        if (cleanCombined.length >= 4 && cleanCombined.length <= 8) {
          numbers.add(combined);
          // FIX: Tăng priority lên 95 (cao hơn 90 của "near keyword")
          // Vì số ghép (đặc biệt là có dấu thập phân) thường chính xác hơn
          numberPriority[combined] = 95;
          
        }
      }
    }
    
    // Nếu vẫn chưa có số nào, thử tìm số dài nhất (fallback cho ảnh cắt)
    if (numbers.isEmpty) {
      var allNumbers = _extractNumbers(recognizedText.text);
      // RESPONSIVE FIX: Chấp nhận số từ 3 chữ số trở lên (thay vì 4) để phù hợp với Small Phone
      var longNumbers = allNumbers.where((num) => num.length >= 3).toList();

      if (longNumbers.isNotEmpty) {
        // Sắp xếp theo độ dài giảm dần
        longNumbers.sort((a, b) => b.length.compareTo(a.length));

        // RESPONSIVE FIX: Mở rộng range từ 4-8 thành 3-8 để chấp nhận các độ phân giải khác nhau
        var validLongNumbers = longNumbers.where((num) {
          String clean = num.replaceAll(RegExp(r'[.,]'), '');
          return clean.length >= 3 && clean.length <= 8 && clean != '0' && clean != '00' && clean != '000';
        }).toList();

        if (validLongNumbers.isNotEmpty) {
          numbers.add(validLongNumbers.first);
          numberPriority[validLongNumbers.first] = 25; // Ưu tiên thấp nhưng vẫn khả thi

        } else if (longNumbers.isNotEmpty) {
          // Nếu không có số hợp lệ, lấy số dài nhất bất kể
          numbers.add(longNumbers.first);
          numberPriority[longNumbers.first] = 20; // Ưu tiên rất thấp

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
      
      // Nếu cùng độ ưu tiên, so sánh giá trị số (ưu tiên số lớn hơn)
      // FIX: 873156 > 1181, nên 873156 sẽ được chọn
      try {
        int intA = int.parse(a);
        int intB = int.parse(b);
        if (intA != intB) {
          return intB.compareTo(intA); // Số lớn hơn lên trước
        }
      } catch (e) {
        // Nếu không parse được, so sánh độ dài
      }
      
      // Fallback: ưu tiên số dài hơn
      return b.length.compareTo(a.length);
    });
    
    
    if (sortedNumbers.isNotEmpty) {
      
    }
    
    return sortedNumbers;
  }

  /// Trích xuất tất cả các số từ text
  List<String> _extractNumbers(String text) {
    // Làm sạch text - loại bỏ các ký tự đặc biệt nhưng giữ lại số, khoảng trắng, dấu phẩy/chấm
    String cleanText = text.replaceAll(RegExp(r'[^\d\s.,\-]'), ' ');
    
    // FIX: Không ghép các số đơn lẻ - để chúng riêng biệt
    // Vì chúng ta sẽ ghép chúng sau trong _extractNumbersWithContext
    // Ví dụ: "873 15.6" → ["873", "15.6"] → ghép thành "87315.6"
    
    // Tìm các pattern số khác nhau (GIỮ LẠI dấu thập phân)
    final List<RegExp> patterns = [
      RegExp(r'\b\d+[.,]\d+\b'),       // Số có dấu phẩy/chấm (ưu tiên cao nhất)
      RegExp(r'\b\d{5,8}\b'),           // Số 5-8 chữ số (odometer thông thường)
      RegExp(r'\b\d{4,}\b'),           // Số từ 4 chữ số trở lên
      RegExp(r'\b\d+\b'),              // Bất kỳ số nào (bao gồm 2-3 chữ số)
    ];
    
    Set<String> numbers = {};
    
    // Tìm từ text gốc (giữ lại dấu phẩy/chấm)
    for (RegExp pattern in patterns) {
      final matches = pattern.allMatches(cleanText);
      numbers.addAll(matches.map((match) => match.group(0)!));
    }
    
    // Nếu không tìm thấy số nào, thử tìm bất kỳ số nào (bao gồm dấu thập phân)
    if (numbers.isEmpty) {
      // FIX: Giữ lại dấu thập phân trong fallback
      final directMatches = RegExp(r'\d+[.,]?\d*').allMatches(text);
      numbers.addAll(directMatches.map((match) => match.group(0)!));
    }

    return numbers.toList();
  }

  /// Tìm số phù hợp nhất cho odometer reading
  String _findBestOdometerNumber(List<String> numbers) {
    if (numbers.isEmpty) return '';
    
    // Lọc các số hợp lệ (4-8 chữ số) - mở rộng để bao gồm trường hợp chỉ chụp số
    var validNumbers = numbers.where((num) {
      String clean = num.replaceAll(RegExp(r'[.,]'), '');
      return clean.length >= 4 && clean.length <= 8;
    }).toList();
    
    // Nếu không có số hợp lệ, lấy số dài nhất
    if (validNumbers.isEmpty) {
      validNumbers = numbers;
    }
    
    // Sắp xếp theo độ ưu tiên
    validNumbers.sort((a, b) {
      String cleanA = a.replaceAll(RegExp(r'[.,]'), '');
      String cleanB = b.replaceAll(RegExp(r'[.,]'), '');
      
      // Ưu tiên 1: Số có 6-7 chữ số (odometer phổ biến nhất)
      bool aIsOdometerLength = cleanA.length >= 6 && cleanA.length <= 7;
      bool bIsOdometerLength = cleanB.length >= 6 && cleanB.length <= 7;
      
      if (aIsOdometerLength && !bIsOdometerLength) return -1;
      if (!aIsOdometerLength && bIsOdometerLength) return 1;
      
      // Ưu tiên 2: Số lớn hơn 100000 (odometer thường > 100000 km)
      // FIX: Tăng threshold từ 10000 lên 100000 để ưu tiên số lớn hơn (873156 > 1181)
      try {
        int intA = int.parse(cleanA);
        int intB = int.parse(cleanB);
        bool aIsLarge = intA >= 100000;
        bool bIsLarge = intB >= 100000;
        
        if (aIsLarge && !bIsLarge) return -1;
        if (!aIsLarge && bIsLarge) return 1;
        
        // Nếu cùng category (cả 2 >= 100000 hoặc cả 2 < 100000), so sánh giá trị
        // Ưu tiên số lớn hơn (873156 > 1181)
        if (intA != intB) {
          return intB.compareTo(intA);
        }
      } catch (e) {
        // Bỏ qua nếu không parse được
      }
      
      // Ưu tiên 3: Số dài hơn (trong khoảng 4-8)
      if (cleanA.length != cleanB.length) {
        return cleanB.length.compareTo(cleanA.length);
      }
      
      // Ưu tiên 4: Số có nhiều chữ số hơn (ưu tiên số thực, không phải số 0)
      int aNonZeroCount = cleanA.replaceAll('0', '').length;
      int bNonZeroCount = cleanB.replaceAll('0', '').length;
      
      if (aNonZeroCount != bNonZeroCount) {
        return bNonZeroCount.compareTo(aNonZeroCount);
      }
      
      return 0;
    });
    
    // Làm sạch và format số tốt nhất
    return _cleanNumber(validNumbers.first);
  }

  /// Làm sạch số (chuẩn hóa dấu thập phân)
  String _cleanNumber(String number) {
    // FIX: Giữ lại dấu thập phân, chỉ chuẩn hóa từ dấu phẩy thành dấu chấm
    // Ví dụ: "873,15.6" → "873.15.6" (nếu có 2 dấu) hoặc "873,15" → "873.15"
    // Chuyển dấu phẩy thành dấu chấm
    String normalized = number.replaceAll(',', '.');
    
    // Xóa dấu chấm thừa (chỉ giữ lại 1 dấu chấm)
    // Ví dụ: "873.15.6" → "873.156" (nếu có 2 dấu chấm)
    int lastDotIndex = normalized.lastIndexOf('.');
    if (lastDotIndex != -1) {
      // Có dấu chấm, xóa tất cả dấu chấm khác
      String beforeDot = normalized.substring(0, lastDotIndex).replaceAll('.', '');
      String afterDot = normalized.substring(lastDotIndex + 1);
      return beforeDot + '.' + afterDot;
    }
    
    return normalized;
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

      return _ImageQualityCheck(isValid: true, warning: null); // Không block nếu có lỗi
    }
  }

  /// Giải phóng tài nguyên OCR
  void dispose() {
    try {
      _latinOptimizedRecognizer?.close();
      _defaultRecognizer?.close();
    } catch (e) {

    }
  }
}

/// Model để lưu kết quả kiểm tra chất lượng ảnh
class _ImageQualityCheck {
  final bool isValid;
  final String? warning;

  _ImageQualityCheck({required this.isValid, this.warning});
}
