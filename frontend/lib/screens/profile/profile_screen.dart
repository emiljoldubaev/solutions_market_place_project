import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../widgets/app_button.dart';
import '../../main.dart'; // for LocaleProvider

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user ?? {};

    final name = user['full_name'] ?? 'User';
    final email = user['email'] ?? 'email@example.com';
    final city = user['city'] ?? 'City not set';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    final listingsCount = user['active_listings_count'] ?? 0;
    final joinDate = user['created_at']?.toString().split('T').first ?? 'Recently';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('My Profile'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // ── Avatar & Info ──
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppTheme.primary.withOpacity(0.1),
                    child: Text(
                      initials,
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            color: AppTheme.primary, fontSize: 40),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(name, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text(email,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_on,
                          size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(city,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppTheme.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── Stats Row ──
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStat(context, listingsCount.toString(), 'Listings'),
                  Container(width: 1, height: 40, color: AppTheme.border),
                  _buildStat(context, joinDate, 'Member Since', isSmall: true),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Actions ──
            _buildActionTile(context, Icons.edit, 'Edit Profile', () {
              // TODO: navigate to edit profile screen
            }),
            const SizedBox(height: 12),
            _buildActionTile(context, Icons.inventory_2_outlined, 'My Listings',
                () {
              Navigator.pushNamed(context, '/my-listings');
            }),
            const SizedBox(height: 24),

            // ── Language Switcher ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Language',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  _LanguageSwitcher(),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── Logout ──
            AppButton(
              text: 'Logout',
              isSecondary: true,
              onPressed: () => _showLogoutDialog(context, authProvider),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Logout',
            style: Theme.of(context).textTheme.headlineSmall),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await authProvider.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(BuildContext context, String value, String label,
      {bool isSmall = false}) {
    return Column(
      children: [
        Text(value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.primary,
                  fontSize: isSmall ? 14 : null,
                )),
        const SizedBox(height: 4),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildActionTile(
      BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
                child: Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600))),
            const Icon(Icons.chevron_right, color: AppTheme.border),
          ],
        ),
      ),
    );
  }
}

// ── Language Switcher Widget ──
class _LanguageSwitcher extends StatefulWidget {
  @override
  State<_LanguageSwitcher> createState() => _LanguageSwitcherState();
}

class _LanguageSwitcherState extends State<_LanguageSwitcher> {
  String _currentLocale = 'en';

  @override
  void initState() {
    super.initState();
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentLocale = prefs.getString('locale') ?? 'en';
    });
  }

  Future<void> _setLocale(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', code);
    setState(() => _currentLocale = code);
    context.read<LocaleProvider>().setLocale(code);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _langButton(context, 'EN', 'en'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _langButton(context, 'RU', 'ru'),
        ),
      ],
    );
  }

  Widget _langButton(BuildContext context, String label, String code) {
    final isSelected = _currentLocale == code;
    return GestureDetector(
      onTap: () => _setLocale(code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ),
    );
  }
}
