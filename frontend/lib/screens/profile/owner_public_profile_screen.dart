import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/favorite_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/listing_card.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';

class OwnerPublicProfileScreen extends StatefulWidget {
  const OwnerPublicProfileScreen({Key? key}) : super(key: key);

  @override
  State<OwnerPublicProfileScreen> createState() => _OwnerPublicProfileScreenState();
}

class _OwnerPublicProfileScreenState extends State<OwnerPublicProfileScreen> {
  int? _userId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_userId == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is int) {
        _userId = args;
        // Enqueue fetch requests
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final prov = context.read<ProfileProvider>();
          prov.reset(); // clear old state if any
          prov.fetchProfile(_userId!);
          prov.fetchProfileListings(_userId!, refresh: true);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: Text('Invalid User ID')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Consumer<ProfileProvider>(
        builder: (context, provider, child) {
          final profile = provider.profile;

          return NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              final maxScroll = scrollInfo.metrics.maxScrollExtent;
              final currentScroll = scrollInfo.metrics.pixels;
              if (currentScroll >= maxScroll * 0.9) {
                if (provider.hasMore && !provider.isListingsLoading) {
                  provider.fetchProfileListings(_userId!);
                }
              }
              return false;
            },
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 0,
                  pinned: true,
                  backgroundColor: AppTheme.surface,
                  iconTheme: const IconThemeData(color: AppTheme.textPrimary),
                  title: Text(profile?['full_name'] ?? 'Profile', style: const TextStyle(color: AppTheme.textPrimary)),
                  elevation: 0,
                ),
                
                // --- PROFILE HEADER (Airbnb/Wildberries aesthetic) ---
                SliverToBoxAdapter(
                  child: Container(
                    color: AppTheme.surface,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: provider.isProfileLoading
                        ? const _ProfileHeaderSkeleton()
                        : (profile != null ? _buildProfileHeader(profile) : const SizedBox.shrink()),
                  ),
                ),

                // --- FEED DIVIDER ---
                if (profile != null)
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _StickySectionHeader(
                      title: 'Active Listings (${profile['active_listing_count'] ?? 0})',
                    ),
                  ),

                // --- LISTINGS FEED ---
                if (provider.error != null && provider.listings.isEmpty)
                  SliverFillRemaining(
                    child: EmptyState(
                      icon: Icons.error_outline,
                      title: 'Something went wrong',
                      subtitle: provider.error!,
                      buttonText: 'Retry',
                      onButtonPressed: () {
                        provider.fetchProfileListings(_userId!, refresh: true);
                      },
                    ),
                  )
                else if (!provider.isListingsLoading && provider.listings.isEmpty)
                  const SliverFillRemaining(
                    child: EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'No Active Listings',
                      subtitle: 'This user doesn\'t have any items for sale right now.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.65,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index >= provider.listings.length) {
                            return const LoadingSkeleton(
                              height: 280,
                              borderRadius: BorderRadius.all(Radius.circular(16)),
                            );
                          }

                          final listing = provider.listings[index];
                          
                          final images = listing['images'] as List<dynamic>?;
                          String imageUrl = '';
                          if (images != null && images.isNotEmpty) {
                            final rawUrl = images[0]['url']?.toString() ?? '';
                            if (rawUrl.startsWith('http')) {
                              imageUrl = rawUrl;
                            } else if (rawUrl.isNotEmpty) {
                              imageUrl = '${ApiConfig.baseUrl}$rawUrl';
                            }
                          }

                          final String price = '${listing['currency'] ?? 'USD'} ${listing['price']}';

                          return Consumer<FavoriteProvider>(
                            builder: (context, favProvider, child) {
                              final bool isFav = favProvider.isFavorite(listing['id']);
                              return ListingCard(
                                title: listing['title'] ?? '',
                                price: price,
                                city: listing['city'] ?? '',
                                imageUrl: imageUrl,
                                condition: listing['condition'] ?? '',
                                isFeatured: listing['is_promoted'] ?? false,
                                isFavorite: isFav,
                                onFavoriteTap: () async {
                                  try {
                                    await favProvider.toggleFavorite(listing['id']);
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                                    );
                                  }
                                },
                                onTap: () {
                                  Navigator.pushNamed(context, '/listing-detail', arguments: listing);
                                },
                              );
                            },
                          );
                        },
                        childCount: provider.listings.length + (provider.hasMore ? 2 : 0),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> profile) {
    final avatarUrl = profile['profile_image_url']?.toString();
    final name = profile['full_name'] ?? 'User';
    final initials = name.toString().isNotEmpty ? name.toString()[0].toUpperCase() : 'U';
    
    // Parse joined date
    final rawDate = profile['created_at']?.toString() ?? '';
    String joinedDate = 'Recently';
    if (rawDate.isNotEmpty) {
      try {
        final dt = DateTime.parse(rawDate);
        joinedDate = '${dt.year}';
      } catch (_) {}
    }

    return Column(
      children: [
        CircleAvatar(
          radius: 56,
          backgroundColor: AppTheme.primary.withOpacity(0.1),
          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
              ? CachedNetworkImageProvider(avatarUrl.startsWith('http') ? avatarUrl : '${ApiConfig.baseUrl}$avatarUrl')
              : null,
          child: avatarUrl == null || avatarUrl.isEmpty
              ? Text(initials, style: const TextStyle(fontSize: 40, color: AppTheme.primary, fontWeight: FontWeight.bold))
              : null,
        ),
        const SizedBox(height: 20),
        Text(
          name,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (profile['city'] != null) ...[
              const Icon(Icons.location_on, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(
                profile['city'],
                style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 16),
            ],
            const Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text(
              'Joined $joinedDate',
              style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        if (profile['bio'] != null && profile['bio'].toString().isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            profile['bio'],
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textPrimary, height: 1.5),
          ),
        ]
      ],
    );
  }
}

class _ProfileHeaderSkeleton extends StatelessWidget {
  const _ProfileHeaderSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const LoadingSkeleton(height: 112, width: 112, borderRadius: BorderRadius.all(Radius.circular(56))),
        const SizedBox(height: 20),
        const LoadingSkeleton(height: 24, width: 160),
        const SizedBox(height: 8),
        const LoadingSkeleton(height: 16, width: 220),
      ],
    );
  }
}

class _StickySectionHeader extends SliverPersistentHeaderDelegate {
  final String title;

  _StickySectionHeader({required this.title});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppTheme.background,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      alignment: Alignment.bottomLeft,
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  @override
  double get maxExtent => 60.0;

  @override
  double get minExtent => 60.0;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
}
