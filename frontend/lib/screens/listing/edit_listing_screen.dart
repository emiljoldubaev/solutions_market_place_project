import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../providers/listing_provider.dart';
import '../../config/theme.dart';
import '../../widgets/empty_state.dart';
import '../../main.dart';

class EditListingScreen extends StatefulWidget {
  const EditListingScreen({Key? key}) : super(key: key);

  @override
  State<EditListingScreen> createState() => _EditListingScreenState();
}

class _EditListingScreenState extends State<EditListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  late TextEditingController _titleController;
  late TextEditingController _priceController;
  late TextEditingController _descriptionController;
  late TextEditingController _cityController;

  String _selectedCurrency = 'USD';
  int? _selectedCategoryId;
  String? _selectedCondition;
  String _status = 'active';
  List<XFile> _newImages = [];
  List<Map<String, dynamic>> _existingImages = [];

  Map<String, dynamic>? _listing;
  int? _listingId;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        _listing = args;
        _listingId = _listing!['id'];
        _titleController = TextEditingController(text: _listing!['title'] ?? '');
        _priceController = TextEditingController(text: _listing!['price']?.toString() ?? '');
        _descriptionController = TextEditingController(text: _listing!['description'] ?? '');
        _cityController = TextEditingController(text: _listing!['city'] ?? '');
        _selectedCurrency = _listing!['currency'] ?? 'USD';
        _selectedCategoryId = _listing!['category_id'];
        _selectedCondition = _listing!['condition'];
        _status = _listing!['status'] ?? 'draft';

        // Parse existing images from the listing payload
        final rawImages = _listing!['images'] as List<dynamic>? ?? [];
        _existingImages = rawImages.map((img) => Map<String, dynamic>.from(img as Map)).toList();
      } else {
        _titleController = TextEditingController();
        _priceController = TextEditingController();
        _descriptionController = TextEditingController();
        _cityController = TextEditingController();
      }
      _initialized = true;

      // Load categories for the dropdown
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ListingProvider>().fetchCategories();
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _cityController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isEmpty) return;

    final totalCurrent = _existingImages.length + _newImages.length;
    final remaining = 8 - totalCurrent;
    final toAdd = picked.take(remaining).toList();

    setState(() => _newImages.addAll(toAdd));

    if (picked.length > remaining && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 8 photos allowed')),
      );
    }
  }

  Future<void> _handleUpdate() async {
    if (!_formKey.currentState!.validate() || _listingId == null) return;

    final provider = context.read<ListingProvider>();

    // Build payload — exclude 'status' (not in ListingUpdate schema)
    final data = <String, dynamic>{
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
      'currency': _selectedCurrency,
      'city': _cityController.text.trim(),
    };
    if (_selectedCategoryId != null) data['category_id'] = _selectedCategoryId;
    if (_selectedCondition != null) data['condition'] = _selectedCondition;

    try {
      // Step 1: Update listing metadata
      await provider.updateListing(_listingId!, data);

      // Step 2: Upload any new images
      if (_newImages.isNotEmpty) {
        await provider.uploadImages(_listingId!, _newImages);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Listing updated successfully!'),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.pop(context, true);
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
    if (_listing == null || _listingId == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(elevation: 0, backgroundColor: AppTheme.surface),
        body: EmptyState(
          icon: Icons.error_outline,
          title: 'Listing Not Found',
          subtitle: 'The listing data is missing or corrupted.',
          buttonText: 'Go Back',
          onButtonPressed: () => Navigator.pop(context),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Edit Listing'),
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
                  // ── Status Banner ──
                  _statusBanner(),
                  const SizedBox(height: 24),

                  // ── Photos Section ──
                  _sectionHeader('Photos  ${_existingImages.length + _newImages.length}/8'),
                  const SizedBox(height: 12),
                  _imageGallery(),
                  const SizedBox(height: 24),

                  // ── Listing Details ──
                  _sectionHeader('Listing Details'),
                  const SizedBox(height: 12),
                  _titleField(),
                  const SizedBox(height: 16),
                  _descriptionField(),
                  const SizedBox(height: 16),
                  _priceRow(),
                  const SizedBox(height: 24),

                  // ── Category & Location ──
                  _sectionHeader('Category & Location'),
                  const SizedBox(height: 12),
                  _categoryDropdown(provider),
                  const SizedBox(height: 16),
                  _cityField(),
                  const SizedBox(height: 24),

                  // ── Item Details ──
                  _sectionHeader('Item Details'),
                  const SizedBox(height: 12),
                  _conditionDropdown(),
                  const SizedBox(height: 32),

                  // ── Submit Button ──
                  _updateButton(provider),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Widgets ──

  Widget _statusBanner() {
    final Color bannerColor;
    final IconData bannerIcon;
    switch (_status.toLowerCase()) {
      case 'approved':
        bannerColor = AppTheme.success;
        bannerIcon = Icons.check_circle_outline;
        break;
      case 'pending_review':
      case 'pending':
        bannerColor = AppTheme.accent;
        bannerIcon = Icons.hourglass_top;
        break;
      case 'rejected':
        bannerColor = AppTheme.error;
        bannerIcon = Icons.cancel_outlined;
        break;
      case 'sold':
        bannerColor = AppTheme.primaryDark;
        bannerIcon = Icons.sell_outlined;
        break;
      case 'archived':
        bannerColor = AppTheme.textSecondary;
        bannerIcon = Icons.archive_outlined;
        break;
      default:
        bannerColor = AppTheme.textSecondary;
        bannerIcon = Icons.edit_note;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bannerColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bannerColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(bannerIcon, color: bannerColor, size: 20),
          const SizedBox(width: 10),
          Text(
            'Status: ${_status.replaceAll('_', ' ').toUpperCase()}',
            style: TextStyle(
              color: bannerColor,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: 0.3,
            ),
          ),
        ],
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

  Widget _imageGallery() {
    final totalImages = _existingImages.length + _newImages.length;

    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Existing backend images
          ..._existingImages.asMap().entries.map((entry) {
            final img = entry.value;
            final url = img['image_url'] ?? img['url'] ?? '';
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: url.toString().isNotEmpty
                        ? Image.network(
                            url,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholderThumb(),
                          )
                        : _placeholderThumb(),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => setState(() => _existingImages.removeAt(entry.key)),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.error,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Newly picked local images
          ..._newImages.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(entry.value.path),
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => setState(() => _newImages.removeAt(entry.key)),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.error,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Add Photo button
          if (totalImages < 8)
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
      ),
    );
  }

  Widget _placeholderThumb() {
    return Container(
      width: 100,
      height: 100,
      color: AppTheme.background,
      child: const Icon(Icons.image, color: AppTheme.textSecondary),
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
        return null;
      },
    );
  }

  Widget _descriptionField() {
    return TextFormField(
      controller: _descriptionController,
      maxLines: 5,
      minLines: 3,
      maxLength: 2000,
      decoration: const InputDecoration(
        labelText: 'Description',
        hintText: 'Describe your item in detail',
        alignLabelWithHint: true,
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Description is required';
        if (v.trim().length < 20) return 'Description must be at least 20 characters';
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
    final isRu = context.read<LocaleProvider>().locale.languageCode == 'ru';

    if (provider.categoriesLoading) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
          ),
        ),
      );
    }

    return DropdownButtonFormField<int>(
      value: _selectedCategoryId,
      decoration: const InputDecoration(labelText: 'Category'),
      hint: const Text('Select a category'),
      items: provider.categories.map((cat) {
        final label = isRu && cat.nameRu.isNotEmpty ? cat.nameRu : cat.name;
        return DropdownMenuItem<int>(value: cat.id, child: Text(label));
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

  Widget _updateButton(ListingProvider provider) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: provider.isCreating ? null : _handleUpdate,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          disabledBackgroundColor: AppTheme.primary.withOpacity(0.6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: provider.isCreating
            ? const SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Text(
                'Update Listing',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              ),
      ),
    );
  }
}
