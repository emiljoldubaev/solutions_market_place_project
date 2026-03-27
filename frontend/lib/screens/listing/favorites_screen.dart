import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/favorite_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/listing_card.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FavoriteProvider>().fetchFavorites(refresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Favorites'),
        elevation: 0,
      ),
      body: Consumer<FavoriteProvider>(
        builder: (context, provider, child) {
          // 1. Loading State
          if (provider.isLoading && provider.favorites.isEmpty) {
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.65,
              ),
              itemCount: 4,
              itemBuilder: (context, index) {
                return const LoadingSkeleton(
                  height: 280,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                );
              },
            );
          }

          // 2. Error State
          if (provider.error != null && provider.favorites.isEmpty) {
            return EmptyState(
              icon: Icons.error_outline,
              title: 'Something went wrong',
              subtitle: provider.error!,
              buttonText: 'Retry',
              onButtonPressed: () {
                provider.fetchFavorites(refresh: true);
              },
            );
          }

          // 3. Empty State
          if (provider.favorites.isEmpty) {
            return const EmptyState(
              icon: Icons.favorite_border,
              title: 'No favorites yet',
              subtitle: 'Start exploring and save items you like!',
            );
          }

          // 4. Data State
          return NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              final maxScroll = scrollInfo.metrics.maxScrollExtent;
              final currentScroll = scrollInfo.metrics.pixels;
              if (currentScroll >= maxScroll * 0.9) {
                if (provider.hasMore && !provider.isLoading) {
                  provider.fetchFavorites();
                }
              }
              return false;
            },
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.65,
              ),
              itemCount: provider.favorites.length + (provider.hasMore ? 2 : 0),
              itemBuilder: (context, index) {
                if (index >= provider.favorites.length) {
                  return const LoadingSkeleton(
                    height: 280,
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  );
                }

                final listing = provider.favorites[index];
                
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

                return ListingCard(
                  title: listing['title'] ?? '',
                  price: price,
                  city: listing['city'] ?? '',
                  imageUrl: imageUrl,
                  condition: listing['condition'] ?? '',
                  isFeatured: listing['is_promoted'] ?? false,
                  isFavorite: true,
                  onFavoriteTap: () async {
                    try {
                      await provider.toggleFavorite(listing['id']);
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(e.toString().replaceFirst('Exception: ', '')),
                          backgroundColor: AppTheme.error,
                        ),
                      );
                    }
                  },
                  onTap: () {
                    Navigator.pushNamed(context, '/listing-detail', arguments: listing);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
