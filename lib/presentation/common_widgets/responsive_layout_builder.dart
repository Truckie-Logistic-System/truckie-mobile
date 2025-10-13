import 'package:flutter/material.dart';

/// Widget builder function type for responsive layouts
typedef ResponsiveWidgetBuilder =
    Widget Function(BuildContext context, SizingInformation sizingInformation);

/// Sizing information for responsive layouts
class SizingInformation {
  final Size screenSize;
  final Size localWidgetSize;
  final DeviceScreenType deviceScreenType;
  final Orientation orientation;

  SizingInformation({
    required this.screenSize,
    required this.localWidgetSize,
    required this.deviceScreenType,
    required this.orientation,
  });

  bool get isPhone => deviceScreenType == DeviceScreenType.phone;
  bool get isTablet => deviceScreenType == DeviceScreenType.tablet;
  bool get isDesktop => deviceScreenType == DeviceScreenType.desktop;
  bool get isPortrait => orientation == Orientation.portrait;
  bool get isLandscape => orientation == Orientation.landscape;
}

/// Device screen type enum
enum DeviceScreenType { phone, tablet, desktop }

/// A responsive layout builder that provides sizing information
class ResponsiveLayoutBuilder extends StatelessWidget {
  final ResponsiveWidgetBuilder builder;

  const ResponsiveLayoutBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaQuery = MediaQuery.of(context);
        final screenSize = mediaQuery.size;
        final orientation = mediaQuery.orientation;
        final localWidgetSize = Size(
          constraints.maxWidth,
          constraints.maxHeight,
        );

        // Determine device screen type based on width
        DeviceScreenType deviceScreenType;
        if (screenSize.width < 600) {
          deviceScreenType = DeviceScreenType.phone;
        } else if (screenSize.width < 900) {
          deviceScreenType = DeviceScreenType.tablet;
        } else {
          deviceScreenType = DeviceScreenType.desktop;
        }

        return builder(
          context,
          SizingInformation(
            screenSize: screenSize,
            localWidgetSize: localWidgetSize,
            deviceScreenType: deviceScreenType,
            orientation: orientation,
          ),
        );
      },
    );
  }
}

/// A responsive layout that provides different widgets based on screen size
class ScreenTypeLayout extends StatelessWidget {
  final Widget? phone;
  final Widget? tablet;
  final Widget? desktop;
  final Widget? watch;

  const ScreenTypeLayout({
    super.key,
    this.phone,
    this.tablet,
    this.desktop,
    this.watch,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      builder: (context, sizingInformation) {
        // If we're on a watch size device (smaller than 300 width)
        if (sizingInformation.screenSize.width < 300) {
          // If we have a watch layout then display that
          if (watch != null) return watch!;
          // If no watch layout is supplied, use phone
          if (phone != null) return phone!;
        }

        // If we're on a phone
        if (sizingInformation.deviceScreenType == DeviceScreenType.phone) {
          if (phone != null) return phone!;
        }

        // If we're on a tablet
        if (sizingInformation.deviceScreenType == DeviceScreenType.tablet) {
          // Return a tablet layout if we have one
          if (tablet != null) return tablet!;
          // Return a phone layout as a fallback if no tablet layout
          if (phone != null) return phone!;
        }

        // If we're on a desktop
        if (sizingInformation.deviceScreenType == DeviceScreenType.desktop) {
          // Return a desktop layout if we have one
          if (desktop != null) return desktop!;
          // Return a tablet layout as a fallback if we have one
          if (tablet != null) return tablet!;
          // Return a phone layout as a fallback if no desktop or tablet layout
          if (phone != null) return phone!;
        }

        // Return phone layout as default fallback
        return phone ?? const SizedBox();
      },
    );
  }
}

/// A responsive layout that provides different widgets based on orientation
class OrientationLayout extends StatelessWidget {
  final Widget? portrait;
  final Widget? landscape;

  const OrientationLayout({super.key, this.portrait, this.landscape});

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      builder: (context, sizingInformation) {
        if (sizingInformation.orientation == Orientation.portrait) {
          return portrait ?? const SizedBox();
        }
        return landscape ?? const SizedBox();
      },
    );
  }
}
