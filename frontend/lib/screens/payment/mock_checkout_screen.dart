import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/payment_provider.dart';
import '../../config/theme.dart';
import '../../widgets/app_button.dart';

class MockCheckoutScreen extends StatefulWidget {
  const MockCheckoutScreen({Key? key}) : super(key: key);

  @override
  State<MockCheckoutScreen> createState() => _MockCheckoutScreenState();
}

class _MockCheckoutScreenState extends State<MockCheckoutScreen> {
  Map<String, dynamic>? _paymentMap;
  Map<String, dynamic>? _listingMap;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_paymentMap == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        _paymentMap = args['payment'] as Map<String, dynamic>?;
        _listingMap = args['listing'] as Map<String, dynamic>?;
      }
    }
  }

  void _completeTransaction(String mockStatus) async {
    if (_paymentMap == null) return;
    final paymentId = _paymentMap!['id'];
    if (paymentId == null) return;

    final provider = context.read<PaymentProvider>();

    try {
      final finalState = await provider.confirmPayment(paymentId, mockStatus);

      if (!mounted) return;
      
      if (finalState['status'] == 'successful') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment Successful! Listing is now actively promoted.'),
            backgroundColor: AppTheme.primary,
          ),
        );
        // Pop all the way back to home feed or my-listings
        Navigator.popUntil(context, ModalRoute.withName('/home'));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaction returned state: ${finalState['status']}'),
            backgroundColor: AppTheme.error,
          ),
        );
        Navigator.pop(context); // Go back to promotion select to try again
      }

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
    if (_paymentMap == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: const Center(child: Text('Invalid Checkout Session')),
      );
    }

    final String amountRender = '${_paymentMap!['currency'] ?? 'USD'} ${_paymentMap!['amount'] ?? '0.00'}';
    final String trxId = _paymentMap!['transaction_id'] ?? 'TRX-UNKNOWN';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Checkout Simulation'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Receipt Card
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.cardShadow,
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 64, color: AppTheme.primary),
                  const SizedBox(height: 24),
                  Text(
                    amountRender,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total Amount Due',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 32),
                  
                  _buildReceiptRow('Listing ID', '#${_listingMap?['id'] ?? 'N/A'}'),
                  const SizedBox(height: 16),
                  _buildReceiptRow('Method', (_paymentMap!['payment_method'] ?? 'Card').toString().toUpperCase()),
                  const SizedBox(height: 16),
                  _buildReceiptRow('Transaction ID', trxId),
                ],
              ),
            ),

            const SizedBox(height: 48),

            // Action Buttons
            Text(
              'Select a mock response below to test gateway behavior.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),

            Consumer<PaymentProvider>(
              builder: (context, provider, child) {
                return Column(
                  children: [
                    AppButton(
                      text: 'Simulate Successful Payment',
                      isLoading: provider.isProcessing,
                      onPressed: provider.isProcessing ? null : () => _completeTransaction('success'),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: provider.isProcessing ? null : () => _completeTransaction('fail'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        side: BorderSide(color: provider.isProcessing ? AppTheme.border : AppTheme.error.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Simulate Transaction Failure', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
      ],
    );
  }
}
