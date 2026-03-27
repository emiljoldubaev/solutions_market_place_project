import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/listing_provider.dart';
import 'providers/conversation_provider.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/auth/language_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/listing/create_listing_screen.dart';
import 'screens/listing/edit_listing_screen.dart';
import 'screens/listing/listing_detail_screen.dart';
import 'screens/listing/my_listings_screen.dart';
import 'screens/listing/favorites_screen.dart';
import 'screens/messaging/conversation_detail_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/profile/owner_public_profile_screen.dart';
import 'screens/listing/promote_listing_screen.dart';
import 'screens/payment/mock_checkout_screen.dart';
import 'screens/search/search_screen.dart';
import 'providers/favorite_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/payment_provider.dart';
import 'providers/search_provider.dart';

// ── Locale Provider ──
class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  Future<void> loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('locale') ?? 'en';
    _locale = Locale(code);
    notifyListeners();
  }

  Future<void> setLocale(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', code);
    _locale = Locale(code);
    notifyListeners();
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ListingProvider()),
        ChangeNotifierProvider(create: (_) => ConversationProvider()),
        ChangeNotifierProvider(create: (_) => FavoriteProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()..loadLocale()),
      ],
      child: const MarketplaceApp(),
    ),
  );
}

class MarketplaceApp extends StatelessWidget {
  const MarketplaceApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Marketplace',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: context.watch<LocaleProvider>().locale,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/language': (context) => const LanguageScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/create-listing': (context) => const CreateListingScreen(),
        '/edit-listing': (context) => const EditListingScreen(),
        '/listing-detail': (context) => const ListingDetailScreen(),
        '/my-listings': (context) => const MyListingsScreen(),
        '/conversation-detail': (context) => const ConversationDetailScreen(),
        '/favorites': (context) => const FavoritesScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/owner-profile': (context) => const OwnerPublicProfileScreen(),
        '/promote': (context) => const PromoteListingScreen(),
        '/checkout': (context) => const MockCheckoutScreen(),
        '/search': (context) => const SearchScreen(),
      },
    );
  }
}
