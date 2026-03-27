import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../widgets/app_button.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user ?? {};

    final name = user['full_name'] ?? 'User';
    final email = user['email'] ?? 'email@example.com';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    
    final listingsCount = user['active_listings_count'] ?? 0;
    final favoritesCount = user['favorites_count'] ?? 0;
    final joinDate = user['created_at']?.toString().split('T').first ?? 'Recently';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('My Profile'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Avatar & Basic Info
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppTheme.primary.withOpacity(0.1),
                    child: Text(
                      initials,
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: AppTheme.primary,
                        fontSize: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(name, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text(email, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Stats Row
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
                  _buildStat(context, 'Listings', listingsCount.toString()),
                  Container(width: 1, height: 40, color: AppTheme.border),
                  _buildStat(context, 'Favorites', favoritesCount.toString()),
                  Container(width: 1, height: 40, color: AppTheme.border),
                  _buildStat(context, 'Joined', joinDate, isDate: true),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Actions
            _buildActionTile(context, Icons.edit, 'Edit Profile', () {}),
            const SizedBox(height: 12),
            _buildActionTile(context, Icons.language, 'Language (EN/RU)', () {}),
            const SizedBox(height: 32),

            AppButton(
              text: 'Logout',
              isSecondary: true,
              onPressed: () async {
                await authProvider.logout();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(BuildContext context, String label, String value, {bool isDate = false}) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontSize: isDate ? 16 : null, // smaller font for date
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile(BuildContext context, IconData icon, String title, VoidCallback onTap) {
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
              child: Text(title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.border),
          ],
        ),
      ),
    );
  }
}
