import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        shape: BoxShape.circle,
      ),
    );
  }
}

class ShimmerWrapper extends StatelessWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerWrapper({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: baseColor ?? Colors.grey[300]!,
      highlightColor: highlightColor ?? Colors.grey[100]!,
      child: child,
    );
  }
}

class TripCardSkeleton extends StatelessWidget {
  const TripCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SkeletonBox(width: 80, height: 28, borderRadius: 20),
                  SkeletonBox(width: 60, height: 24, borderRadius: 20),
                ],
              ),
              const Spacer(),
              SkeletonBox(width: 200, height: 28, borderRadius: 4),
              const SizedBox(height: 12),
              Row(
                children: [
                  SkeletonBox(width: 14, height: 14, borderRadius: 2),
                  const SizedBox(width: 8),
                  SkeletonBox(width: 150, height: 14, borderRadius: 4),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TripsListSkeleton extends StatelessWidget {
  final int itemCount;

  const TripsListSkeleton({super.key, this.itemCount = 3});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TripCardSkeleton(),
        );
      },
    );
  }
}

class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primary.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 48),
                    Text(
                      'Profile',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, color: Colors.white),
                      onPressed: null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ShimmerWrapper(
                baseColor: Colors.white.withValues(alpha: 0.3),
                highlightColor: Colors.white.withValues(alpha: 0.5),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: const SkeletonCircle(size: 100),
                    ),
                    const SizedBox(height: 16),
                    SkeletonBox(width: 150, height: 24, borderRadius: 4),
                    const SizedBox(height: 8),
                    SkeletonBox(width: 120, height: 14, borderRadius: 4),
                    const SizedBox(height: 4),
                    SkeletonBox(width: 180, height: 14, borderRadius: 4),
                    const SizedBox(height: 24),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatSkeleton(),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          _StatSkeleton(),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          _StatSkeleton(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SkeletonBox(width: 40, height: 24, borderRadius: 4),
        const SizedBox(height: 4),
        SkeletonBox(width: 50, height: 14, borderRadius: 4),
      ],
    );
  }
}

class FriendTileSkeleton extends StatelessWidget {
  const FriendTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: ListTile(
        leading: const SkeletonCircle(size: 48),
        title: SkeletonBox(width: 120, height: 16, borderRadius: 4),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: SkeletonBox(width: 80, height: 12, borderRadius: 4),
        ),
        trailing: SkeletonBox(width: 24, height: 24, borderRadius: 4),
      ),
    );
  }
}

class FriendsListSkeleton extends StatelessWidget {
  final int itemCount;

  const FriendsListSkeleton({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: itemCount,
      itemBuilder: (context, index) => const FriendTileSkeleton(),
    );
  }
}

class TripDetailSkeleton extends StatelessWidget {
  const TripDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: Colors.grey[200],
            flexibleSpace: FlexibleSpaceBar(
              background: ShimmerWrapper(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Container(
                  color: Colors.grey[300],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: ShimmerWrapper(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description placeholder
                    Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: double.infinity, height: 14, borderRadius: 4),
                          const SizedBox(height: 8),
                          SkeletonBox(width: 200, height: 14, borderRadius: 4),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Stats row
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SkeletonBox(width: 24, height: 24, borderRadius: 4),
                                const SizedBox(height: 8),
                                SkeletonBox(width: 40, height: 12, borderRadius: 4),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SkeletonBox(width: 24, height: 24, borderRadius: 4),
                                const SizedBox(height: 8),
                                SkeletonBox(width: 40, height: 12, borderRadius: 4),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SkeletonBox(width: 24, height: 24, borderRadius: 4),
                                const SizedBox(height: 8),
                                SkeletonBox(width: 40, height: 12, borderRadius: 4),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Section headers and cards
                    SkeletonBox(width: 120, height: 20, borderRadius: 4),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          SkeletonBox(width: 48, height: 48, borderRadius: 10),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SkeletonBox(width: 150, height: 14, borderRadius: 4),
                                const SizedBox(height: 8),
                                SkeletonBox(width: 100, height: 12, borderRadius: 4),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SkeletonBox(width: 100, height: 20, borderRadius: 4),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          SkeletonCircle(size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SkeletonBox(width: double.infinity, height: 14, borderRadius: 4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ItineraryItemSkeleton extends StatelessWidget {
  const ItineraryItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            SkeletonBox(width: 4, height: 60, borderRadius: 2),
            const SizedBox(width: 12),
            SkeletonCircle(size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 150, height: 16, borderRadius: 4),
                  const SizedBox(height: 8),
                  SkeletonBox(width: 100, height: 12, borderRadius: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ItineraryListSkeleton extends StatelessWidget {
  final int itemCount;

  const ItineraryListSkeleton({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: itemCount,
      itemBuilder: (context, index) => const ItineraryItemSkeleton(),
    );
  }
}

class ActivityLogItemSkeleton extends StatelessWidget {
  const ActivityLogItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonCircle(size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: double.infinity, height: 14, borderRadius: 4),
                  const SizedBox(height: 6),
                  SkeletonBox(width: 80, height: 12, borderRadius: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MemberTileSkeleton extends StatelessWidget {
  const MemberTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: ListTile(
        leading: const SkeletonCircle(size: 48),
        title: SkeletonBox(width: 120, height: 16, borderRadius: 4),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: SkeletonBox(width: 60, height: 12, borderRadius: 4),
        ),
        trailing: SkeletonBox(width: 60, height: 24, borderRadius: 12),
      ),
    );
  }
}

class MembersListSkeleton extends StatelessWidget {
  final int itemCount;

  const MembersListSkeleton({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: itemCount,
      itemBuilder: (context, index) => const MemberTileSkeleton(),
    );
  }
}
