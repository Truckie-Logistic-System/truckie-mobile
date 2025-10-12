# Truckie Driver App

Transportation Management System with Real-Time GPS Order Tracking for Drivers.

## Responsive Design Implementation

The app has been enhanced with comprehensive responsive design features to ensure optimal user experience across different screen sizes and device types:

### Responsive Utilities

1. **ResponsiveSizeUtils**: A utility class that provides methods for responsive sizing based on screen dimensions.
   - Automatically scales UI elements based on screen size
   - Provides consistent sizing across different devices
   - Handles font scaling appropriately

2. **Responsive Extensions**: Extension methods for easier usage of responsive sizing.
   - `.w` - Responsive width
   - `.h` - Responsive height
   - `.sp` - Responsive font size
   - `.r` - Responsive value based on shortest dimension

3. **ResponsiveLayoutBuilder**: A widget that provides sizing information for building responsive layouts.
   - Detects device type (phone, tablet, desktop)
   - Provides orientation information
   - Enables conditional rendering based on screen size

4. **ResponsiveGrid**: A grid layout that adapts to different screen sizes.
   - Automatically adjusts columns based on available width
   - Provides consistent spacing between items
   - Supports different layouts for different screen sizes

5. **ResponsiveScaffold**: A scaffold that adapts to different screen sizes.
   - Applies appropriate padding based on screen size
   - Handles safe areas properly
   - Provides consistent layout across different devices

6. **SystemUiService**: A service that handles system UI overlays properly.
   - Ensures content isn't hidden behind system bars
   - Provides consistent padding for system insets
   - Handles navigation bar on older Android devices

### Responsive Design Principles Applied

- **Flexible Layouts**: UI elements adapt to available space
- **Appropriate Text Scaling**: Font sizes scale appropriately based on screen size
- **Consistent Spacing**: Padding and margins adjust based on screen size
- **Device-Specific Layouts**: Different layouts for phones and tablets
- **Orientation Support**: UI adapts to both portrait and landscape orientations
- **System Insets Handling**: Content isn't hidden behind system bars or notches

### Screen Size Categories

- **Extra Small**: < 360dp (Small phones)
- **Small**: 360dp - 480dp (Standard phones)
- **Medium**: 480dp - 768dp (Large phones, small tablets)
- **Large**: 768dp - 1024dp (Tablets)
- **Extra Large**: > 1024dp (Large tablets, desktops)

## Features

- Real-time GPS tracking of deliveries
- Order management
- Driver profile and information
- Authentication and security
- Delivery history and statistics

## Getting Started

This project is a Flutter application for the driver-side of the Truckie Transportation Management System.

### Prerequisites

- Flutter SDK
- Android Studio / VS Code
- Android / iOS device or emulator

### Installation

1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Run `flutter run` to start the app

## Architecture

The app follows a clean architecture approach with the following layers:

- **Presentation**: UI components and ViewModels
- **Domain**: Business logic and use cases
- **Data**: Data sources and repositories
- **Core**: Shared utilities and services

## Dependencies

- Provider for state management
- Dio for network requests
- Google Maps Flutter for maps
- Geolocator for location services
- SharedPreferences for local storage
