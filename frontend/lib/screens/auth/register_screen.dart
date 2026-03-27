import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../config/theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = "Passwords do not match";
      });
      return;
    }

    setState(() {
      _errorMessage = null;
    });

    try {
      await context.read<AuthProvider>().register(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: BackButton(color: AppTheme.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Create Account',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Join the marketplace today',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 32),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.error.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              AppTextField(
                label: 'Full Name',
                hint: 'Enter your full name',
                controller: _nameController,
                prefixIcon: const Icon(Icons.person_outline, color: AppTheme.textSecondary),
                validator: (value) => 
                    value == null || value.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 20),

              AppTextField(
                label: 'Email Address',
                hint: 'Enter your email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.textSecondary),
                validator: (value) => 
                    value == null || value.isEmpty ? 'Email is required' : null,
              ),
              const SizedBox(height: 20),
              
              AppTextField(
                label: 'Password',
                hint: 'Create a strong password',
                controller: _passwordController,
                obscureText: true,
                prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.textSecondary),
                validator: (value) => 
                    value != null && value.length < 6 ? 'Password must be at least 6 characters' : null,
              ),
              const SizedBox(height: 20),

              AppTextField(
                label: 'Confirm Password',
                hint: 'Repeat your password',
                controller: _confirmPasswordController,
                obscureText: true,
                prefixIcon: const Icon(Icons.lock_reset, color: AppTheme.textSecondary),
                validator: (value) => 
                    value == null || value.isEmpty ? 'Please confirm password' : null,
              ),
              const SizedBox(height: 32),

              AppButton(
                text: 'Sign Up',
                isLoading: authProvider.isLoading,
                onPressed: _handleRegister,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
