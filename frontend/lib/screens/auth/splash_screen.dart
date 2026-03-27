import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAppState();
  }

  Future<void> _checkAppState() async {
    // Wait for minimum splash duration to show the brand
    await Future.delayed(const Duration(milliseconds: 1500));
    
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final hasSelectedLanguage = prefs.getBool('has_selected_language') ?? false;

    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();

    // If auth state is still loading from storage, wait
    while (!authProvider.isInitialized) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (!mounted) return;

    if (!hasSelectedLanguage) {
      Navigator.of(context).pushReplacementNamed('/language');
    } else {
      if (authProvider.isAuthenticated) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront, size: 80, color: Colors.white),
            SizedBox(height: 24),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
