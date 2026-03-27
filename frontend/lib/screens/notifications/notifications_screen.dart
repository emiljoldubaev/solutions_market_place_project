import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/listing_provider.dart';
import '../../providers/conversation_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_skeleton.dart';
import '../../config/theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().fetchNotifications(refresh: true);
    });
  }

  void _handleNotificationTap(Map<String, dynamic> notification) async {
    final provider = context.read<NotificationProvider>();
    
    // 1. Mark as read
    try {
      await provider.markAsRead(notification['id']);
    } catch (e) {
      // Silently continue if marking read fails
    }

    if (!mounted) return;

    // 2. Safely route without crashing depending on reference_type
    final String? refType = notification['reference_type'];
    final dynamic refId = notification['reference_id'];

    if (refType == 'listing' && refId != null) {
      // Look for it in local memory so we can pass full object to the screen
      final listingProv = context.read<ListingProvider>();
      final found = [...listingProv.listings, ...listingProv.myListings].firstWhere(
        (l) => l['id'] == refId, 
        orElse: () => null,
      );

      if (found != null) {
         Navigator.pushNamed(context, '/listing-detail', arguments: found);
      } else {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(
             content: Text('Please navigate to Home or My Listings to view this item.'),
             backgroundColor: AppTheme.primary,
           ),
         );
      }
    } else if (refType == 'message' && refId != null) {
      final convProv = context.read<ConversationProvider>();
      final found = convProv.conversations.firstWhere(
        (c) => c['id'] == refId, 
        orElse: () => null,
      );

      if (found != null) {
         Navigator.pushNamed(context, '/conversation', arguments: found);
      } else {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(
             content: Text('Please navigate to your Inbox to view this message.'),
             backgroundColor: AppTheme.primary,
           ),
         );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        elevation: 0,
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, child) {
              if (provider.unreadCount == 0 || provider.notifications.isEmpty) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(Icons.done_all, color: AppTheme.primary),
                tooltip: 'Mark all as read',
                onPressed: () async {
                  try {
                    await provider.markAllAsRead();
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
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, child) {
          // 1. Loading
          if (provider.isLoading && provider.notifications.isEmpty) {
            return ListView.separated(
              itemCount: 8,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: LoadingSkeleton(height: 60, borderRadius: BorderRadius.all(Radius.circular(8))),
                );
              },
            );
          }

          // 2. Error
          if (provider.error != null && provider.notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  EmptyState(
                    icon: Icons.error_outline,
                    title: 'Something went wrong',
                    subtitle: provider.error!,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.fetchNotifications(refresh: true),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          // 3. Empty
          if (provider.notifications.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none,
              title: 'No notifications',
              subtitle: 'You\'re all caught up!',
            );
          }

          // 4. Data
          return NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              final maxScroll = scrollInfo.metrics.maxScrollExtent;
              final currentScroll = scrollInfo.metrics.pixels;
              if (currentScroll >= maxScroll * 0.9) {
                if (provider.hasMore && !provider.isLoading) {
                  provider.fetchNotifications();
                }
              }
              return false;
            },
            child: RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: () async {
                await provider.fetchNotifications(refresh: true);
              },
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: provider.notifications.length + (provider.hasMore ? 1 : 0),
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index >= provider.notifications.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                      child: Center(
                        child: SizedBox(
                          width: 24, 
                          height: 24, 
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)
                        )
                      ),
                    );
                  }

                  final notification = provider.notifications[index];
                  final bool isRead = notification['is_read'] ?? false;
                  final String refType = notification['reference_type'] ?? '';

                  IconData icon;
                  Color iconBg;
                  if (refType == 'listing') {
                    icon = Icons.storefront;
                    iconBg = Colors.blue.withOpacity(0.1);
                  } else if (refType == 'message') {
                    icon = Icons.chat_bubble_outline;
                    iconBg = Colors.green.withOpacity(0.1);
                  } else {
                    icon = Icons.info_outline;
                    iconBg = AppTheme.primary.withOpacity(0.1);
                  }

                  // Parse simple time
                  final rawTime = notification['created_at']?.toString() ?? '';
                  String timeStr = '';
                  if (rawTime.isNotEmpty) {
                    try {
                      final dt = DateTime.parse(rawTime);
                      timeStr = '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                    } catch (_) {
                      timeStr = rawTime.split('T').first;
                    }
                  }

                  return InkWell(
                    onTap: () => _handleNotificationTap(notification),
                    child: Container(
                      color: isRead ? Colors.transparent : AppTheme.primary.withOpacity(0.04),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: iconBg,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: AppTheme.primary, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        notification['title'] ?? 'Notification',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (timeStr.isNotEmpty)
                                      Text(
                                        timeStr,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  notification['body'] ?? '',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: isRead ? AppTheme.textSecondary : AppTheme.textPrimary,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
