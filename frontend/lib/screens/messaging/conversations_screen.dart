import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/conversation_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_skeleton.dart';
import '../../config/theme.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({Key? key}) : super(key: key);

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConversationProvider>().fetchConversations();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Messages'),
        elevation: 0,
      ),
      body: Consumer<ConversationProvider>(
        builder: (context, provider, child) {
          // Loading state
          if (provider.isLoading && provider.conversations.isEmpty) {
            return ListView.separated(
              itemCount: 6,
              padding: const EdgeInsets.all(16),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, __) => Row(
                children: [
                  const LoadingSkeleton(
                    width: 48, height: 48,
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        LoadingSkeleton(width: 140, height: 14),
                        SizedBox(height: 8),
                        LoadingSkeleton(width: 220, height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          // Error state
          if (provider.error != null && provider.conversations.isEmpty) {
            return EmptyState(
              icon: Icons.wifi_off,
              title: 'Connection Error',
              subtitle: provider.error!,
              buttonText: 'Retry',
              onButtonPressed: () => provider.fetchConversations(),
            );
          }

          // Empty state
          if (provider.conversations.isEmpty) {
            return const EmptyState(
              icon: Icons.chat_bubble_outline,
              title: 'No messages yet',
              subtitle: 'When you contact sellers or buyers contact you, messages will appear here.',
            );
          }

          // Conversation list
          return RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: () => provider.fetchConversations(),
            child: ListView.separated(
              itemCount: provider.conversations.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
              itemBuilder: (context, index) {
                final conv = provider.conversations[index];
                final otherUser = conv['other_participant'] ?? {};
                final listing = conv['listing'] ?? {};

                final name = otherUser['full_name'] ?? 'User';
                final initials = name.isNotEmpty ? name[0].toUpperCase() : 'U';
                final listingTitle = listing['title'] ?? 'Listing';
                final lastMessage = conv['last_message']?['text_body'] ?? 'Sent an attachment';
                final unreadCount = conv['unread_count'] ?? 0;
                final rawTimestamp = conv['last_message']?['created_at']?.toString() ?? '';
                final timestamp = rawTimestamp.contains('T')
                    ? rawTimestamp.split('T').last.substring(0, 5)
                    : '';

                return InkWell(
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/conversation-detail',
                      arguments: {
                        'id': conv['id'],
                        'other_participant': otherUser,
                        'listing': listing,
                      },
                    );
                  },
                  child: Container(
                    color: unreadCount > 0
                        ? AppTheme.primary.withOpacity(0.03)
                        : AppTheme.surface,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        // Avatar
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppTheme.primary.withOpacity(0.1),
                          child: Text(
                            initials,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: AppTheme.primary,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        fontWeight: unreadCount > 0
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    timestamp,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: unreadCount > 0
                                          ? AppTheme.primary
                                          : AppTheme.textSecondary,
                                      fontWeight: unreadCount > 0
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                listingTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      lastMessage,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: unreadCount > 0
                                            ? AppTheme.textPrimary
                                            : AppTheme.textSecondary,
                                        fontWeight: unreadCount > 0
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  if (unreadCount > 0)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.error,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        unreadCount.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
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
          );
        },
      ),
    );
  }
}
