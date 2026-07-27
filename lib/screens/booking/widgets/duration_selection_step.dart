import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/app_theme.dart';
import 'booking_step_header.dart';

class DurationSelectionStep extends StatelessWidget {
  final int selectedDuration;
  final Function(int) onSelect;

  const DurationSelectionStep({
    super.key,
    required this.selectedDuration,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('duration'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BookingStepHeader(
          title: 'SELECT DURATION',
          subtitle: 'How long is your session?',
        ),
        const SizedBox(height: 16),
        _buildDurationCard(1, '1 Hour', 'BHD 5.000'),
        const SizedBox(height: 12),
        _buildDurationCard(2, '2 Hours', 'BHD 10.000'),
        const SizedBox(height: 12),
        _buildDurationCard(3, '3 Hours', 'BHD 15.000'),
        const SizedBox(height: 12),
        _buildDurationCard(4, '4 Hours', 'BHD 20.000'),
        const SizedBox(height: 12),
        _buildDurationCard(5, '5 Hours', 'BHD 25.000'),
      ],
    );
  }

  Widget _buildDurationCard(int hours, String title, String price) {
    final isSelected = selectedDuration == hours;
    return GestureDetector(
      onTap: () => onSelect(hours),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryGreen.withValues(alpha: 0.15)
              : AppTheme.cardDark.withValues(alpha: 0.6),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : Colors.white24,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryGreen : Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.access_time,
                color: isSelected ? Colors.black : Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    price,
                    style: GoogleFonts.inter(
                      color: AppTheme.primaryGreen,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: AppTheme.primaryGreen, size: 28),
          ],
        ),
      ),
    );
  }
}
