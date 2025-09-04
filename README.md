# Truckie Driver - Ứng dụng Quản lý Vận tải với GPS Tracking

![Truckie Driver Logo](assets/images/logo.png)

Truckie Driver là ứng dụng dành cho tài xế trong hệ thống quản lý vận tải, cho phép theo dõi đơn hàng, cập nhật trạng thái giao hàng và theo dõi vị trí thời gian thực bằng GPS.

## Mục lục

- [Tổng quan](#tổng-quan)
- [Kiến trúc](#kiến-trúc)
- [Yêu cầu hệ thống](#yêu-cầu-hệ-thống)
- [Cài đặt](#cài-đặt)
- [Khởi động](#khởi-động)
- [Tính năng](#tính-năng)
- [Hướng dẫn phát triển](#hướng-dẫn-phát-triển)
- [Giấy phép](#giấy-phép)

## Tổng quan

Truckie Driver là phần mềm dành cho tài xế trong hệ thống quản lý vận tải, được phát triển bằng Flutter với kiến trúc MVVM (Model-View-ViewModel). Ứng dụng cho phép tài xế:

- Xem danh sách đơn hàng cần giao
- Cập nhật trạng thái đơn hàng (đã lấy hàng, đang giao, đã giao, v.v.)
- Theo dõi vị trí thời gian thực bằng GPS
- Xem thông tin chi tiết về đơn hàng và khách hàng
- Nhận thông báo về đơn hàng mới

## Kiến trúc

Dự án được tổ chức theo mô hình MVVM (Model-View-ViewModel) với cấu trúc thư mục như sau:

```
lib/
  ├── app/                  # Widget gốc và router
  │   ├── app.dart
  │   └── app_router.dart
  │
  ├── core/                 # Thành phần cốt lõi
  │   ├── constants/        # Các hằng số
  │   ├── errors/           # Xử lý lỗi
  │   ├── network/          # Xử lý mạng
  │   ├── services/         # Các dịch vụ
  │   └── utils/            # Tiện ích
  │
  ├── data/                 # Tầng dữ liệu
  │   ├── datasources/      # Nguồn dữ liệu
  │   │   ├── local/        # Dữ liệu cục bộ
  │   │   └── remote/       # Dữ liệu từ API
  │   ├── models/           # Mô hình dữ liệu
  │   └── repositories/     # Triển khai repository
  │
  ├── domain/               # Tầng nghiệp vụ
  │   ├── entities/         # Đối tượng nghiệp vụ
  │   ├── repositories/     # Interface repository
  │   └── usecases/         # Các trường hợp sử dụng
  │
  ├── presentation/         # Tầng giao diện
  │   ├── common_widgets/   # Widget dùng chung
  │   ├── theme/            # Theme ứng dụng
  │   └── features/         # Các tính năng
  │       ├── auth/         # Xác thực
  │       ├── home/         # Trang chủ
  │       ├── orders/       # Quản lý đơn hàng
  │       └── delivery/     # Giao hàng
  │
  ├── l10n/                 # Localization
  │
  └── main.dart             # Điểm khởi đầu ứng dụng
```

### Mô hình MVVM

- **Model**: Đại diện bởi các entity trong thư mục `domain/entities` và các model trong `data/models`
- **View**: Các màn hình trong thư mục `presentation/features/*/screens`
- **ViewModel**: Các lớp trong thư mục `presentation/features/*/viewmodels`

### Nguyên tắc thiết kế

- **Dependency Injection**: Sử dụng `get_it` để quản lý dependency
- **Repository Pattern**: Tách biệt logic truy cập dữ liệu
- **Clean Architecture**: Tách biệt các tầng để dễ bảo trì và mở rộng
- **Separation of Concerns**: Mỗi thành phần có trách nhiệm riêng biệt

## Yêu cầu hệ thống

- Flutter SDK: ^3.8.1
- Dart SDK: ^3.8.1
- Android SDK: API 21+ (Android 5.0+)
- iOS: iOS 12.0+

## Cài đặt

1. **Clone repository**:
   ```bash
   git clone https://github.com/your-username/capstone_mobile.git
   cd capstone_mobile
   ```

2. **Cài đặt dependencies**:
   ```bash
   flutter pub get
   ```

3. **Cấu hình Google Maps API Key**:
   - Tạo API key từ [Google Cloud Console](https://console.cloud.google.com/)
   - Thay thế `YOUR_API_KEY_HERE` trong `android/app/src/main/AndroidManifest.xml`
   - Thêm API key vào `ios/Runner/AppDelegate.swift` (nếu cần)

## Khởi động

### Sử dụng IDE (Android Studio/VS Code)

1. Mở dự án trong Android Studio hoặc VS Code
2. Chọn thiết bị hoặc máy ảo
3. Nhấn nút Run (▶️)

### Sử dụng Command Line

1. **Liệt kê các máy ảo có sẵn**:
   ```bash
   flutter emulators
   ```

2. **Khởi động máy ảo**:
   ```bash
   flutter emulators --launch <emulator_id>
   ```
   Ví dụ: `flutter emulators --launch Pixel_7_Pro`

3. **Chạy ứng dụng**:
   ```bash
   flutter run
   ```

## Tính năng

- **Xác thực**: Đăng nhập, đăng xuất
- **Trang chủ**: Xem tổng quan đơn hàng, thống kê
- **Đơn hàng**: Xem danh sách và chi tiết đơn hàng
- **Giao hàng**: Theo dõi quá trình giao hàng, cập nhật trạng thái
- **Bản đồ**: Xem vị trí và chỉ đường

## Hướng dẫn phát triển

### Thêm tính năng mới

1. Tạo entity trong `domain/entities` (nếu cần)
2. Tạo repository interface trong `domain/repositories`
3. Tạo use case trong `domain/usecases`
4. Triển khai repository trong `data/repositories`
5. Tạo ViewModel trong `presentation/features/your_feature/viewmodels`
6. Tạo màn hình trong `presentation/features/your_feature/screens`
7. Cập nhật router trong `app/app_router.dart`

### Quy ước đặt tên

- **Tệp**: snake_case (ví dụ: `home_screen.dart`)
- **Lớp**: PascalCase (ví dụ: `HomeScreen`)
- **Biến/Hàm**: camelCase (ví dụ: `getUserData()`)
- **Hằng số**: UPPER_SNAKE_CASE (ví dụ: `API_BASE_URL`)

### Kiểm thử

- **Unit Tests**: `test/domain/usecases/`
- **Widget Tests**: `test/presentation/`
- **Integration Tests**: `integration_test/`

Chạy kiểm thử:
```bash
flutter test
```

## Giấy phép

© 2025 Truckie. Bản quyền đã đăng ký.
