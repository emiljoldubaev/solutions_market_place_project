import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class FavoriteProvider extends ChangeNotifier {
  List<dynamic> _favorites = [];
  final Set<int> _favoriteIds = {};
  
  bool _isLoading = false;
  bool _isToggling = false;
  String? _error;
  
  // Pagination
  int _currentPage = 1;
  bool _hasMore = true;
  final int _pageSize = 20;

  List<dynamic> get favorites => _favorites;
  Set<int> get favoriteIds => _favoriteIds;
  bool get isLoading => _isLoading;
  bool get isToggling => _isToggling;
  String? get error => _error;
  bool get hasMore => _hasMore;

  bool isFavorite(int listingId) => _favoriteIds.contains(listingId);

  Future<void> fetchFavorites({bool refresh = false}) async {
    if (_isLoading) return;
    
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      _error = null;
    } else if (!_hasMore) {
      return;
    }

    _isLoading = true;
    if (refresh) _error = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) throw Exception('Not authenticated');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/favorites?page=$_currentPage&size=$_pageSize'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> newItems = data['items'] ?? [];
        
        if (refresh) {
          _favorites = newItems;
          _favoriteIds.clear();
        } else {
          _favorites.addAll(newItems);
        }
        
        for (final item in newItems) {
          if (item['listing'] != null && item['listing']['id'] != null) {
            _favoriteIds.add(item['listing']['id'] as int);
          }
        }
        
        _hasMore = newItems.length == _pageSize;
        _currentPage++;
      } else {
        throw Exception(
          json.decode(response.body)['detail'] ?? 'Failed to load favorites',
        );
      }
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(int listingId) async {
    _isToggling = true;
    notifyListeners();

    final bool currentlyFavorited = isFavorite(listingId);

    // Optimistically update local state
    if (currentlyFavorited) {
      _favoriteIds.remove(listingId);
      _favorites.removeWhere((item) => item['id'] == listingId);
    } else {
      _favoriteIds.add(listingId);
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) throw Exception('Not authenticated');

      http.Response response;
      if (currentlyFavorited) {
        response = await http.delete(
          Uri.parse('${ApiConfig.baseUrl}/favorites/$listingId'),
          headers: {'Authorization': 'Bearer $token'},
        );
      } else {
        response = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/favorites/$listingId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      }

      final isSuccess = response.statusCode == 200 || response.statusCode == 201;

      // Handle conflict if trying to post a duplicate duplicate
      if (!isSuccess && response.statusCode != 409) {
        throw Exception(
          json.decode(response.body)['detail'] ?? 'Failed to toggle favorite',
        );
      } else if (isSuccess && !currentlyFavorited) {
        // Silently sync the list in the background since we just added an ID but don't have the object
        fetchFavorites(refresh: true);
      }

    } catch (e) {
      // Rollback on error
      if (currentlyFavorited) {
        _favoriteIds.add(listingId);
      } else {
        _favoriteIds.remove(listingId);
      }
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      rethrow;
    } finally {
      _isToggling = false;
      notifyListeners();
    }
  }

  Future<void> checkFavorite(int listingId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) return;

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/favorites/check/$listingId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final bool isFavorited = data['is_favorited'] ?? false;
        if (isFavorited) {
          _favoriteIds.add(listingId);
        } else {
          _favoriteIds.remove(listingId);
        }
        notifyListeners();
      }
    } catch (_) {
      // Silently fail checking
    }
  }
}
