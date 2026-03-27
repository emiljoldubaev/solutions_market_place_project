import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../widgets/app_button.dart';
import '../providers/listing_provider.dart';

class FilterModal extends StatefulWidget {
  final Map<String, dynamic> initialFilters;

  const FilterModal({Key? key, required this.initialFilters}) : super(key: key);

  @override
  State<FilterModal> createState() => _FilterModalState();
}

class _FilterModalState extends State<FilterModal> {
  late Map<String, dynamic> _filters;
  final TextEditingController _minPriceCtrl = TextEditingController();
  final TextEditingController _maxPriceCtrl = TextEditingController();

  final List<String> _conditions = ['New', 'Used - Like New', 'Used - Good', 'Used - Fair'];
  final List<Map<String, String>> _sortOptions = [
    {'label': 'Newest Arrivals', 'value': 'newest'},
    {'label': 'Price: Low to High', 'value': 'price_low'},
    {'label': 'Price: High to Low', 'value': 'price_high'},
    {'label': 'Oldest', 'value': 'oldest'},
  ];

  @override
  void initState() {
    super.initState();
    _filters = Map<String, dynamic>.from(widget.initialFilters);
    if (_filters['min_price'] != null) {
      _minPriceCtrl.text = _filters['min_price'].toString();
    }
    if (_filters['max_price'] != null) {
      _maxPriceCtrl.text = _filters['max_price'].toString();
    }
    
    // Ensure categories are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ListingProvider>().fetchCategories();
    });
  }

  @override
  void dispose() {
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    final double? minP = double.tryParse(_minPriceCtrl.text);
    final double? maxP = double.tryParse(_maxPriceCtrl.text);
    if (minP != null) _filters['min_price'] = minP;
    if (maxP != null) _filters['max_price'] = maxP;
    Navigator.pop(context, _filters);
  }

  void _reset() {
    setState(() {
      _filters = {'sort_by': 'newest'};
      if (widget.initialFilters['search'] != null) {
        _filters['search'] = widget.initialFilters['search'];
      }
      _minPriceCtrl.clear();
      _maxPriceCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle Bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Filters', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              TextButton(
                onPressed: _reset,
                child: const Text('Reset', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Sort By'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _sortOptions.map((opt) {
                      final bool isSelected = _filters['sort_by'] == opt['value'];
                      return ChoiceChip(
                        label: Text(opt['label']!),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) setState(() => _filters['sort_by'] = opt['value']);
                        },
                        selectedColor: AppTheme.primary.withOpacity(0.1),
                        labelStyle: TextStyle(
                          color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                        backgroundColor: AppTheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: isSelected ? AppTheme.primary : AppTheme.border),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  
                  _buildSectionTitle('Category'),
                  Consumer<ListingProvider>(
                    builder: (context, provider, child) {
                      if (provider.categoriesLoading && provider.categories.isEmpty) {
                        return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                      }
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: provider.categories.map((cat) {
                          final bool isSelected = _filters['category_id'] == cat.id;
                          return ChoiceChip(
                            label: Text(cat.name),
                            selected: isSelected,
                            onSelected: (val) {
                              setState(() {
                                if (val) {
                                  _filters['category_id'] = cat.id;
                                } else {
                                  _filters.remove('category_id');
                                }
                              });
                            },
                            selectedColor: AppTheme.primary.withOpacity(0.1),
                            labelStyle: TextStyle(
                              color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                            backgroundColor: AppTheme.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: isSelected ? AppTheme.primary : AppTheme.border),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  _buildSectionTitle('Price Range'),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minPriceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Min Price',
                            prefixIcon: const Icon(Icons.attach_money, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('-', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _maxPriceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Max Price',
                            prefixIcon: const Icon(Icons.attach_money, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Condition'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _conditions.map((cond) {
                      final bool isSelected = _filters['condition'] == cond;
                      return ChoiceChip(
                        label: Text(cond),
                        selected: isSelected,
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              _filters['condition'] = cond;
                            } else {
                              _filters.remove('condition');
                            }
                          });
                        },
                        selectedColor: AppTheme.primary.withOpacity(0.1),
                        labelStyle: TextStyle(
                          color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                        backgroundColor: AppTheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: isSelected ? AppTheme.primary : AppTheme.border),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          AppButton(
            text: 'Show Results',
            onPressed: _apply,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}
