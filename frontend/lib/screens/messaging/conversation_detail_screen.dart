import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'dart:io';
import '../../providers/auth_provider.dart';
import '../../providers/conversation_provider.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/empty_state.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';

class ConversationDetailScreen extends StatefulWidget {
  const ConversationDetailScreen({Key? key}) : super(key: key);

  @override
  State<ConversationDetailScreen> createState() =>
      _ConversationDetailScreenState();
}

class _ConversationDetailScreenState extends State<ConversationDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  Timer? _pollingTimer;
  bool _isSending = false;
  XFile? _pendingAttachment;
  bool _initialLoadDone = false;

  Map<String, dynamic>? _convMap;
  int? _convId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_convMap == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        _convMap = args;
        _convId = args['id'];
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadMessages();
        });
        
        _pollingTimer?.cancel();
        _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
          if (mounted && _convId != null) {
            context.read<ConversationProvider>().fetchMessages(_convId!);
          }
        });
      }
    }
  }

  Future<void> _loadMessages() async {
    if (_convId == null) return;
    final provider = context.read<ConversationProvider>();
    await provider.fetchMessages(_convId!);
    if (!mounted) return;
    await provider.markAsRead(_convId!);
    if (mounted) {
      setState(() => _initialLoadDone = true);
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      // reverse: true means position 0 is the bottom
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickAttachment() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() => _pendingAttachment = image);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _removeAttachment() {
    setState(() => _pendingAttachment = null);
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _pendingAttachment == null) return;

    setState(() => _isSending = true);

    try {
      if (_convId == null) return;
      await context.read<ConversationProvider>().sendMessage(
        _convId!,
        text,
        attachment: _pendingAttachment,
      );
      if (!mounted) return;
      _messageController.clear();
      setState(() => _pendingAttachment = null);
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_convMap == null || _convId == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(elevation: 0, backgroundColor: AppTheme.surface),
        body: EmptyState(
          icon: Icons.chat_bubble_outline,
          title: 'Conversation Corrupted',
          subtitle: 'The conversation requested is unavailable or malformed.',
          buttonText: 'Return',
          onButtonPressed: () => Navigator.pop(context),
        ),
      );
    }

    final currentUserId = context.read<AuthProvider>().user?['id'];
    
    // Safely unpack other_participant and listing from the mapped argument
    final recipient = _convMap!['other_participant'] ?? {};
    final recipientName = recipient['full_name'] ?? 'User';
    final recipientInitial = recipientName.toString().isNotEmpty
        ? recipientName.toString()[0].toUpperCase()
        : 'U';
        
    final listing = _convMap!['listing'] ?? {};
    final listingTitle = listing['title'] ?? 'Listing';

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
                recipientInitial,
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipientName,
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(fontSize: 16),
                  ),
                  Text(
                    listingTitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
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
          // ── Messages Area ──
          Expanded(
            child: Consumer<ConversationProvider>(
              builder: (context, provider, child) {
                final messages = provider.messagesFor(_convId!);

                // Loading state — shimmer skeletons
                if (provider.isLoading && !_initialLoadDone) {
                  return _buildShimmerLoading();
                }

                // Error state
                if (provider.error != null && messages.isEmpty) {
                  return EmptyState(
                    icon: Icons.wifi_off,
                    title: 'Connection Error',
                    subtitle: provider.error!,
                    buttonText: 'Retry',
                    onButtonPressed: () => _loadMessages(),
                  );
                }

                // Empty state
                if (messages.isEmpty && _initialLoadDone) {
                  return const EmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: 'No messages yet',
                    subtitle:
                        'Send the first message to start the conversation!',
                  );
                }

                // Message list
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    // reverse: true means index 0 = last item in the list
                    final message = messages[messages.length - 1 - index];
                    final isMine = message['sender_id'] == currentUserId;
                    final hasAttachment = message['attachment'] != null;

                    return _buildMessageBubble(
                      context,
                      message: message,
                      isMine: isMine,
                      hasAttachment: hasAttachment,
                    );
                  },
                );
              },
            ),
          ),

          // ── Attachment Preview ──
          if (_pendingAttachment != null) _buildAttachmentPreview(),

          // ── Input Bar ──
          _buildInputBar(),
        ],
      ),
    );
  }

  // ── Shimmer Loading ──
  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      itemCount: 8,
      itemBuilder: (context, index) {
        final isRight = index % 2 == 0;
        return Align(
          alignment: isRight ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: LoadingSkeleton(
              width: MediaQuery.of(context).size.width * 0.65,
              height: isRight ? 56 : 72,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }

  // ── Message Bubble ──
  Widget _buildMessageBubble(
    BuildContext context, {
    required Map<String, dynamic> message,
    required bool isMine,
    required bool hasAttachment,
  }) {
    // Parse timestamp
    final rawTimestamp = message['sent_at']?.toString() ?? '';
    String timeLabel = '';
    if (rawTimestamp.contains('T')) {
      try {
        final dt = DateTime.parse(rawTimestamp);
        timeLabel =
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        timeLabel = rawTimestamp.split('T').last.substring(0, 5);
      }
    }

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
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Attachment image
            if (hasAttachment)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl:
                        '${ApiConfig.baseUrl}${message['attachment']['file_url']}',
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        const LoadingSkeleton(height: 180),
                    errorWidget: (context, url, error) => Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.white54,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Text body
            if (message['text_body'] != null &&
                message['text_body'].toString().isNotEmpty)
              Text(
                message['text_body'],
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isMine ? Colors.white : AppTheme.textPrimary,
                ),
              ),

            // Timestamp
            const SizedBox(height: 6),
            Text(
              timeLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isMine
                    ? Colors.white.withOpacity(0.7)
                    : AppTheme.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Attachment Preview Bar ──
  Widget _buildAttachmentPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(_pendingAttachment!.path),
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _pendingAttachment!.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppTheme.error, size: 20),
            onPressed: _removeAttachment,
          ),
        ],
      ),
    );
  }

  // ── Input Bar ──
  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ).copyWith(bottom: MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
      ),
      child: Row(
        children: [
          // Attachment button
          IconButton(
            icon: const Icon(Icons.attach_file, color: AppTheme.textSecondary),
            onPressed: _isSending ? null : _pickAttachment,
          ),

          // Text field
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
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.newline,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send button
          CircleAvatar(
            backgroundColor: _isSending
                ? AppTheme.primary.withOpacity(0.6)
                : AppTheme.primary,
            child: _isSending
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
          ),
        ],
      ),
    );
  }
}
