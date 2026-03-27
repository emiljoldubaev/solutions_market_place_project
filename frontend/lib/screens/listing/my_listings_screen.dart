import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/listing_provider.dart';
import '../../widgets/listing_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_skeleton.dart';
import '../../config/theme.dart';
import '../../widgets/app_button.dart';

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({Key? key}) : super(key: key);

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabs = ['All', 'Draft', 'Pending', 'Approved', 'Rejected', 'Archived'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ListingProvider>().fetchMyListings();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return AppTheme.success;
      case 'pending':
        return AppTheme.accent;
      case 'rejected':
        return AppTheme.error;
      case 'draft':
      case 'archived':
        return AppTheme.textSecondary;
      default:
        return AppTheme.textSecondary;
    }
  }

  List<dynamic> _filteredListings(List<dynamic> all, String tab) {
    if (tab == 'All') return all;
    return all
        .where((l) => (l['status'] ?? '').toString().toLowerCase() == tab.toLowerCase())
        .toList();
  }

  void _showDeleteDialog(BuildContext context, dynamic listing) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Listing', style: Theme.of(context).textTheme.headlineSmall),
        content: Text('Are you sure you want to delete "${listing['title']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ListingProvider>().deleteListing(listing['id']);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('My Listings'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: Consumer<ListingProvider>(
        builder: (context, provider, child) {
          // Loading state
          if (provider.isLoading && provider.myListings.isEmpty) {
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 4,
              itemBuilder: (_, __) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: LoadingSkeleton(
                  height: 100,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            );
          }

          // Error state
          if (provider.error != null && provider.myListings.isEmpty) {
            return EmptyState(
              icon: Icons.wifi_off,
              title: 'Connection Error',
              subtitle: provider.error!,
              buttonText: 'Retry',
              onButtonPressed: () => provider.fetchMyListings(),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: _tabs.map((tab) {
              final items = _filteredListings(provider.myListings, tab);

              if (items.isEmpty) {
                return EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'No $tab listings',
                  subtitle: tab == 'All'
                      ? 'Create your first listing to start selling.'
                      : 'You don\'t have any ${tab.toLowerCase()} listings.',
                  buttonText: tab == 'All' ? 'Create Listing' : null,
                  onButtonPressed: tab == 'All'
                      ? () => Navigator.pushNamed(context, '/create-listing')
                      : null,
                );
              }

              return RefreshIndicator(
                color: AppTheme.primary,
                onRefresh: () => provider.fetchMyListings(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final listing = items[index];
                    final title = listing['title'] ?? 'Untitled';
                    final priceRaw = listing['price']?.toString() ?? '0';
                    final status = listing['status'] ?? 'draft';
                    final images = listing['images'] as List<dynamic>? ?? [];
                    final imageUrl = images.isNotEmpty
                        ? (images.first['url'] ?? '')
                        : '';

                    return Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: InkWell(
                        onTap: () {
                          // Navigate to listing detail
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Thumbnail
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: imageUrl.isNotEmpty
                                    ? Image.network(
                                        imageUrl,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _placeholderThumb(),
                                      )
                                    : _placeholderThumb(),
                              ),
                              const SizedBox(width: 12),

                              // Content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '\$$priceRaw',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            color: AppTheme.primary,
                                            fontSize: 16,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    // Status badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _statusColor(status).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        status.toUpperCase(),
                                        style: TextStyle(
                                          color: _statusColor(status),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Actions
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _actionIcon(
                                    context,
                                    Icons.edit_outlined,
                                    AppTheme.primary,
                                    () {
                                      // Navigate to edit listing
                                    },
                                  ),
                                  const SizedBox(height: 4),
                                  _actionIcon(
                                    context,
                                    Icons.delete_outline,
                                    AppTheme.error,
                                    () => _showDeleteDialog(context, listing),
                                  ),
                                  if (status.toLowerCase() == 'approved') ...[
                                    const SizedBox(height: 4),
                                    _actionIcon(
                                      context,
                                      Icons.rocket_launch_outlined,
                                      AppTheme.accent,
                                      () {
                                        Navigator.pushNamed(
                                          context,
                                          '/promote',
                                          arguments: listing,
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _placeholderThumb() {
    return Container(
      width: 80,
      height: 80,
      color: AppTheme.background,
      child: const Icon(Icons.image, color: AppTheme.textSecondary),
    );
  }

  Widget _actionIcon(
      BuildContext context, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}
