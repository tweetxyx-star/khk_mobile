import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/app_theme.dart';
import '../../../models/package.dart';

class RateCardSelectionStep extends StatelessWidget {
  final List<Package> categories;
  final Package? selectedCard;
  final Function(Package) onSelect;

  const RateCardSelectionStep({
    super.key,
    required this.categories,
    required this.selectedCard,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return Center(
        child: Text(
          'No booking types available',
          style: GoogleFonts.montserrat(color: Colors.white70),
        ),
      );
    }

    // Group packages by category
    final Map<String, List<Package>> grouped = {};
    for (var pkg in categories) {
      grouped.putIfAbsent(pkg.category, () => []).add(pkg);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SELECT BOOKING TYPE',
          style: GoogleFonts.montserrat(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose how you want to book',
          style: GoogleFonts.montserrat(fontSize: 14, color: Colors.white70),
        ),
        const SizedBox(height: 24),
        ...grouped.entries.map(
          (entry) => _buildCategorySection(entry.key, entry.value),
        ),
      ],
    );
  }

  Widget _buildCategorySection(String categoryName, List<Package> cards) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                categoryName.toUpperCase(),
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        ...cards.map((card) => _buildRateCard(card)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildRateCard(Package card) {
    final isSelected = selectedCard?.id == card.id;

    return GestureDetector(
      onTap: () => onSelect(card),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryGreen.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : Colors.white24,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            if (card.imageUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Image.network(
                  card.imageUrl!,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 140,
                    color: Colors.grey.shade900,
                    child: Icon(Icons.image, color: Colors.white24, size: 48),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    card.name,
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Description
                  if (card.description != null)
                    Text(
                      card.description!,
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  const SizedBox(height: 12),

                  // Pricing
                  _buildPricingRow(card),
                  const SizedBox(height: 12),

                  // Includes chips
                  if (card.includes != null && card.includes!.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: card.includes!
                          .map(
                            (item) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppTheme.primaryGreen.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              child: Text(
                                item,
                                style: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),

                  // Advance payment badge - FIXED: paymentInAdvance instead of advancePaymentRequired
                  if (card.paymentInAdvance) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.warning_amber,
                            size: 14,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Payment in Advance',
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingRow(Package card) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _getPricingLabel(card),
          style: GoogleFonts.montserrat(fontSize: 13, color: Colors.white70),
        ),
        Text(
          card.getDisplayPrice(),
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppTheme.primaryGreen,
          ),
        ),
      ],
    );
  }

  String _getPricingLabel(Package card) {
    switch (card.pricingType) {
      case 'hourly_peak_offpeak':
        return 'From';
      case 'flat_rate':
        return '4hr / 8hr';
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      case 'package':
        return 'Total';
      case 'session':
        return 'Per Session';
      default:
        return 'Price';
    }
  }
}
