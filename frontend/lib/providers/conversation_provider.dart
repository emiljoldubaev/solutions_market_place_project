import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ConversationProvider extends ChangeNotifier {
  List<dynamic> _conversations = [];
  List<dynamic> _messages = [];
  bool _isLoading = false;
  int _unreadCount = 0;
  String? _error;

  List<dynamic> get conversations => _conversations;
  List<dynamic> get messages => _messages;
  bool get isLoading => _isLoading;
  int get unreadCount => _unreadCount;
  String? get error => _error;

  Future<Map<String, dynamic>> getOrCreateConversation(int listingId, int recipientId) async {
    _isLoading = true;
    notifyListeners();
    // Real implementation would POST to /conversations
    await Future.delayed(const Duration(milliseconds: 300));
    _isLoading = false;
    notifyListeners();
    return {
      'id': 1, 
      'listing': {'title': 'Listing', 'id': listingId},
      'recipient': {'full_name': 'Seller', 'id': recipientId}
    };
  }

  // Stubs for API integration
  Future<void> fetchMessages(int conversationId) async {}
  Future<void> sendMessage(int conversationId, String text) async {}
  void pollMessages() {}
}
