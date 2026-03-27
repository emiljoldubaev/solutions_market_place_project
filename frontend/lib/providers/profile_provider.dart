import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

class ProfileProvider extends ChangeNotifier {
  Map<String, dynamic>? _profile;
  List<dynamic> _listings = [];
  
  bool _isProfileLoading = false;
  bool _isListingsLoading = false;
  String? _error;
  
  int _currentPage = 1;
  bool _hasMore = true;
  final int _pageSize = 20;

  Map<String, dynamic>? get profile => _profile;
  List<dynamic> get listings => _listings;
  bool get isProfileLoading => _isProfileLoading;
  bool get isListingsLoading => _isListingsLoading;
  bool get isLoading => _isProfileLoading || _isListingsLoading;
  String? get error => _error;
  bool get hasMore => _hasMore;

  Future<void> fetchProfile(int userId) async {
    _isProfileLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/users/$userId/public'),
      );

      if (response.statusCode == 200) {
        _profile = json.decode(response.body);
      } else {
        throw Exception(
          json.decode(response.body)['detail'] ?? 'Failed to load profile',
        );
      }
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isProfileLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchProfileListings(int userId, {bool refresh = false, String sortBy = 'newest'}) async {
    if (_isListingsLoading) return;
    
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      _error = null;
    } else if (!_hasMore) {
      return;
    }

    _isListingsLoading = true;
    if (refresh) notifyListeners();

    try {
      // Adding standard query parameters mapping to backend constraints
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/users/$userId/listings?page=$_currentPage&size=$_pageSize&sort_by=$sortBy'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> newItems = data['items'] ?? [];
        
        if (refresh) {
          _listings = newItems;
        } else {
          _listings.addAll(newItems);
        }
        
        _hasMore = newItems.length == _pageSize;
        _currentPage++;
      } else {
        throw Exception(
          json.decode(response.body)['detail'] ?? 'Failed to load listings',
        );
      }
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isListingsLoading = false;
      notifyListeners();
    }
  }

  void reset() {
    _profile = null;
    _listings = [];
    _error = null;
    _currentPage = 1;
    _hasMore = true;
    notifyListeners();
  }
}
