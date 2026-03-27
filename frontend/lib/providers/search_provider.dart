import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

class SearchProvider extends ChangeNotifier {
  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  int _currentPage = 1;
  final int _pageSize = 20;

  /// Stores the persistent filters applied by the user
  Map<String, dynamic> _currentFilters = {
    'sort_by': 'newest', // default
  };

  List<dynamic> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;
  Map<String, dynamic> get currentFilters => _currentFilters;

  Future<void> performSearch(Map<String, dynamic> filters, {bool refresh = false}) async {
    if (_isLoading) return;

    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      _error = null;
      _currentFilters = Map<String, dynamic>.from(filters);
    } else if (!_hasMore) {
      return;
    }

    _isLoading = true;
    if (refresh) notifyListeners();

    try {
      final queryParams = <String, String>{
        'page': _currentPage.toString(),
        'size': _pageSize.toString(),
      };

      // Map filters rigidly onto backend Query parameters
      if (_currentFilters['search'] != null && _currentFilters['search'].toString().isNotEmpty) {
        queryParams['search'] = _currentFilters['search'];
      }
      if (_currentFilters['category_id'] != null) {
        queryParams['category_id'] = _currentFilters['category_id'].toString();
      }
      if (_currentFilters['city'] != null && _currentFilters['city'].toString().isNotEmpty) {
        queryParams['city'] = _currentFilters['city'];
      }
      if (_currentFilters['min_price'] != null) {
        queryParams['min_price'] = _currentFilters['min_price'].toString();
      }
      if (_currentFilters['max_price'] != null) {
        queryParams['max_price'] = _currentFilters['max_price'].toString();
      }
      if (_currentFilters['condition'] != null && _currentFilters['condition'].toString().isNotEmpty) {
        queryParams['condition'] = _currentFilters['condition'];
      }
      if (_currentFilters['sort_by'] != null && _currentFilters['sort_by'].toString().isNotEmpty) {
        queryParams['sort_by'] = _currentFilters['sort_by'];
      }

      final uri = Uri.parse('${ApiConfig.baseUrl}/listings').replace(queryParameters: queryParams);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> newItems = data['items'] ?? [];

        if (refresh) {
          _searchResults = newItems;
        } else {
          _searchResults.addAll(newItems);
        }

        _hasMore = newItems.length == _pageSize;
        _currentPage++;
      } else {
        throw Exception(json.decode(response.body)['detail'] ?? 'Failed to fetch search results');
      }
    } catch (e) {
      _error = 'Network error. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearFilters() {
    _currentFilters = {'sort_by': 'newest'};
    performSearch(_currentFilters, refresh: true);
  }
}
