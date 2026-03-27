import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/search_provider.dart';
import '../../providers/favorite_provider.dart';
import '../../widgets/listing_card.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_modal.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<SearchProvider>();
      _searchCtrl.text = provider.currentFilters['search'] ?? '';
      // Always ping a fresh fetch on open just in case
      provider.performSearch(provider.currentFilters, refresh: true);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _executeTextSearch(String query) {
    final provider = context.read<SearchProvider>();
    final newFilters = Map<String, dynamic>.from(provider.currentFilters);
    if (query.trim().isEmpty) {
      newFilters.remove('search');
    } else {
      newFilters['search'] = query.trim();
    }
    provider.performSearch(newFilters, refresh: true);
  }

  void _openFilters() async {
    final provider = context.read<SearchProvider>();
    
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterModal(initialFilters: provider.currentFilters),
    );

    if (result != null) {
      provider.performSearch(result, refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.search, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _executeTextSearch,
                    decoration: const InputDecoration(
                      hintText: 'Search hundreds of items...',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_searchCtrl.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: AppTheme.textSecondary),
                    onPressed: () {
                      _searchCtrl.clear();
                      _executeTextSearch('');
                      FocusScope.of(context).unfocus();
                    },
                  ),
              ],
            ),
          ),
        ),
        actions: [
          Consumer<SearchProvider>(
            builder: (context, provider, child) {
              final int activeFilters = provider.currentFilters.keys.where((k) => k != 'search' && k != 'sort_by').length;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.tune_rounded, color: AppTheme.textPrimary),
                    onPressed: _openFilters,
                  ),
                  if (activeFilters > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$activeFilters',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<SearchProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.searchResults.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }

          if (provider.error != null && provider.searchResults.isEmpty) {
            return EmptyState(
              icon: Icons.error_outline,
              title: 'Search Failed',
              subtitle: provider.error!,
              buttonText: 'Retry',
              onButtonPressed: () => provider.performSearch(provider.currentFilters, refresh: true),
            );
          }

          if (!provider.isLoading && provider.searchResults.isEmpty) {
            return EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No results found',
              subtitle: 'Try adjusting your filters or searching for something else.',
              buttonText: 'Clear Filters',
              onButtonPressed: () {
                _searchCtrl.clear();
                provider.clearFilters();
              },
            );
          }

          return NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent * 0.9) {
                if (provider.hasMore && !provider.isLoading) {
                  provider.performSearch(provider.currentFilters);
                }
              }
              return false;
            },
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.65,
              ),
              itemCount: provider.searchResults.length + (provider.hasMore ? 2 : 0),
              itemBuilder: (context, index) {
                if (index >= provider.searchResults.length) {
                  return const LoadingSkeleton(
                    height: 280,
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  );
                }

                final listing = provider.searchResults[index];
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
            ),
          );
        },
      ),
    );
  }
}
