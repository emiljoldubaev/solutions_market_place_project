// LAST MODIFIED: 2026-03-28 - Implemented Spec 13.1 / 14.1 Firestore Chat Topology
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Generates a deterministic composite ID to prevent Race Conditions (Risk A).
  /// Formula: min(uid1, uid2)_max(uid1, uid2)_listingId
  String getChatId(String uid1, String uid2, String listingId) {
    List<String> sortedUids = [uid1, uid2]..sort();
    return '${sortedUids[0]}_${sortedUids[1]}_$listingId';
  }

  /// Sends a text message or attachment to a specific listing thread.
  Future<void> sendMessage({
    required String peerId,
    required String listingId,
    required String listingTitle,
    String? text,
    File? attachment,
    String? attachmentType, // 'image' or 'pdf'
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('unauthorized_error'); // Localizable key

    final currentUid = currentUser.uid;
    final chatId = getChatId(currentUid, peerId, listingId);
    final chatRef = _db.collection('chats').doc(chatId);

    String? attachmentUrl;
    int? attachmentSize;

    // Spec 14.1 Attachment Handling
    if (attachment != null && attachmentType != null) {
      attachmentSize = await attachment.length();
      // Enforce max size (e.g. 10MB) locally before uploading
      if (attachmentSize > 10 * 1024 * 1024) {
        throw Exception('file_too_large_error'); // Localizable key
      }

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${currentUid}.${attachmentType == 'pdf' ? 'pdf' : 'jpg'}';
      final storageRef = _storage.ref().child('chat_attachments/$chatId/$fileName');
      
      final uploadTask = await storageRef.putFile(
        attachment, 
        SettableMetadata(contentType: attachmentType == 'pdf' ? 'application/pdf' : 'image/jpeg')
      );
      attachmentUrl = await uploadTask.ref.getDownloadURL();
    }

    if ((text == null || text.trim().isEmpty) && attachmentUrl == null) {
      throw Exception('empty_message_error'); // Localizable key
    }

    // Spec 13.1 Message Payload
    final messageData = {
      'sender_id': currentUid,
      'text_body': text?.trim(),
      'sent_at': FieldValue.serverTimestamp(),
      'is_read': false,
      'attachment_url': attachmentUrl,
      'attachment_type': attachmentType,
      'attachment_size': attachmentSize,
    };

    // Transaction to safely update both Thread Metadata and Message Subcollection
    await _db.runTransaction((transaction) async {
      final chatSnapshot = await transaction.get(chatRef);

      if (!chatSnapshot.exists) {
        transaction.set(chatRef, {
          'listing_id': listingId,
          'listing_title': listingTitle,
          'participant_ids': [currentUid, peerId],
          'last_message': text?.trim() ?? (attachmentType == 'pdf' ? 'Sent a PDF' : 'Sent an image'),
          'last_message_time': FieldValue.serverTimestamp(),
          'created_at': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.update(chatRef, {
          'last_message': text?.trim() ?? (attachmentType == 'pdf' ? 'Sent a PDF' : 'Sent an image'),
          'last_message_time': FieldValue.serverTimestamp(),
        });
      }

      final messageRef = chatRef.collection('messages').doc();
      transaction.set(messageRef, messageData);
    });
  }

  /// Streams active messages for a specific interaction.
  Stream<QuerySnapshot> getMessagesStream(String peerId, String listingId) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return const Stream.empty();

    final chatId = getChatId(currentUid, peerId, listingId);
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('sent_at', descending: true)
        .snapshots();
  }

  /// Streams all Inbox threads for the current user.
  Stream<QuerySnapshot> getInboxStream() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return const Stream.empty();

    return _db
        .collection('chats')
        .where('participant_ids', arrayContains: currentUid)
        .orderBy('last_message_time', descending: true)
        .snapshots();
  }
}
