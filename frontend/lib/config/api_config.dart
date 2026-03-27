class ApiConfig {
  // Use 10.0.2.2 for Android emulator, 127.0.0.1 for iOS simulator / web
  static const String baseUrl = 'http://10.0.2.2:8000';
  
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String me = '/users/me';
  static const String logout = '/auth/logout';
}
