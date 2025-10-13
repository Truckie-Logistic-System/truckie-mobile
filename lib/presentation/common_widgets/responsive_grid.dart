import 'package:flutter/material.dart';

/// A responsive grid layout that adapts to different screen sizes
class ResponsiveGrid extends StatelessWidget {
  /// The list of widgets to display in the grid
  final List<Widget> children;

  /// The number of columns for small screens (phones)
  final int smallScreenColumns;

  /// The number of columns for medium screens (large phones, small tablets)
  final int mediumScreenColumns;

  /// The number of columns for large screens (tablets, desktops)
  final int largeScreenColumns;

  /// The spacing between items horizontally
  final double horizontalSpacing;

  /// The spacing between items vertically
  final double verticalSpacing;

  /// Whether to stretch the items to fill the available width
  final bool stretchItems;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.smallScreenColumns = 1,
    this.mediumScreenColumns = 2,
    this.largeScreenColumns = 3,
    this.horizontalSpacing = 16.0,
    this.verticalSpacing = 16.0,
    this.stretchItems = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine the number of columns based on available width
        int columns;
        if (constraints.maxWidth < 600) {
          columns = smallScreenColumns;
        } else if (constraints.maxWidth < 900) {
          columns = mediumScreenColumns;
        } else {
          columns = largeScreenColumns;
        }

        // Calculate the width of each item
        double itemWidth =
            (constraints.maxWidth - ((columns - 1) * horizontalSpacing)) /
            columns;

        // Create rows of items
        List<Widget> rows = [];
        for (int i = 0; i < children.length; i += columns) {
          List<Widget> rowChildren = [];

          // Add items to the current row
          for (int j = 0; j < columns; j++) {
            if (i + j < children.length) {
              Widget child = children[i + j];

              // Wrap the child in a SizedBox with the calculated width
              if (stretchItems) {
                child = SizedBox(width: itemWidth, child: child);
              } else {
                child = SizedBox(width: itemWidth, child: child);
              }

              // Add the child to the row
              rowChildren.add(child);
            } else {
              // Add an empty container to maintain grid alignment
              rowChildren.add(SizedBox(width: itemWidth));
            }
          }

          // Create a row with the calculated children
          rows.add(
            Padding(
              padding: EdgeInsets.only(
                bottom: i + columns < children.length ? verticalSpacing : 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: rowChildren,
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows,
        );
      },
    );
  }
}

/// A responsive grid item that can be used with ResponsiveGrid
class ResponsiveGridItem extends StatelessWidget {
  /// The child widget to display
  final Widget child;

  /// The flex factor for the item (used for sizing)
  final int flex;

  /// The minimum height of the item
  final double? minHeight;

  /// The maximum height of the item
  final double? maxHeight;

  const ResponsiveGridItem({
    super.key,
    required this.child,
    this.flex = 1,
    this.minHeight,
    this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        minHeight: minHeight ?? 0,
        maxHeight: maxHeight ?? double.infinity,
      ),
      child: child,
    );
  }
}
