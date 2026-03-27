import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../providers/conversation_provider.dart';
import '../../providers/favorite_provider.dart';
import '../../config/theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/dynamic_attributes.dart';

class ListingDetailScreen extends StatefulWidget {
  const ListingDetailScreen({Key? key}) : super(key: key);

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;
  bool _messagingLoading = false;

  Map<String, dynamic>? _listing;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_listing == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        _listing = args;
        // Check favorite once we have the ID safely
        final listingId = _listing!['id'];
        if (listingId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<FavoriteProvider>().checkFavorite(listingId);
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_listing == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(elevation: 0, backgroundColor: AppTheme.surface),
        body: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Listing Not Found',
          subtitle: 'The listing you are looking for may have been removed or is unavailable.',
          buttonText: 'Go Back',
          onButtonPressed: () => Navigator.pop(context),
        ),
      );
    }

    final images = _listing!['images'] as List<dynamic>? ?? [];
    final title = _listing!['title'] ?? 'Unknown';
    final priceRaw = _listing!['price']?.toString() ?? '0';
    final currency = _listing!['currency'] ?? 'USD';
    final price = '$currency $priceRaw';
    final condition = _listing!['condition'] ?? 'used';
    final city = _listing!['city'] ?? 'Unknown Location';
    final isPromoted = _listing!['is_promoted'] ?? false;
    final description = _listing!['description'] ?? 'No description provided.';
    
    final owner = _listing!['owner'] ?? {};
    final ownerName = owner['full_name'] ?? 'User';
    final ownerInitials = ownerName.toString().isNotEmpty ? ownerName.toString()[0].toUpperCase() : 'U';
    final ownerJoinDate = owner['created_at']?.toString().split('T').first ?? 'Recently';
    final activeListingsCount = owner['active_listings_count'] ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 350.0,
            pinned: true,
            backgroundColor: AppTheme.surface,
            iconTheme: const IconThemeData(color: AppTheme.textPrimary),
            actions: [
              Consumer<FavoriteProvider>(
                builder: (context, favProvider, _) {
                  final listingId = _listing!['id'] as int?;
                  final isFav = listingId != null && favProvider.isFavorite(listingId);
                  return IconButton(
                    icon: Icon(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      color: isFav ? AppTheme.error : AppTheme.textPrimary,
                    ),
                    onPressed: favProvider.isToggling
                        ? null
                        : () async {
                            if (listingId == null) return;
                            try {
                              await context.read<FavoriteProvider>().toggleFavorite(listingId);
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
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: () {},
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  images.isNotEmpty
                      ? PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() => _currentImageIndex = index);
                          },
                          itemCount: images.length,
                          itemBuilder: (context, index) {
                            return CachedNetworkImage(
                              imageUrl: images[index]['url'] ?? 'https://via.placeholder.com/400',
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const LoadingSkeleton(height: double.infinity),
                              errorWidget: (context, url, error) => Container(
                                color: AppTheme.border,
                                child: const Icon(Icons.broken_image, size: 50, color: AppTheme.textSecondary),
                              ),
                            );
                          },
                        )
                      : Container(
                          color: AppTheme.border,
                          child: const Icon(Icons.image_not_supported, size: 50, color: AppTheme.textSecondary),
                        ),
                  
                  if (images.length > 1)
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(images.length, (index) {
                          return Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentImageIndex == index
                                  ? AppTheme.primary
                                  : Colors.white.withOpacity(0.5),
                            ),
                          );
                        }),
                      ),
                    ),
                    
                  if (isPromoted)
                    Positioned(
                      bottom: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.accent,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Colors.white, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'Featured',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          SliverToBoxAdapter(
            child: Container(
              color: AppTheme.surface,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    price,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AppTheme.primary,
                      fontSize: 32,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Text(
                          condition.toUpperCase(),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.location_on, size: 20, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        city,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                  
                  // Description
                  Text('Description', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
                  ),
                  const SizedBox(height: 32),
                  
                  // Dynamic Attributes
                  DynamicAttributes(attributes: _listing!['attributes'] as Map<String, dynamic>?),
                  
                  // Owner Card
                  Text('Seller Information', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () {
                      final ownerId = _listing!['owner']?['id'];
                      if (ownerId == null) return;
                      Navigator.pushNamed(context, '/owner-profile', arguments: ownerId);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        border: Border.all(color: AppTheme.border),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: AppTheme.primary.withOpacity(0.1),
                            child: Text(
                              ownerInitials,
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ownerName,
                                  style: Theme.of(context).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Joined $ownerJoinDate • $activeListingsCount active listings',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Action Buttons
                  AppButton(
                    text: _messagingLoading ? 'Opening chat...' : 'Message Seller',
                    isLoading: _messagingLoading,
                    onPressed: _messagingLoading ? null : () async {
                      final ownerId = _listing!['owner']?['id'];
                      final listingId = _listing!['id'];
                      if (ownerId == null || listingId == null) return;

                      setState(() => _messagingLoading = true);
                      try {
                        final convProvider = context.read<ConversationProvider>();
                        final conv = await convProvider.getOrCreateConversation(listingId, ownerId);
                        if (!mounted) return;
                        Navigator.pushNamed(context, '/conversation-detail', arguments: conv);
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.toString().replaceFirst('Exception: ', '')),
                            backgroundColor: AppTheme.error,
                          ),
                        );
                      } finally {
                        if (mounted) {
                          setState(() => _messagingLoading = false);
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.center,
                    child: TextButton.icon(
                      onPressed: () {
                        // Open report modal
                      },
                      icon: const Icon(Icons.flag_outlined, color: AppTheme.textSecondary, size: 20),
                      label: Text(
                        'Report this listing',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
