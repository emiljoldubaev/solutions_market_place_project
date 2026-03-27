import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../providers/conversation_provider.dart';
import '../../widgets/loading_skeleton.dart';
import '../../config/theme.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ConversationDetailScreen extends StatefulWidget {
  final int conversationId;
  final Map<String, dynamic> recipient;
  final Map<String, dynamic> listing;

  const ConversationDetailScreen({
    Key? key,
    required this.conversationId,
    required this.recipient,
    required this.listing,
  }) : super(key: key);

  @override
  State<ConversationDetailScreen> createState() => _ConversationDetailScreenState();
}

class _ConversationDetailScreenState extends State<ConversationDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConversationProvider>().fetchMessages(widget.conversationId);
    });
    // Polls every 10 seconds per requirements
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      context.read<ConversationProvider>().pollMessages(); 
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    context.read<ConversationProvider>().sendMessage(widget.conversationId, text);
    _messageController.clear();
    
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: AppTheme.surface,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.primary.withOpacity(0.1),
              child: Text(
                (widget.recipient['full_name'] ?? 'U')[0].toUpperCase(),
                style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.recipient['full_name'] ?? 'User',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 16),
                  ),
                  Text(
                    widget.listing['title'] ?? 'Listing',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ConversationProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final messages = provider.messages;
                
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  reverse: true, // Display newest at bottom natively
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMine = message['is_mine'] ?? false; 
                    final hasAttachment = message['attachment'] != null;
                    
                    return Align(
                      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: isMine ? AppTheme.primary : AppTheme.surface,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: isMine ? const Radius.circular(16) : Radius.zero,
                            bottomRight: isMine ? Radius.zero : const Radius.circular(16),
                          ),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasAttachment)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: message['attachment']['url'],
                                    height: 180,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const LoadingSkeleton(height: 180),
                                    errorWidget: (context, url, error) => Container(
                                      height: 100,
                                      color: Colors.black12,
                                      child: const Icon(Icons.broken_image, color: Colors.white54),
                                    ),
                                  ),
                                ),
                              ),
                            if (message['text_body'] != null && message['text_body'].isNotEmpty)
                              Text(
                                message['text_body'],
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: isMine ? Colors.white : AppTheme.textPrimary,
                                ),
                              ),
                            const SizedBox(height: 6),
                            Text(
                              message['created_at']?.toString().split('T').last.substring(0, 5) ?? '12:00',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isMine ? Colors.white.withOpacity(0.7) : AppTheme.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // Send Message Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12).copyWith(
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file, color: AppTheme.textSecondary),
                  onPressed: () {
                    // Open file picker
                  },
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Message...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      maxLines: 4,
                      minLines: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppTheme.primary,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
