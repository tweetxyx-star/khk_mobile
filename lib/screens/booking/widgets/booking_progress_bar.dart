import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/app_theme.dart';

class BookingProgressBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const BookingProgressBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final safeCurrent = currentStep.clamp(
      0,
      totalSteps > 0 ? totalSteps - 1 : 0,
    );
    final progress = totalSteps > 0 ? (safeCurrent + 1) / totalSteps : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${safeCurrent + 1} of $totalSteps',
                style: GoogleFonts.inter(
                  color: AppTheme.textGrey,
                  fontSize: 12,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: GoogleFonts.inter(
                  color: AppTheme.primaryGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(totalSteps, (index) {
              final isActive = index <= safeCurrent;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                    right: index == totalSteps - 1 ? 0 : 6,
                  ),
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive ? AppTheme.primaryGreen : Colors.white12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
