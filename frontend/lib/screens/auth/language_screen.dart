import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/theme.dart';
import '../../widgets/app_button.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({Key? key}) : super(key: key);

  Future<void> _selectLanguage(BuildContext context, String langCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', langCode);
    await prefs.setBool('has_selected_language', true);
    
    if (context.mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.language, size: 80, color: AppTheme.primary),
              const SizedBox(height: 32),
              Text(
                'Choose your language\nВыберите язык',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              AppButton(
                text: 'English',
                onPressed: () => _selectLanguage(context, 'en'),
              ),
              const SizedBox(height: 16),
              AppButton(
                text: 'Русский',
                isSecondary: true,
                onPressed: () => _selectLanguage(context, 'ru'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
