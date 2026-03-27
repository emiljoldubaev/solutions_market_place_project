import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ListingProvider extends ChangeNotifier {
  List<dynamic> _listings = [];
  List<dynamic> _myListings = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  
  List<dynamic> get listings => _listings;
  List<dynamic> get myListings => _myListings;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;

  int _currentPage = 1;

  Future<void> fetchListings({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _listings.clear();
      _hasMore = true;
    }

    if (!_hasMore || _isLoading) return;

    _isLoading = true;
    _error = null;
    if (refresh) notifyListeners();

    try {
      // Typically, categories/filters would be appended here
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/listings?page=$_currentPage&size=20'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> newItems = data['items'] ?? [];
        
        if (newItems.isEmpty) {
          _hasMore = false;
        } else {
          _listings.addAll(newItems);
          _currentPage++;
        }
      } else {
        _error = 'Failed to load listings';
      }
    } catch (e) {
      _error = 'Network error. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMyListings() async {
    // Stub for now, to be implemented fully later alongside UI
    _isLoading = true;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/users/me/listings'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _myListings = data['items'] ?? [];
      } else {
        _error = 'Failed to load your listings';
      }
    } catch (e) {
      _error = 'Network error.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createListing(Map<String, dynamic> data) async {
    // Stub
  }

  Future<void> deleteListing(int id) async {
    // Stub
  }
}
