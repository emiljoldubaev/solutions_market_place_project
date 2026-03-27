import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class AuthService {
  Future<Map<String, dynamic>> login(String email, String password) async {
    // API uses OAuth2PasswordRequestForm (form-data)
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.login}'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'username': email,
        'password': password,
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception(json.decode(response.body)['detail'] ?? 'Failed to login');
    }
  }

  Future<Map<String, dynamic>> register(String fullName, String email, String password) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.register}'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'full_name': fullName,
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception(json.decode(response.body)['detail'] ?? 'Failed to register');
    }
  }

  Future<Map<String, dynamic>> getMe(String token) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.me}'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch user profile');
    }
  }
}
