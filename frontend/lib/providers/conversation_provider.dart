import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../config/api_config.dart';

class ConversationProvider extends ChangeNotifier {
  List<dynamic> _conversations = [];
  Map<int, List<dynamic>> _messagesByConversation = {};
  bool _isLoading = false;
  int _unreadCount = 0;
  String? _error;

  List<dynamic> get conversations => _conversations;
  bool get isLoading => _isLoading;
  int get unreadCount => _unreadCount;
  String? get error => _error;

  List<dynamic> messagesFor(int conversationId) =>
      _messagesByConversation[conversationId] ?? [];

  Future<void> fetchConversations() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/conversations'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _conversations = data['items'] ?? [];
        _unreadCount = 0;
        for (final conv in _conversations) {
          _unreadCount += (conv['unread_count'] ?? 0) as int;
        }
      } else {
        _error = 'Failed to load conversations';
      }
    } catch (e) {
      _error = 'Network error. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> getOrCreateConversation(
      int listingId, int recipientId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/conversations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'listing_id': listingId,
          'recipient_id': recipientId,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else if (response.statusCode == 400) {
        throw Exception('Cannot message yourself');
      } else if (response.statusCode == 403) {
        throw Exception('Your account is restricted');
      } else if (response.statusCode == 404) {
        throw Exception('Listing or user not found');
      } else {
        throw Exception('Failed to start conversation');
      }
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMessages(int conversationId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.get(
        Uri.parse(
            '${ApiConfig.baseUrl}/conversations/$conversationId/messages?page=1&size=50'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _messagesByConversation[conversationId] = data['items'] ?? [];
      } else {
        _error = 'Failed to load messages';
      }
    } catch (e) {
      _error = 'Network error loading messages.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(int conversationId, String text,
      {XFile? attachment}) async {
    _error = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
            '${ApiConfig.baseUrl}/conversations/$conversationId/messages'),
      );
      request.headers['Authorization'] = 'Bearer $token';

      if (text.isNotEmpty) {
        request.fields['text_body'] = text;
      }

      if (attachment != null) {
        final bytes = await attachment.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: attachment.name,
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final message = json.decode(response.body);
        _messagesByConversation[conversationId] ??= [];
        _messagesByConversation[conversationId]!.add(message);
        notifyListeners();
      } else if (response.statusCode == 400) {
        throw Exception('Message must contain text or a file');
      } else if (response.statusCode == 401) {
        throw Exception('Session expired, please login again');
      } else if (response.statusCode == 403) {
        throw Exception('You are not a participant in this conversation');
      } else {
        throw Exception('Failed to send message');
      }
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    }
  }

  Future<void> markAsRead(int conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.post(
        Uri.parse(
            '${ApiConfig.baseUrl}/conversations/$conversationId/messages/mark-read'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        // Update the local conversation's unread count to 0
        for (final conv in _conversations) {
          if (conv['id'] == conversationId) {
            conv['unread_count'] = 0;
            break;
          }
        }
        // Recalculate total unread
        _unreadCount = 0;
        for (final conv in _conversations) {
          _unreadCount += (conv['unread_count'] ?? 0) as int;
        }
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to mark messages as read';
    }
  }
}
