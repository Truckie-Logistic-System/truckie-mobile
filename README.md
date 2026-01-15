<div align="center">

# 🚛 Truckie Driver App

### Real-Time GPS Tracking & Order Management for Drivers

[![Flutter](https://img.shields.io/badge/Flutter-3.8-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.8-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev/)
[![Android](https://img.shields.io/badge/Android-5.0+-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://www.android.com/)
[![License](https://img.shields.io/badge/License-Educational-blue?style=for-the-badge)](LICENSE)

*A professional mobile application for truck drivers with real-time GPS tracking, order management, and seamless communication with the logistics platform.*

[Download APK](#-building-apk) • [Backend API](https://truckie-be-e3bre6hmfqhcabba.southeastasia-01.azurewebsites.net/swagger-ui/index.html) • [Web Portal](https://truckie.vercel.app/) • [Report Bug](#-contributing)

</div>

---

## 📋 Table of Contents

- [About The Project](#-about-the-project)
- [Key Features](#-key-features)
- [Tech Stack](#-tech-stack)
- [Architecture](#-architecture)
- [Getting Started](#-getting-started)
- [Building APK](#-building-apk)
- [Project Structure](#-project-structure)
- [Contributing](#-contributing)
- [License](#-license)

---

## 🎯 About The Project

**Truckie Driver App** is a mobile application built with Flutter for truck drivers working with the Truckie logistics platform. The app provides real-time GPS tracking, order management, and route navigation, enabling drivers to efficiently complete deliveries while staying connected with dispatchers and customers.

### 🎓 Capstone Project Details
- **University:** FPT University
- **Semester:** Fall 2025 (9/2025 - 12/2025)
- **Team Size:** 5 members
- **Development Duration:** 4 months

### 💡 Design Philosophy

- **Driver-Centric:** Simplified UI optimized for on-the-road usage
- **Offline-Ready:** Local storage for order data and offline tracking
- **Battery Efficient:** Optimized GPS tracking to minimize battery drain
- **Responsive Design:** Adaptive layouts for different screen sizes
- **Native Performance:** Leveraging Flutter's native compilation

---

## ⭐ Key Features

### 📍 Real-Time GPS Tracking
- **Live Location Updates** - Automatic position reporting via WebSocket
- **Background Tracking** - Continue tracking even when app is minimized
- **Route Navigation** - Turn-by-turn directions with VietMap integration
- **Off-Route Detection** - Automatic alerts for route deviations
- **Battery Optimization** - Intelligent tracking intervals to preserve battery

### 📦 Order Management
- **Active Assignments** - View current and upcoming delivery orders
- **Order Details** - Complete shipment information and delivery instructions
- **Photo Verification** - Capture delivery proof with camera integration
- **Digital Signatures** - Collect recipient signatures for POD (Proof of Delivery)
- **Seal Tracking** - Record container seal numbers with OCR support
- **Status Updates** - Real-time order status synchronization

### 🚚 Driver Operations
- **Daily Dashboard** - Overview of earnings, trips, and performance
- **Trip History** - Complete record of past deliveries
- **Earnings Tracking** - Real-time payment and commission information
- **Vehicle Information** - Assigned vehicle details and maintenance alerts
- **Profile Management** - Update personal information and documents

### 🔔 Communication
- **Push Notifications** - Instant alerts for new orders and updates
- **In-App Messaging** - Communication with dispatchers and support
- **Emergency Contact** - Quick access to support hotline
- **Issue Reporting** - Report problems or incidents during delivery

### 🎨 UI/UX Features
- **Responsive Design** - Adaptive layouts for phones and tablets
- **Dark Mode Support** - Eye-friendly interface for night driving
- **Multilingual** - Vietnamese and English language support
- **Offline Mode** - Core features work without internet connection
- **Accessibility** - Large touch targets and readable fonts

---

## 🛠️ Tech Stack

### Core Framework
| Technology | Version | Purpose |
|------------|---------|---------|
| Flutter | 3.8+ | Cross-platform mobile framework |
| Dart | 3.8+ | Programming language |
| Android SDK | 21+ (Android 5.0+) | Target platform |

### State Management
| Technology | Purpose |
|------------|---------|
| Provider | State management and dependency injection |
| GetIt | Service locator for DI |
| Equatable | Value equality for state objects |

### Networking & Data
| Technology | Purpose |
|------------|---------|
| Dio | HTTP client with interceptors |
| STOMP Dart Client | WebSocket communication |
| JSON Serialization | Data serialization/deserialization |
| SharedPreferences | Local key-value storage |
| Hive | Local NoSQL database |
| SQLite (sqflite) | Structured local database |
| Flutter Secure Storage | Encrypted storage for tokens |

### Maps & Location
| Technology | Purpose |
|------------|---------|
| VietMap Flutter GL | Primary map provider |
| VietMap Plugin | Route calculation & geocoding |
| Google Maps Flutter | Alternative map provider |
| Geolocator | GPS positioning and tracking |
| Permission Handler | Location permission management |

### Media & Recognition
| Technology | Purpose |
|------------|---------|
| Image Picker | Camera and gallery access |
| Flutter Image Compress | Image optimization |
| Google ML Kit | Text recognition (OCR) |
| ML Kit Face Detection | Face detection for photos |

### UI Components
| Technology | Purpose |
|------------|---------|
| Cached Network Image | Efficient image loading |
| Shimmer | Loading placeholders |
| Google Fonts | Custom typography |
| Flutter ScreenUtil | Responsive sizing |
| FL Chart | Data visualization |
| Flutter SVG | Vector graphics |

### System Integration
| Technology | Purpose |
|------------|---------|
| Flutter Local Notifications | Push notifications |
| Android Alarm Manager | Background task scheduling |
| Audio Players | Notification sounds |
| Battery Plus | Battery status monitoring |
| Network Info Plus | Network connectivity info |
| Connectivity Plus | Network state monitoring |
| Internet Connection Checker | Connection validation |

---

## 🏗 Architecture

The app follows **Clean Architecture** principles with clear separation of concerns:

```
┌───────────────────────────────────────────────────────────────┐
│                     PRESENTATION LAYER                         │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐        │
│  │    Pages    │   │   Widgets   │   │ ViewModels  │        │
│  │  (Screens)  │   │  (UI Comp)  │   │  (Provider) │        │
│  └──────┬──────┘   └──────┬──────┘   └──────┬──────┘        │
└─────────┼──────────────────┼──────────────────┼───────────────┘
          │                  │                  │
          └──────────────────┼──────────────────┘
                             │
┌────────────────────────────▼───────────────────────────────────┐
│                       DOMAIN LAYER                             │
│   ┌──────────────────┐           ┌──────────────────┐        │
│   │   Use Cases      │           │    Entities      │        │
│   │(Business Logic)  │           │ (Domain Models)  │        │
│   └────────┬─────────┘           └────────┬─────────┘        │
└────────────┼──────────────────────────────┼────────────────────┘
             │                              │
             └──────────────┬───────────────┘
                            │
┌───────────────────────────▼────────────────────────────────────┐
│                        DATA LAYER                              │
│   ┌─────────────┐   ┌──────────────┐   ┌─────────────┐       │
│   │Repositories │   │ Data Sources │   │   Models    │       │
│   │ (Interface) │   │(Remote/Local)│   │   (DTOs)    │       │
│   └──────┬──────┘   └──────┬───────┘   └──────┬──────┘       │
└──────────┼──────────────────┼──────────────────┼──────────────┘
           │                  │                  │
           │                  │                  │
    ┌──────▼──────┐    ┌──────▼──────┐    ┌─────▼──────┐
    │     API     │    │  WebSocket  │    │  Database  │
    │   Service   │    │   (STOMP)   │    │   (Hive)   │
    └─────────────┘    └─────────────┘    └────────────┘
```

### Architecture Layers

1. **Presentation Layer** (`lib/presentation/`)
   - Pages: Full-screen UI components
   - Widgets: Reusable UI components
   - Providers: State management with Provider pattern

2. **Domain Layer** (`lib/domain/`)
   - Entities: Core business models
   - Use Cases: Business logic operations
   - Repository Interfaces: Data access contracts

3. **Data Layer** (`lib/data/`)
   - Models: Data transfer objects (DTOs)
   - Repositories: Implementation of domain interfaces
   - Data Sources: Remote API and local database access

4. **Core Layer** (`lib/core/`)
   - Constants: App-wide constants
   - Utils: Helper functions and utilities
   - Services: Shared services (network, storage, location)

---

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK**: 3.8.1 or higher
- **Dart SDK**: 3.8.1 or higher (included with Flutter)
- **Android Studio** or **VS Code** with Flutter extension
- **Android Device/Emulator** running Android 5.0 (API 21) or higher
- **Git**

### Installation

1. **Install Flutter**
   
   Follow the official guide: [Flutter Installation](https://docs.flutter.dev/get-started/install)
   
   Verify installation:
   ```bash
   flutter doctor
   ```

2. **Clone the repository**
   ```bash
   git clone https://github.com/Truckie-Logistic-System/truckie-mobile.git
   cd truckie-mobile
   ```

3. **Install dependencies**
   ```bash
   flutter pub get
   ```

4. **Configure API endpoints**
   
   Update API base URL in `lib/core/constants/api_constants.dart`:
   ```dart
   static const String baseUrl = 'https://truckie-be-e3bre6hmfqhcabba.southeastasia-01.azurewebsites.net';
   ```

5. **Run the app**
   
   Connect your device or start an emulator, then:
   ```bash
   flutter run
   ```
   
   For release mode:
   ```bash
   flutter run --release
   ```

### Troubleshooting

| Issue | Solution |
|-------|----------|
| **Flutter doctor issues** | Follow suggested fixes from `flutter doctor` output |
| **Dependencies conflict** | Run `flutter pub upgrade` or `flutter clean && flutter pub get` |
| **Build errors** | Try `flutter clean && flutter pub get && flutter run` |
| **GPS not working** | Ensure location permissions are granted in device settings |
| **Map not loading** | Check VietMap API key configuration |

---

## 📦 Building APK

### Build Release APK

Build a release APK for distribution:

```bash
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build release APK
flutter build apk --release
```

The APK will be generated at: `build/app/outputs/flutter-apk/app-release.apk`

### Build Split APKs (Smaller file size)

Build separate APKs for different CPU architectures:

```bash
flutter build apk --split-per-abi --release
```

This generates three APKs:
- `app-armeabi-v7a-release.apk` (32-bit ARM)
- `app-arm64-v8a-release.apk` (64-bit ARM - most common)
- `app-x86_64-release.apk` (64-bit x86 - emulators)

### Build Options

```bash
# Build with specific version
flutter build apk --release --build-name=1.0.0 --build-number=1

# Build with obfuscation (more secure)
flutter build apk --release --obfuscate --split-debug-info=./debug-info

# Build for specific architecture only
flutter build apk --target-platform android-arm64 --release
```

### App Signing (For Production)

For production releases, configure app signing:

1. **Generate keystore**:
   ```bash
   keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. **Create `android/key.properties`**:
   ```properties
   storePassword=<your-store-password>
   keyPassword=<your-key-password>
   keyAlias=upload
   storeFile=/path/to/upload-keystore.jks
   ```

3. **Update `android/app/build.gradle`**:
   ```gradle
   def keystoreProperties = new Properties()
   def keystorePropertiesFile = rootProject.file('key.properties')
   if (keystorePropertiesFile.exists()) {
       keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
   }
   
   android {
       signingConfigs {
           release {
               keyAlias keystoreProperties['keyAlias']
               keyPassword keystoreProperties['keyPassword']
               storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
               storePassword keystoreProperties['storePassword']
           }
       }
       buildTypes {
           release {
               signingConfig signingConfigs.release
           }
       }
   }
   ```

4. **Build signed APK**:
   ```bash
   flutter build apk --release
   ```

### Testing the APK

```bash
# Install APK on connected device
flutter install

# Or manually install
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## 📁 Project Structure

```
truckie-mobile/
├── android/                    # Android native code
├── ios/                        # iOS native code (future)
├── assets/                     # Static assets
│   ├── images/                 # Image files
│   ├── icons/                  # Icon files
│   └── sounds/                 # Notification sounds
├── lib/
│   ├── app/                    # App initialization
│   │   └── app.dart            # Root app widget
│   ├── core/                   # Core utilities
│   │   ├── constants/          # App constants
│   │   ├── errors/             # Error handling
│   │   ├── network/            # Network configuration
│   │   ├── services/           # Core services
│   │   ├── theme/              # App theming
│   │   └── utils/              # Utility functions
│   ├── data/                   # Data layer
│   │   ├── datasources/        # Remote & local data sources
│   │   ├── models/             # Data models (DTOs)
│   │   └── repositories/       # Repository implementations
│   ├── domain/                 # Domain layer
│   │   ├── entities/           # Business entities
│   │   ├── repositories/       # Repository interfaces
│   │   └── usecases/           # Business logic use cases
│   ├── presentation/           # Presentation layer
│   │   ├── pages/              # Screen pages
│   │   │   ├── auth/           # Authentication screens
│   │   │   ├── home/           # Home dashboard
│   │   │   ├── orders/         # Order management
│   │   │   ├── tracking/       # GPS tracking
│   │   │   ├── profile/        # Driver profile
│   │   │   └── ...             # Other screens
│   │   ├── providers/          # State management providers
│   │   └── widgets/            # Reusable widgets
│   │       ├── common/         # Common widgets
│   │       ├── responsive/     # Responsive components
│   │       └── ...             # Feature-specific widgets
│   └── main.dart               # Application entry point
├── test/                       # Unit tests
├── pubspec.yaml                # Dependencies and assets
├── analysis_options.yaml       # Linting rules
└── README.md                   # This file
```

---

## 🎨 Responsive Design

The app implements comprehensive responsive design for optimal experience across devices:

### Screen Size Support

| Category | Size Range | Target Devices |
|----------|------------|----------------|
| Extra Small | < 360dp | Small phones |
| Small | 360dp - 480dp | Standard phones |
| Medium | 480dp - 768dp | Large phones, small tablets |
| Large | 768dp - 1024dp | Tablets |
| Extra Large | > 1024dp | Large tablets |

### Responsive Utilities

- **ResponsiveSizeUtils**: Automatic scaling based on screen dimensions
- **Responsive Extensions**: `.w`, `.h`, `.sp`, `.r` for responsive sizing
- **ResponsiveLayoutBuilder**: Device type detection and conditional rendering
- **ResponsiveGrid**: Adaptive grid layouts
- **ResponsiveScaffold**: Screen-size aware scaffolding
- **SystemUiService**: Proper handling of system UI overlays

---

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Standards
- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Use meaningful variable and function names
- Write unit tests for business logic
- Document public APIs with DartDoc comments
- Maintain clean architecture separation

---

## 📄 License

This project is developed for educational purposes as part of FPT University's Capstone Project program.

---

<div align="center">

### ⭐ Star this repository if you find it helpful!

**Built with ❤️ by FPT University Students**

[Download APK](#-building-apk) • [Report Bug](https://github.com/Truckie-Logistic-System/truckie-mobile/issues) • [Request Feature](https://github.com/Truckie-Logistic-System/truckie-mobile/issues)

</div>
