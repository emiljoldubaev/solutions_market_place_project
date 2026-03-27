import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/listing_provider.dart';
import '../../providers/conversation_provider.dart';
import '../../widgets/listing_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_skeleton.dart';
import '../../config/theme.dart';

// Import remaining feature screens
import '../search/search_screen.dart';
import '../listing/create_listing_screen.dart';
import '../messaging/conversations_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final ScrollController _scrollController = ScrollController();

  final List<String> _categories = [
    'All', 'Electronics', 'Vehicles', 'Real Estate', 'Clothing', 'Services'
  ];
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ListingProvider>().fetchListings(refresh: true);
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= 
          _scrollController.position.maxScrollExtent - 200) {
        context.read<ListingProvider>().fetchListings();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Array of base screens for Navigation
    final List<Widget> _screens = [
      _buildHomeTab(context),
      const SearchScreen(),
      const CreateListingScreen(),
      const ConversationsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        backgroundColor: AppTheme.surface,
        indicatorColor: AppTheme.primary.withOpacity(0.1),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined), 
            selectedIcon: Icon(Icons.home, color: AppTheme.primary), 
            label: 'Home'
          ),
          const NavigationDestination(
            icon: Icon(Icons.search), 
            label: 'Search'
          ),
          const NavigationDestination(
            icon: CircleAvatar(
              backgroundColor: AppTheme.accent,
              radius: 18,
              child: Icon(Icons.add, color: Colors.white, size: 20),
            ),
            label: 'Post',
          ),
          NavigationDestination(
            icon: Consumer<ConversationProvider>(
              builder: (context, convProvider, _) => Badge(
                label: Text('${convProvider.unreadCount}'),
                isLabelVisible: convProvider.unreadCount > 0,
                backgroundColor: AppTheme.error,
                child: const Icon(Icons.chat_bubble_outline),
              ),
            ),
            selectedIcon: Consumer<ConversationProvider>(
              builder: (context, convProvider, _) => Badge(
                label: Text('${convProvider.unreadCount}'),
                isLabelVisible: convProvider.unreadCount > 0,
                backgroundColor: AppTheme.error,
                child: const Icon(Icons.chat_bubble, color: AppTheme.primary),
              ),
            ),
            label: 'Messages',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline), 
            selectedIcon: Icon(Icons.person, color: AppTheme.primary), 
            label: 'Profile'
          ),
        ],
      ),
      body: SafeArea(
        child: _screens[_currentIndex],
      ),
    );
  }

  Widget _buildHomeTab(BuildContext context) {
    return Column(
      children: [
        // Search Bar Area
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const TextField(
                    decoration: InputDecoration(
                      hintText: 'Search for anything...',
                      prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.tune, color: AppTheme.primary),
                  onPressed: () {
                    // Open Filter Modal
                  },
                ),
              ),
            ],
          ),
        ),

        // Categories (Horizontal Scroll)
        SizedBox(
          height: 44,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final category = _categories[index];
              final isSelected = _selectedCategory == category;
              return ChoiceChip(
                label: Text(category),
                selected: isSelected,
                selectedColor: AppTheme.primary,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                backgroundColor: AppTheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? AppTheme.primary : AppTheme.border,
                  ),
                ),
                showCheckmark: false,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedCategory = category);
                    context.read<ListingProvider>().fetchListings(refresh: true);
                  }
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // Listings Grid
        Expanded(
          child: Consumer<ListingProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading && provider.listings.isEmpty) {
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.65,
                  ),
                  itemCount: 6,
                  itemBuilder: (context, index) => const LoadingSkeleton(),
                );
              }

              if (provider.error != null && provider.listings.isEmpty) {
                return EmptyState(
                  icon: Icons.error_outline,
                  title: 'Oops!',
                  subtitle: provider.error!,
                  buttonText: 'Retry',
                  onButtonPressed: () => provider.fetchListings(refresh: true),
                );
              }

              if (provider.listings.isEmpty) {
                return EmptyState(
                  icon: Icons.search_off,
                  title: 'No listings found',
                  subtitle: 'Try adjusting your search or filters.',
                  buttonText: 'Clear Filters',
                  onButtonPressed: () {
                    setState(() => _selectedCategory = 'All');
                    provider.fetchListings(refresh: true);
                  },
                );
              }

              return RefreshIndicator(
                color: AppTheme.primary,
                onRefresh: () => provider.fetchListings(refresh: true),
                child: GridView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.65,
                  ),
                  itemCount: provider.listings.length + (provider.hasMore ? 2 : 0),
                  itemBuilder: (context, index) {
                    if (index >= provider.listings.length) {
                      return const LoadingSkeleton();
                    }

                    final listing = provider.listings[index];
                    // Defensive parsing mapping from the backend API shape
                    final title = listing['title'] ?? 'Unknown';
                    // Check if price is available, and format cleanly
                    final priceRaw = listing['price']?.toString() ?? '0';
                    final price = '\$$priceRaw';
                    final city = listing['city'] ?? 'Unknown Location';
                    
                    final images = listing['images'] as List<dynamic>?;
                    final imageUrl = (images != null && images.isNotEmpty) 
                        ? (images.first['url'] ?? '') 
                        : 'https://via.placeholder.com/200';
                        
                    final condition = listing['condition'] ?? 'used';

                    return ListingCard(
                      title: title,
                      price: price,
                      city: city,
                      imageUrl: imageUrl,
                      condition: condition,
                      isFeatured: listing['is_promoted'] ?? false,
                      onTap: () {
                        // Navigate to Listing Detail
                      },
                      onFavoriteTap: () {
                        // Toggle Favorite locally or via Provider
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
