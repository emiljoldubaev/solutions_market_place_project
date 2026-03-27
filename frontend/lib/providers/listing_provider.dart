import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../config/api_config.dart';
import '../models/category.dart';

class ListingProvider extends ChangeNotifier {
  List<dynamic> _listings = [];
  List<dynamic> _myListings = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;

  List<Category> _categories = [];
  bool _categoriesLoading = false;
  bool _isCreating = false;

  List<dynamic> get listings => _listings;
  List<dynamic> get myListings => _myListings;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;

  List<Category> get categories => _categories;
  bool get categoriesLoading => _categoriesLoading;
  bool get isCreating => _isCreating;

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
    _isLoading = true;
    _error = null;
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

  Future<void> fetchCategories() async {
    if (_categories.isNotEmpty) return;

    _categoriesLoading = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/categories'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _categories = data
            .map((c) => Category.fromJson(c))
            .where((c) => c.isActive)
            .toList()
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      } else {
        _error = 'Failed to load categories';
      }
    } catch (e) {
      _error = 'Network error loading categories';
    } finally {
      _categoriesLoading = false;
      notifyListeners();
    }
  }

  Future<void> createListing(
    Map<String, dynamic> data, {
    List<XFile> images = const [],
  }) async {
    _isCreating = true;
    _error = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      // Step 1: Create listing
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/listings'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(data),
      );

      if (response.statusCode == 401) {
        throw Exception('Session expired, please login again');
      }
      if (response.statusCode == 422) {
        final detail = json.decode(response.body)['detail'];
        throw Exception(detail?.toString() ?? 'Validation error');
      }
      if (response.statusCode != 201) {
        throw Exception(
          json.decode(response.body)['detail'] ?? 'Failed to create listing',
        );
      }

      final createdListing = json.decode(response.body);
      final listingId = createdListing['id'];

      // Step 2: Upload images one by one
      for (final image in images) {
        try {
          final bytes = await image.readAsBytes();
          final request = http.MultipartRequest(
            'POST',
            Uri.parse('${ApiConfig.baseUrl}/listings/$listingId/images'),
          );
          request.headers['Authorization'] = 'Bearer $token';
          request.files.add(http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: image.name,
          ));
          await request.send();
        } catch (_) {
          // Skip this image, continue with next
        }
      }

      // Step 3: Prepend to myListings
      _myListings.insert(0, createdListing);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  Future<void> deleteListing(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/listings/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        _myListings.removeWhere((l) => l['id'] == id);
        notifyListeners();
      } else if (response.statusCode == 403) {
        throw Exception('You do not have permission to delete this listing');
      } else if (response.statusCode == 404) {
        throw Exception('Listing not found');
      } else {
        throw Exception('Failed to delete listing');
      }
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    }
  }
}
