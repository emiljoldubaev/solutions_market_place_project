import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/city_hubs.dart';
import '../../providers/search_provider.dart';
import '../../main.dart';

class CityExplorerScreen extends StatefulWidget {
  const CityExplorerScreen({Key? key}) : super(key: key);

  @override
  State<CityExplorerScreen> createState() => _CityExplorerScreenState();
}

class _CityExplorerScreenState extends State<CityExplorerScreen>
    with TickerProviderStateMixin {
  CityHub? _selectedCity;
  late AnimationController _pulseController;
  late AnimationController _cardController;
  late Animation<double> _cardSlideAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _cardSlideAnimation = CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  void _selectCity(CityHub city) {
    setState(() => _selectedCity = city);
    _cardController.forward(from: 0);
  }

  void _navigateToSearch(CityHub city) {
    final searchProvider = context.read<SearchProvider>();
    searchProvider.performSearch({
      'city': city.name,
      'sort_by': 'newest',
    }, refresh: true);
    Navigator.pop(context, city.name);
  }

  @override
  Widget build(BuildContext context) {
    final isRu = context.read<LocaleProvider>().locale.languageCode == 'ru';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // ── Deep gradient background ──
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1E3A5F),
                  Color(0xFF0F172A),
                ],
              ),
            ),
          ),

          // ── Subtle grid pattern overlay ──
          CustomPaint(
            painter: _GridPainter(),
            size: Size.infinite,
          ),

          // ── Main content ──
          SafeArea(
            child: Column(
              children: [
                // ── App Bar ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isRu ? 'Хабы Кыргызстана' : 'Explore Kyrgyzstan',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8, height: 8,
                              decoration: const BoxDecoration(
                                color: AppTheme.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${kyrgyzstanHubs.length} ${isRu ? 'городов' : 'cities'}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Subtitle ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    isRu
                        ? 'Выберите город чтобы найти объявления рядом с вами'
                        : 'Tap a city hub to discover listings near you',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // ── City Hub Grid ──
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: kyrgyzstanHubs.length,
                      itemBuilder: (context, index) {
                        final city = kyrgyzstanHubs[index];
                        final isSelected = _selectedCity?.name == city.name;
                        return _buildCityCard(city, isSelected, isRu);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Glassmorphism Bottom Card ──
          if (_selectedCity != null)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: AnimatedBuilder(
                animation: _cardSlideAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, 200 * (1 - _cardSlideAnimation.value)),
                    child: Opacity(
                      opacity: _cardSlideAnimation.value,
                      child: child,
                    ),
                  );
                },
                child: _buildBottomCard(isRu),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCityCard(CityHub city, bool isSelected, bool isRu) {
    return GestureDetector(
      onTap: () => _selectCity(city),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF1A56DB), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : Colors.white.withOpacity(0.08),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  )
                ]
              : null,
        ),
        child: Stack(
          children: [
            // ── Pulse ring (selected only) ──
            if (isSelected)
              Positioned(
                top: 12, right: 12,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    return Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.4 * (1 - _pulseController.value)),
                            blurRadius: 12 * _pulseController.value,
                            spreadRadius: 6 * _pulseController.value,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    city.icon,
                    color: isSelected ? Colors.white : Colors.white.withOpacity(0.4),
                    size: 28,
                  ),
                  const Spacer(),
                  Text(
                    isRu ? city.nameRu : city.name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.85),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    city.region,
                    style: TextStyle(
                      color: isSelected ? Colors.white70 : Colors.white.withOpacity(0.35),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomCard(bool isRu) {
    final city = _selectedCity!;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.15)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Handle bar ──
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  // ── Animated Pulse Icon ──
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, _) {
                      return Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primary.withOpacity(0.2),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.15 * (1 - _pulseController.value)),
                              blurRadius: 16 * _pulseController.value,
                              spreadRadius: 4 * _pulseController.value,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.explore, color: Colors.white, size: 24),
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isRu ? city.nameRu : city.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${city.region} ${isRu ? 'область' : 'region'} • ${city.latitude.toStringAsFixed(2)}°N',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Navigate Button ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => _navigateToSearch(city),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isRu ? 'Смотреть объявления' : 'View Listings',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Subtle tech-grid pattern for the background
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 0.5;

    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
