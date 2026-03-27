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
    // Normally fetch inbox here
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
          if (provider.isLoading && provider.conversations.isEmpty) {
            return ListView.separated(
              itemCount: 5,
              padding: const EdgeInsets.all(16),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, __) => const LoadingSkeleton(height: 80),
            );
          }
          
          if (provider.conversations.isEmpty) {
            return const EmptyState(
              icon: Icons.chat_bubble_outline,
              title: 'No messages yet',
              subtitle: 'When you contact sellers or buyers contact you, messages will appear here.',
            );
          }

          return ListView.separated(
            itemCount: provider.conversations.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final conv = provider.conversations[index];
              final otherUser = conv['other_participant'] ?? {};
              final listing = conv['listing'] ?? {};
              
              final title = listing['title'] ?? 'Listing';
              final name = otherUser['full_name'] ?? 'User';
              final lastMessage = conv['last_message']?['text_body'] ?? 'Sent an attachment';
              final unreadCount = conv['unread_count'] ?? 0;
              final timestamp = conv['last_message']?['created_at']?.toString().split('T').last.substring(0, 5) ?? '';
              
              return ListTile(
                tileColor: AppTheme.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primary.withOpacity(0.1),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(color: AppTheme.primary),
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      timestamp,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.primary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: unreadCount > 0 ? AppTheme.textPrimary : AppTheme.textSecondary,
                        fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                trailing: unreadCount > 0
                    ? Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppTheme.error,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          unreadCount.toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      )
                    : null,
                onTap: () {
                  Navigator.pushNamed(context, '/conversation', arguments: conv);
                },
              );
            },
          );
        },
      ),
    );
  }
}
