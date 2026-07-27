import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_theme.dart';

class PackageCard extends StatelessWidget {
  final Map<String, dynamic> pkg;

  const PackageCard({super.key, required this.pkg});

  IconData getIcon() {
    final name = (pkg['name'] ?? '').toLowerCase();
    if (name.contains('team') || name.contains('match')) {
      return Icons.people;
    }
    if (name.contains('tournament')) {
      return Icons.emoji_events;
    }
    return Icons.timer;
  }

  @override
  Widget build(BuildContext context) {
    // DEBUG: Print the price value coming from API
    debugPrint(
      '💰 [PackageCard] base_price: ${pkg['base_price']} | Type: ${pkg['base_price'].runtimeType} | Full pkg: $pkg',
    );

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        border: Border.all(color: const Color(0xFF2A2A2A)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Image section
          Container(
            height: 160,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              image: DecorationImage(
                image: NetworkImage(
                  pkg['image_url'] ??
                      'https://images.unsplash.com/photo-1531415074968-036ba1b575da?q=80&w=800',
                ),
                fit: BoxFit.cover,
              ),
            ),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.9),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(getIcon(), color: Colors.white, size: 16),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: Text(
                    pkg['name'] ?? 'Package',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      shadows: const [
                        Shadow(blurRadius: 8, color: Colors.black),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Info section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.timer, size: 16, color: AppTheme.textGrey),
                    const SizedBox(width: 6),
                    Text(
                      pkg['duration_hours'] == 24
                          ? 'FULL DAY'
                          : '${pkg['duration_hours']} HRS',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppTheme.textGrey,
                      ),
                    ),
                  ],
                ),
                Text(
                  'BHD ${pkg['base_price']}',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
