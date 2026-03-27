import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/payment_provider.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../widgets/app_button.dart';
import '../../widgets/loading_skeleton.dart';

class PromoteListingScreen extends StatefulWidget {
  const PromoteListingScreen({Key? key}) : super(key: key);

  @override
  State<PromoteListingScreen> createState() => _PromoteListingScreenState();
}

class _PromoteListingScreenState extends State<PromoteListingScreen> {
  int? _selectedPackageId;
  Map<String, dynamic>? _listing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PaymentProvider>().fetchPackages();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_listing == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        _listing = args;
      }
    }
  }

  void _handleCheckout() async {
    if (_selectedPackageId == null || _listing == null) return;

    final provider = context.read<PaymentProvider>();
    try {
      final paymentSession = await provider.processPromotionFlow(
        _listing!['id'], 
        _selectedPackageId!,
      );
      
      if (!mounted) return;
      // Navigate to checkout providing the payment object and listing context
      Navigator.pushNamed(
        context, 
        '/checkout', 
        arguments: {
          'payment': paymentSession,
          'listing': _listing,
        },
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_listing == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Promote')),
        body: const Center(child: Text('Invalid Listing Provided')),
      );
    }

    final images = _listing!['images'] as List<dynamic>?;
    String imageUrl = '';
    if (images != null && images.isNotEmpty) {
      final rawUrl = images[0]['url']?.toString() ?? '';
      if (rawUrl.startsWith('http')) {
         imageUrl = rawUrl;
      } else if (rawUrl.isNotEmpty) {
         imageUrl = '${ApiConfig.baseUrl}$rawUrl';
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Boost Visibility'),
        elevation: 0,
      ),
      body: Consumer<PaymentProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }

          if (provider.error != null && provider.packages.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: AppTheme.error),
                    const SizedBox(height: 16),
                    Text(provider.error!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 24),
                    AppButton(text: 'Retry', onPressed: () => provider.fetchPackages()),
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Minimal Context Card (Airbnb Host style)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppTheme.cardShadow,
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const LoadingSkeleton(width: 80, height: 80),
                                errorWidget: (context, url, err) => Container(width: 80, height: 80, color: AppTheme.border, child: const Icon(Icons.broken_image)),
                              )
                            : Container(
                                width: 80,
                                height: 80,
                                color: AppTheme.border,
                                child: const Icon(Icons.image_not_supported, color: AppTheme.textSecondary),
                              ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _listing!['title'] ?? 'Listing',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_listing!['currency'] ?? 'USD'} ${_listing!['price']}',
                              style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                Text(
                  'Select a Promotion Tier',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sponsored items are pinned to the top of relevant search feeds guaranteeing massive exposure.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 24),

                ...provider.packages.map((pkg) {
                  final bool isSelected = _selectedPackageId == pkg['id'];
                  return GestureDetector(
                    onTap: () {
                      if (!provider.isProcessing) {
                        setState(() => _selectedPackageId = pkg['id']);
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primary.withOpacity(0.04) : AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppTheme.primary : AppTheme.border,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected ? [] : AppTheme.cardShadow,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        pkg['name'] ?? '',
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${pkg['currency'] ?? 'USD'} ${pkg['price']}',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  pkg['description'] ?? '',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.background,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${pkg['duration_days']} Days',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),

                const SizedBox(height: 48), // Padding for the bottom safe area
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Consumer<PaymentProvider>(
            builder: (context, provider, child) {
              return AppButton(
                text: 'Proceed to Checkout',
                isLoading: provider.isProcessing,
                onPressed: _selectedPackageId != null && !provider.isProcessing
                    ? _handleCheckout
                    : null,
              );
            },
          ),
        ),
      ),
    );
  }
}
