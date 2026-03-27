import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class PaymentProvider extends ChangeNotifier {
  List<dynamic> _packages = [];
  bool _isLoading = false;
  bool _isProcessing = false;
  String? _error;

  List<dynamic> get packages => _packages;
  bool get isLoading => _isLoading;
  bool get isProcessing => _isProcessing;
  String? get error => _error;

  Future<void> fetchPackages() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/promotions/packages'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _packages = data;
      } else {
        throw Exception('Failed to load promotion packages');
      }
    } catch (e) {
      _error = 'Network error fetching promotion plans.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Processes phases 1 & 2: Promotion Creation & Payment Initiation
  /// Returns the Payment JSON object containing transaction_id, amount, and id
  Future<Map<String, dynamic>> processPromotionFlow(int listingId, int packageId) async {
    if (_isProcessing) throw Exception('A transaction is already processing.');
    
    _isProcessing = true;
    _error = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) throw Exception('Not authenticated');

      // 1. Create Promotion
      final promoResponse = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/promotions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'listing_id': listingId,
          'package_id': packageId,
        }),
      );

      if (promoResponse.statusCode != 201 && promoResponse.statusCode != 200) {
        throw Exception(
          json.decode(promoResponse.body)['detail'] ?? 'Failed to initialize promotion record',
        );
      }
      
      final promoData = json.decode(promoResponse.body);
      final int promotionId = promoData['id'];

      // 2. Initiate Payment
      final paymentResponse = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/payments/initiate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'promotion_id': promotionId,
          'payment_method': 'card',
        }),
      );

      if (paymentResponse.statusCode != 200 && paymentResponse.statusCode != 201) {
        throw Exception(
          json.decode(paymentResponse.body)['detail'] ?? 'Failed to initiate secure payment gateway',
        );
      }

      // Return the payment object so checkout screen can render receipt details
      return json.decode(paymentResponse.body);

    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Processes phase 3: Mock Payment Confirmation targeting the exact backend endpoint
  Future<Map<String, dynamic>> confirmPayment(int paymentId, String mockStatus) async {
    if (_isProcessing) throw Exception('A transaction is already processing.');
    
    _isProcessing = true;
    _error = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) throw Exception('Not authenticated');

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/payments/$paymentId/confirm'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'mock_status': mockStatus,
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          json.decode(response.body)['detail'] ?? 'Gateway rejected the transaction confirmation',
        );
      }

      return json.decode(response.body);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }
}
