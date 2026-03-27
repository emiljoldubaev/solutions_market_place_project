import 'package:flutter/material.dart';
import '../config/theme.dart';

class DynamicAttributes extends StatelessWidget {
  final Map<String, dynamic>? attributes;

  const DynamicAttributes({Key? key, this.attributes}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (attributes == null || attributes!.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Details', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: attributes!.entries.map((entry) {
              final isLast = entry.key == attributes!.entries.last.key;
              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatKey(entry.key),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                      ),
                      Text(
                        entry.value.toString(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  if (!isLast) const Divider(height: 24),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  String _formatKey(String key) {
    if (key.isEmpty) return key;
    return key.split('_').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1).toLowerCase() : '').join(' ');
  }
}
