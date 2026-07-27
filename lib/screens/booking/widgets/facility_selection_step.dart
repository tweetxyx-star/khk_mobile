import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../config/app_theme.dart';
import '../../../models/facility.dart';
import '../../../models/coach.dart';

class FacilitySelectionStep extends StatelessWidget {
  final List<Facility> facilities;
  final List<Coach> coaches;
  final Set<int> selectedFacilityIds;
  final Set<int> autoIncludedFacilityIds; // NEW: Auto-included facilities
  final Coach? selectedCoach;
  final String? selectedStartTime;
  final String? selectedEndTime;
  final DateTime selectedDate;
  final int selectedDuration;
  final Function(int, bool) onFacilityToggle;
  final Function(Coach?) onCoachSelect;
  final Function(String, String, String) onLoadCoaches;

  const FacilitySelectionStep({
    super.key,
    required this.facilities,
    required this.coaches,
    required this.selectedFacilityIds,
    this.autoIncludedFacilityIds = const {}, // NEW
    required this.selectedCoach,
    required this.selectedStartTime,
    required this.selectedEndTime,
    required this.selectedDate,
    required this.selectedDuration,
    required this.onFacilityToggle,
    required this.onCoachSelect,
    required this.onLoadCoaches,
  });

  @override
  Widget build(BuildContext context) {
    final coachingFacility = facilities.firstWhere(
      (f) => f.name.toLowerCase().contains('coach'),
      orElse: () => Facility(id: 0, name: '', icon: '', price: 0),
    );
    final isCoachingSelected = selectedFacilityIds.contains(
      coachingFacility.id,
    );

    return Column(
      key: const ValueKey('facilities'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader('ADD-ONS', 'Enhance your session'),
        const SizedBox(height: 16),
        ...facilities.map((facility) {
          final isSelected = selectedFacilityIds.contains(facility.id);
          final isAutoIncluded = autoIncludedFacilityIds.contains(
            facility.id,
          ); // NEW

          return GestureDetector(
            onTap: isAutoIncluded
                ? null
                : () {
                    // Disable tap if auto-included
                    onFacilityToggle(facility.id, !isSelected);
                    if (facility.name.toLowerCase().contains('coach') &&
                        !isSelected) {
                      if (selectedStartTime != null &&
                          selectedEndTime != null) {
                        final dateStr = DateFormat(
                          'yyyy-MM-dd',
                        ).format(selectedDate);
                        onLoadCoaches(
                          dateStr,
                          selectedStartTime!,
                          selectedEndTime!,
                        );
                      }
                    }
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryGreen.withValues(alpha: 0.15)
                    : isAutoIncluded
                    ? AppTheme.primaryGreen.withValues(alpha: 0.08)
                    : AppTheme.cardDark.withValues(alpha: 0.6),
                border: Border.all(
                  color: isSelected || isAutoIncluded
                      ? AppTheme.primaryGreen
                      : Colors.white24,
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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected || isAutoIncluded
                          ? AppTheme.primaryGreen
                          : Colors.white10,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      facility.name.toLowerCase().contains('coach')
                          ? Icons.sports
                          : Icons.sports_baseball,
                      color: isSelected || isAutoIncluded
                          ? Colors.black
                          : Colors.white54,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                facility.name,
                                style: GoogleFonts.montserrat(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (isAutoIncluded) // NEW: Show "INCLUDED" badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGreen,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'INCLUDED',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isAutoIncluded
                              ? 'Included in your package'
                              : 'BHD ${facility.price.toStringAsFixed(3)}/hr',
                          style: GoogleFonts.inter(
                            color: isAutoIncluded
                                ? Colors.white70
                                : AppTheme.primaryGreen,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected && !isAutoIncluded)
                    Icon(
                      Icons.check_circle,
                      color: AppTheme.primaryGreen,
                      size: 28,
                    )
                  else if (isAutoIncluded)
                    Icon(
                      Icons.check_circle,
                      color: AppTheme.primaryGreen,
                      size: 28,
                    ),
                ],
              ),
            ),
          );
        }),
        if (isCoachingSelected && coaches.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'SELECT COACH',
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          ...coaches.map((coach) => _buildCoachCard(coach)),
        ],
      ],
    );
  }

  Widget _buildCoachCard(Coach coach) {
    final isSelected = selectedCoach?.id == coach.id;
    return GestureDetector(
      onTap: () => onCoachSelect(isSelected ? null : coach),
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
            CircleAvatar(
              radius: 32,
              backgroundImage: NetworkImage(
                coach.imageUrl ?? 'https://via.placeholder.com/150',
              ),
              backgroundColor: Colors.white10,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    coach.name,
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    coach.specialty ?? 'Coach',
                    style: GoogleFonts.inter(
                      color: AppTheme.textGrey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.star, size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        coach.rating.toString(),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'BHD ${(coach.hourlyRate ?? 25.0).toStringAsFixed(3)}/hr',
                        style: GoogleFonts.inter(
                          color: AppTheme.primaryGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
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

  Widget _buildStepHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.inter(color: AppTheme.textGrey, fontSize: 14),
        ),
      ],
    );
  }
}
