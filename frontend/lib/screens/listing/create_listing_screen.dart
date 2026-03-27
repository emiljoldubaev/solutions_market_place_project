import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../config/theme.dart';
import '../../providers/listing_provider.dart';
import '../../main.dart';

class CreateListingScreen extends StatefulWidget {
  const CreateListingScreen({Key? key}) : super(key: key);

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _cityController = TextEditingController();

  String _selectedCurrency = 'USD';
  int? _selectedCategoryId;
  String? _selectedCondition;
  String _selectedContactPref = 'both';
  bool _isNegotiable = false;
  List<XFile> _selectedImages = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ListingProvider>().fetchCategories();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _cityController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('New Listing'),
        leading: BackButton(color: AppTheme.primaryDark),
        elevation: 0,
        backgroundColor: AppTheme.background,
      ),
      body: Consumer<ListingProvider>(
        builder: (context, provider, _) {
          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader('Listing Details'),
                  const SizedBox(height: 12),
                  _titleField(),
                  const SizedBox(height: 16),
                  _descriptionField(),
                  const SizedBox(height: 16),
                  _priceRow(),
                  const SizedBox(height: 24),
                  _sectionHeader('Category & Location'),
                  const SizedBox(height: 12),
                  _categoryDropdown(provider),
                  const SizedBox(height: 16),
                  _cityField(),
                  const SizedBox(height: 24),
                  _sectionHeader('Item Details'),
                  const SizedBox(height: 12),
                  _conditionDropdown(),
                  const SizedBox(height: 16),
                  _contactPrefDropdown(),
                  const SizedBox(height: 8),
                  _negotiableSwitch(),
                  const SizedBox(height: 24),
                  _sectionHeader('Photos  ${_selectedImages.length}/8'),
                  const SizedBox(height: 12),
                  _imageGrid(),
                  const SizedBox(height: 32),
                  _submitButton(provider),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
            letterSpacing: 0.5,
          ),
    );
  }

  Widget _titleField() {
    return TextFormField(
      controller: _titleController,
      maxLength: 200,
      decoration: const InputDecoration(
        labelText: 'Title',
        hintText: 'What are you selling?',
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Title is required';
        if (v.trim().length < 5) return 'Title must be at least 5 characters';
        if (v.trim().length > 200) return 'Title must be under 200 characters';
        return null;
      },
    );
  }

  Widget _descriptionField() {
    return TextFormField(
      controller: _descriptionController,
      maxLines: 5,
      minLines: 4,
      maxLength: 2000,
      decoration: const InputDecoration(
        labelText: 'Description',
        hintText: 'Describe your item in detail',
        alignLabelWithHint: true,
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Description is required';
        if (v.trim().length < 20) {
          return 'Description must be at least 20 characters';
        }
        return null;
      },
    );
  }

  Widget _priceRow() {
    return Row(
      children: [
        Expanded(
          flex: 65,
          child: TextFormField(
            controller: _priceController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Price'),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Price is required';
              final parsed = double.tryParse(v.trim());
              if (parsed == null) return 'Enter a valid number';
              if (parsed < 0) return 'Price cannot be negative';
              return null;
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 35,
          child: DropdownButtonFormField<String>(
            value: _selectedCurrency,
            decoration: const InputDecoration(labelText: 'Currency'),
            items: ['USD', 'KGS', 'RUB']
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _selectedCurrency = v!),
          ),
        ),
      ],
    );
  }

  Widget _categoryDropdown(ListingProvider provider) {
    final isRu =
        context.read<LocaleProvider>().locale.languageCode == 'ru';

    if (provider.categoriesLoading) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primary,
            ),
          ),
        ),
      );
    }

    return DropdownButtonFormField<int>(
      value: _selectedCategoryId,
      decoration: const InputDecoration(labelText: 'Category'),
      hint: const Text('Select a category'),
      items: provider.categories.map((cat) {
        final label =
            isRu && cat.nameRu.isNotEmpty ? cat.nameRu : cat.name;
        return DropdownMenuItem<int>(
          value: cat.id,
          child: Text(label),
        );
      }).toList(),
      onChanged: (v) => setState(() => _selectedCategoryId = v),
      validator: (v) => v == null ? 'Please select a category' : null,
    );
  }

  Widget _cityField() {
    return TextFormField(
      controller: _cityController,
      decoration: const InputDecoration(
        labelText: 'City',
        hintText: 'e.g. Bishkek',
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'City is required';
        return null;
      },
    );
  }

  Widget _conditionDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCondition,
      decoration: const InputDecoration(labelText: 'Condition'),
      items: const [
        DropdownMenuItem(value: null, child: Text('Not specified')),
        DropdownMenuItem(value: 'new', child: Text('New')),
        DropdownMenuItem(value: 'like_new', child: Text('Like New')),
        DropdownMenuItem(value: 'good', child: Text('Good')),
        DropdownMenuItem(value: 'fair', child: Text('Fair')),
        DropdownMenuItem(value: 'poor', child: Text('Poor')),
      ],
      onChanged: (v) => setState(() => _selectedCondition = v),
    );
  }

  Widget _contactPrefDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedContactPref,
      decoration: const InputDecoration(labelText: 'Contact Preference'),
      items: const [
        DropdownMenuItem(value: 'both', child: Text('Chat & Phone')),
        DropdownMenuItem(value: 'chat', child: Text('Chat only')),
        DropdownMenuItem(value: 'phone', child: Text('Phone only')),
      ],
      onChanged: (v) => setState(() => _selectedContactPref = v!),
    );
  }

  Widget _negotiableSwitch() {
    return SwitchListTile(
      value: _isNegotiable,
      onChanged: (v) => setState(() => _isNegotiable = v),
      title: Text('Price is negotiable',
          style: Theme.of(context).textTheme.bodyLarge),
      activeColor: AppTheme.primary,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _imageGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ..._selectedImages.asMap().entries.map((entry) {
          final index = entry.key;
          final image = entry.value;
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(image.path),
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _selectedImages.removeAt(index)),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppTheme.error,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        }),
        if (_selectedImages.length < 8)
          GestureDetector(
            onTap: _pickImages,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border, width: 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_photo_alternate_outlined,
                      color: AppTheme.primary, size: 28),
                  const SizedBox(height: 4),
                  Text(
                    'Add Photo',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isEmpty) return;

    final remaining = 8 - _selectedImages.length;
    final toAdd = picked.take(remaining).toList();

    setState(() => _selectedImages.addAll(toAdd));

    if (picked.length > remaining && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 8 photos allowed')),
      );
    }
  }

  Widget _submitButton(ListingProvider provider) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: provider.isCreating ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          disabledBackgroundColor: AppTheme.primary.withOpacity(0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: provider.isCreating
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : const Text(
                'Post Listing',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      return;
    }
    _formKey.currentState!.save();

    final data = <String, dynamic>{
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'price': double.parse(_priceController.text.trim()),
      'currency': _selectedCurrency,
      'category_id': _selectedCategoryId,
      'city': _cityController.text.trim(),
      'contact_preference': _selectedContactPref,
      'is_negotiable': _isNegotiable,
    };
    if (_selectedCondition != null) {
      data['condition'] = _selectedCondition;
    }

    try {
      await context.read<ListingProvider>().createListing(
            data,
            images: _selectedImages,
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Listing submitted for review'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }
}
