import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonLoader extends StatelessWidget {
  final double height;
  final double width;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    this.height = 20,
    this.width = double.infinity,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class DriverInfoSkeletonCard extends StatelessWidget {
  const DriverInfoSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar skeleton
            Shimmer.fromColors(
              baseColor: Colors.grey.shade300,
              highlightColor: Colors.grey.shade100,
              child: Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name skeleton
                  const SkeletonLoader(height: 24, width: 150),
                  const SizedBox(height: 8),
                  // ID skeleton
                  const SkeletonLoader(height: 16, width: 100),
                  const SizedBox(height: 8),
                  // Status skeleton
                  const SkeletonLoader(
                    height: 24,
                    width: 120,
                    borderRadius: 16,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatisticsSkeletonCard extends StatelessWidget {
  const StatisticsSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title skeleton
        const SkeletonLoader(height: 24, width: 100),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildStatCardSkeleton()),
            const SizedBox(width: 16),
            Expanded(child: _buildStatCardSkeleton()),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildStatCardSkeleton()),
            const SizedBox(width: 16),
            Expanded(child: _buildStatCardSkeleton()),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCardSkeleton() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Icon skeleton
            Shimmer.fromColors(
              baseColor: Colors.grey.shade300,
              highlightColor: Colors.grey.shade100,
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Title skeleton
            const SkeletonLoader(height: 14, width: 80),
            const SizedBox(height: 8),
            // Value skeleton
            const SkeletonLoader(height: 20, width: 40),
          ],
        ),
      ),
    );
  }
}

class DeliverySkeletonCard extends StatelessWidget {
  const DeliverySkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title skeleton
        const SkeletonLoader(height: 24, width: 180),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Order ID skeleton
                    const SkeletonLoader(height: 18, width: 120),
                    // Status skeleton
                    const SkeletonLoader(
                      height: 24,
                      width: 100,
                      borderRadius: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Address skeleton
                const SkeletonLoader(height: 16),
                const SizedBox(height: 8),
                const SkeletonLoader(height: 16),
                const SizedBox(height: 16),
                // Time skeleton
                const SkeletonLoader(height: 16, width: 150),
                const SizedBox(height: 16),
                // Button skeleton
                const SkeletonLoader(height: 48),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class OrdersSkeletonList extends StatelessWidget {
  final int itemCount;

  const OrdersSkeletonList({super.key, this.itemCount = 3});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title skeleton
        const SkeletonLoader(height: 24, width: 150),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Order ID skeleton
                          const SkeletonLoader(height: 18, width: 120),
                          // Status skeleton
                          const SkeletonLoader(
                            height: 24,
                            width: 100,
                            borderRadius: 16,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Address skeleton
                      const SkeletonLoader(height: 16),
                      const SizedBox(height: 8),
                      const SkeletonLoader(height: 16),
                      const SizedBox(height: 16),
                      // Time skeleton
                      const SkeletonLoader(height: 16, width: 150),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
