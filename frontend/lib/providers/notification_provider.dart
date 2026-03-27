import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class NotificationProvider extends ChangeNotifier {
  List<dynamic> _notifications = [];
  int _unreadCount = 0;
  
  bool _isLoading = false;
  String? _error;
  
  int _currentPage = 1;
  bool _hasMore = true;
  final int _pageSize = 20;

  List<dynamic> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMore => _hasMore;

  Future<void> fetchNotifications({bool refresh = false}) async {
    if (_isLoading) return;
    
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      _error = null;
      // Also silently update unread count on refresh
      fetchUnreadCount();
    } else if (!_hasMore) {
      return;
    }

    _isLoading = true;
    if (refresh) notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) throw Exception('Not authenticated');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/notifications?page=$_currentPage&size=$_pageSize'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> newItems = data['items'] ?? [];
        
        if (refresh) {
          _notifications = newItems;
        } else {
          _notifications.addAll(newItems);
        }
        
        _hasMore = newItems.length == _pageSize;
        _currentPage++;
      } else {
        throw Exception(
          json.decode(response.body)['detail'] ?? 'Failed to load notifications',
        );
      }
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchUnreadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) return;

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/notifications/unread-count'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _unreadCount = data['unread_count'] ?? 0;
        notifyListeners();
      }
    } catch (_) {
      // Silently fail for badge updates
    }
  }

  Future<void> markAsRead(int notificationId) async {
    // Check if already read to avoid redundant calls
    final index = _notifications.indexWhere((n) => n['id'] == notificationId);
    if (index == -1) return;
    if (_notifications[index]['is_read'] == true) return;

    // Optimistic Update
    _notifications[index]['is_read'] = true;
    if (_unreadCount > 0) _unreadCount--;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) throw Exception('Not authenticated');

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/notifications/$notificationId/read'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to mark as read');
      }
    } catch (e) {
      // Rollback
      _notifications[index]['is_read'] = false;
      _unreadCount++;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> markAllAsRead() async {
    // Optimistic Update
    final List<dynamic> previousState = List.from(_notifications.map((n) => Map.from(n)));
    final int previousCount = _unreadCount;

    for (var n in _notifications) {
      n['is_read'] = true;
    }
    _unreadCount = 0;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) throw Exception('Not authenticated');

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/notifications/read-all'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to mark all as read');
      }
    } catch (e) {
      // Rollback
      _notifications = previousState;
      _unreadCount = previousCount;
      notifyListeners();
      rethrow;
    }
  }
}
