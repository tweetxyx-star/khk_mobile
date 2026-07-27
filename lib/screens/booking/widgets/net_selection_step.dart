import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/app_theme.dart';
import '../../../models/net.dart';
import 'booking_step_header.dart';

class NetSelectionStep extends StatelessWidget {
  final List<Net> nets;
  final Net? selectedNet;
  final Function(Net) onSelect;

  const NetSelectionStep({
    super.key,
    required this.nets,
    required this.selectedNet,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('net'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BookingStepHeader(
          title: 'SELECT NET',
          subtitle: 'Choose your preferred net',
        ),
        const SizedBox(height: 16),
        ...nets.map((net) => _buildNetCard(net)),
      ],
    );
  }

  Widget _buildNetCard(Net net) {
    final isSelected = selectedNet?.id == net.id;
    return GestureDetector(
      onTap: () => onSelect(net),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
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
                Icons.sports_cricket,
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
                    net.name,
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: AppTheme.textGrey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        net.location,
                        style: GoogleFonts.inter(
                          color: AppTheme.textGrey,
                          fontSize: 12,
                        ),
                      ),
                    ],
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
