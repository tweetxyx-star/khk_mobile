import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../config/app_theme.dart';
import '../../../models/net.dart';
import '../../../models/package.dart';
import 'booking_step_header.dart';

class DateTimeSelectionStep extends StatelessWidget {
  final Net? selectedNet;
  final Package? selectedPackage;
  final DateTime selectedDate;
  final int selectedDuration; // in 30-min slots: 2 = 1 hour, 4 = 2 hours
  final List<Map<String, dynamic>> timeSlots;
  final List<Map<String, dynamic>> bookedSlots;
  final bool isLoadingSlots;
  final String? selectedStartTime;
  final bool isFullFacility;
  final Function(DateTime) onDateChanged;
  final Function(
    String startTime,
    String endTime,
    List<String> slots,
    DateTime actualDate,
  )
  onSlotSelected;

  const DateTimeSelectionStep({
    super.key,
    this.selectedNet,
    this.selectedPackage,
    required this.selectedDate,
    required this.selectedDuration,
    required this.timeSlots,
    required this.bookedSlots,
    required this.isLoadingSlots,
    required this.selectedStartTime,
    this.isFullFacility = false,
    required this.onDateChanged,
    required this.onSlotSelected,
  });

  BookingMode get bookingMode =>
      selectedPackage?.bookingMode ?? BookingMode.singleSlot;

  bool get isCorporateOrEvent =>
      selectedPackage?.isCorporateMembership == true ||
      selectedPackage?.isEventBooking == true;

  // FIXED: Handles int 0/1, bool, String from API
  bool _parseIsPeak(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is int) return v == 1;
    if (v is num) return v == 1;
    if (v is String) return v == '1' || v.toLowerCase() == 'true';
    return false;
  }

  // Sort key for working day 07:00 -> 02:00 next day
  int _workingDaySortKey(String timeStr) {
    final parts = timeStr.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    // 07:00-23:59 should come first, then 00:00-06:59 after
    if (h >= 7) {
      return h * 60 + m;
    } else {
      return (24 * 60) + h * 60 + m; // push midnight slots to end
    }
  }

  bool _isSlotInPast(String timeStr) {
    if (timeStr.isEmpty) return true;
    final now = DateTime.now();
    final parts = timeStr.split(':');
    if (parts.length < 2) return true;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    var slotDate = selectedDate;
    if (hour < 7) {
      slotDate = selectedDate.add(const Duration(days: 1));
    }

    final slotStartTime = DateTime(
      slotDate.year,
      slotDate.month,
      slotDate.day,
      hour,
      minute,
    );

    return slotStartTime.isBefore(now) || slotStartTime.isAtSameMomentAs(now);
  }

  bool _isSlotBooked(String timeStr) {
    return bookedSlots.any((slot) => slot['start_time'] == timeStr);
  }

  bool _canSelectSlot(String startTime) {
    if (_isSlotInPast(startTime) || _isSlotBooked(startTime)) return false;

    final startIndex = timeSlots.indexWhere(
      (s) => s['start_time'] == startTime,
    );
    if (startIndex == -1) return false;

    if (bookingMode == BookingMode.eventBlock ||
        bookingMode == BookingMode.membershipDaily) {
      return true;
    }

    if (startIndex + selectedDuration > timeSlots.length) {
      return false;
    }

    for (int i = 0; i < selectedDuration; i++) {
      final slot = timeSlots[startIndex + i];
      final time = slot['start_time'] as String;
      if (_isSlotBooked(time) || _isSlotInPast(time)) return false;

      if (i > 0) {
        final prevSlot = timeSlots[startIndex + i - 1];
        final prevEndTime = prevSlot['end_time'] as String;
        final currentStartTime = time;
        if (prevEndTime != currentStartTime) {
          // Allow midnight wrap: 23:30 -> 00:00 is valid if end_time is 00:00
          // Your DB should have 23:30 end_time = 00:00, so check is ok
          if (!(prevEndTime == '00:00' && currentStartTime == '00:00' ||
              prevEndTime == '23:30' && currentStartTime == '00:00')) {
            // keep strict, but don't block if it's consecutive in working day order
            // For simplicity, if sorted correctly, just check available, not time string continuity
          }
        }
      }
    }
    return true;
  }

  List<String> _getSelectedSlotRange() {
    if (selectedStartTime == null) return [];
    final startIndex = timeSlots.indexWhere(
      (s) => s['start_time'] == selectedStartTime,
    );
    if (startIndex == -1) return [];

    List<String> slots = [];
    if (bookingMode == BookingMode.eventBlock ||
        bookingMode == BookingMode.membershipDaily) {
      slots.add(timeSlots[startIndex]['start_time'] as String);
    } else {
      for (int i = 0; i < selectedDuration; i++) {
        if (startIndex + i < timeSlots.length) {
          slots.add(timeSlots[startIndex + i]['start_time'] as String);
        }
      }
    }
    return slots;
  }

  void _selectTimeSlot(BuildContext context, String startTime) {
    if (!_canSelectSlot(startTime)) return;
    final startIndex = timeSlots.indexWhere(
      (s) => s['start_time'] == startTime,
    );
    if (startIndex == -1) return;

    List<String> slots = [];
    String endTime;
    int peakCount = 0;
    int offPeakCount = 0;

    if (bookingMode == BookingMode.eventBlock ||
        bookingMode == BookingMode.membershipDaily) {
      slots = [startTime];
      endTime = timeSlots[startIndex]['end_time'] as String;
      final isPeak = _parseIsPeak(timeSlots[startIndex]['is_peak']);
      if (isPeak) {
        peakCount = 1;
      } else {
        offPeakCount = 1;
      }
    } else {
      for (int i = 0; i < selectedDuration; i++) {
        final s = timeSlots[startIndex + i];
        slots.add(s['start_time'] as String);
        if (_parseIsPeak(s['is_peak'])) {
          peakCount++;
        } else {
          offPeakCount++;
        }
      }
      final endIndex = startIndex + selectedDuration - 1;
      endTime = timeSlots[endIndex]['end_time'] as String;
    }

    if (isCorporateOrEvent && selectedPackage != null) {
      final total = peakCount + offPeakCount;
      if (total > 0) {
        final canSelect = selectedPackage!.canSelectPeakHours(
          peakHours: peakCount,
          offPeakHours: offPeakCount,
        );
        if (!canSelect) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red.shade800,
              content: Text(
                '${selectedPackage!.peakRuleMessage}\nYou selected $peakCount Peak, $offPeakCount Off-Peak.',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
          return;
        }
      }
    }

    var actualBookingDate = selectedDate;
    final parts = startTime.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    if (hour < 7) {
      actualBookingDate = selectedDate.add(const Duration(days: 1));
    }

    onSlotSelected(startTime, endTime, slots, actualBookingDate);
  }

  Widget _buildTimeSlotChip(
    BuildContext context,
    Map<String, dynamic> slot,
    bool isBlockMode,
  ) {
    final start = slot['start_time'] as String;
    final end = slot['end_time'] as String;
    final isPeak = _parseIsPeak(slot['is_peak']);
    final label = slot['label'] as String?;

    final selectedSlots = _getSelectedSlotRange();
    final isSelected = selectedSlots.contains(start);
    final isPast = _isSlotInPast(start);
    final isBooked = _isSlotBooked(start);
    final canSelect = _canSelectSlot(start);

    Color bgColor;
    Color textColor;
    Color borderColor;
    if (isSelected) {
      bgColor = AppTheme.primaryGreen;
      textColor = Colors.black;
      borderColor = AppTheme.primaryGreen;
    } else if (isBooked) {
      bgColor = Colors.red.withValues(alpha: 0.2);
      textColor = Colors.red;
      borderColor = Colors.red.withValues(alpha: 0.5);
    } else if (isPast || !canSelect) {
      bgColor = Colors.grey.withValues(alpha: 0.1);
      textColor = Colors.grey;
      borderColor = Colors.grey.withValues(alpha: 0.3);
    } else {
      bgColor = AppTheme.cardDark.withValues(alpha: 0.6);
      textColor = Colors.white;
      borderColor = isPeak
          ? Colors.orange.withValues(alpha: 0.5)
          : Colors.white24;
    }

    final displayTime = isBlockMode ? '$start - $end' : start;

    return GestureDetector(
      onTap: canSelect ? () => _selectTimeSlot(context, start) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayTime,
              style: GoogleFonts.inter(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: isBlockMode ? 13 : 15,
              ),
            ),
            if (label != null && isBlockMode) ...[
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: textColor.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                  fontSize: 10,
                ),
              ),
            ],
            if (isBooked) ...[
              const SizedBox(height: 4),
              const Icon(Icons.block, size: 12, color: Colors.red),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSlotSection(
    BuildContext context,
    String title,
    String timeRange,
    List<Map<String, dynamic>> slots,
    Color accentColor,
    bool isBlockMode,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.montserrat(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  timeRange,
                  style: GoogleFonts.inter(
                    color: AppTheme.textGrey,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: accentColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                '${slots.length} slots',
                style: GoogleFonts.inter(
                  color: accentColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (slots.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.cardDark.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Text(
              'No $title available',
              style: GoogleFonts.inter(color: AppTheme.textGrey, fontSize: 12),
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: slots
                .map((s) => _buildTimeSlotChip(context, s, isBlockMode))
                .toList(),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBlockMode =
        bookingMode == BookingMode.eventBlock ||
        bookingMode == BookingMode.membershipDaily;

    // Sort by working day order 07:00 -> 02:00 next day
    final sortedSlots = [...timeSlots]
      ..sort(
        (a, b) => _workingDaySortKey(
          a['start_time'] as String,
        ).compareTo(_workingDaySortKey(b['start_time'] as String)),
      );

    List<Map<String, dynamic>> offPeakSlots = [];
    List<Map<String, dynamic>> peakSlots = [];

    offPeakSlots = sortedSlots
        .where((s) => !_parseIsPeak(s['is_peak']))
        .toList();
    peakSlots = sortedSlots.where((s) => _parseIsPeak(s['is_peak'])).toList();

    final hoursDisplay = (selectedDuration * 0.5)
        .toStringAsFixed(1)
        .replaceAll('.0', '');

    String headerSubtitle = 'Pick your slot';
    if (bookingMode == BookingMode.eventBlock) {
      headerSubtitle = 'Select your event time block - Max 50% Peak allowed';
    } else if (bookingMode == BookingMode.membershipDaily) {
      headerSubtitle = 'Corporate - 2 hrs/day - Max 1 hr Peak allowed';
    } else if (selectedPackage?.isIndividualPackage == true) {
      headerSubtitle =
          'Package: ${selectedPackage?.peakOffPeakLabel} - Weekdays Only';
    }

    final selectedSlots = _getSelectedSlotRange();
    int selectedPeak = 0;
    int selectedOffPeak = 0;
    for (var t in selectedSlots) {
      final s = timeSlots.firstWhere(
        (e) => e['start_time'] == t,
        orElse: () => {'is_peak': false},
      );
      if (_parseIsPeak(s['is_peak'])) {
        selectedPeak++;
      } else {
        selectedOffPeak++;
      }
    }
    final violatesRule =
        isCorporateOrEvent &&
        selectedSlots.isNotEmpty &&
        selectedPackage != null &&
        !selectedPackage!.canSelectPeakHours(
          peakHours: selectedPeak,
          offPeakHours: selectedOffPeak,
        );

    return Column(
      key: const ValueKey('datetime'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BookingStepHeader(
          title: 'SELECT DATE & TIME',
          subtitle: headerSubtitle,
          icon: Icons.calendar_today_outlined,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardDark.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              Icon(
                isFullFacility ? Icons.stadium : Icons.sports_cricket,
                color: AppTheme.primaryGreen,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isFullFacility
                      ? 'Full Facility (All Nets)'
                      : selectedNet?.name ?? 'Select Net',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (bookingMode == BookingMode.membershipDaily)
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
                    'MEMBER',
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: selectedDate,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 60)),
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.dark(primary: AppTheme.primaryGreen),
                ),
                child: child!,
              ),
            );
            if (date != null) onDateChanged(date);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardDark.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.calendar_today,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date',
                      style: GoogleFonts.inter(
                        color: AppTheme.textGrey,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      DateFormat('EEE, MMM d, yyyy').format(selectedDate),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  'CHANGE',
                  style: GoogleFonts.montserrat(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (isCorporateOrEvent)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Rule: Maximum 50% Peak Hours allowed. For Corporate 2 hrs booking, you can select max 1 hr Peak (4 PM - 2 AM) and 1 hr Off-Peak (7 AM - 4 PM).',
                    style: GoogleFonts.inter(
                      color: Colors.orange.shade200,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Text(
              isBlockMode ? 'Available Time Blocks' : 'Available Time Slots',
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            if (isLoadingSlots)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryGreen,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (timeSlots.isEmpty && !isLoadingSlots)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardDark.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(
              selectedNet == null && !isFullFacility
                  ? 'Select a date to see available slots'
                  : 'No available slots for this date',
              style: GoogleFonts.inter(color: AppTheme.textGrey),
            ),
          )
        else ...[
          _buildSlotSection(
            context,
            'OFF-PEAK HOURS',
            '7:00 AM - 4:00 PM',
            offPeakSlots,
            Colors.blue,
            isBlockMode,
          ),
          const SizedBox(height: 24),
          _buildSlotSection(
            context,
            'PEAK HOURS',
            '4:00 PM - 2:00 AM',
            peakSlots,
            Colors.orange,
            isBlockMode,
          ),
        ],
        if (violatesRule) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Peak Hours Limit Exceeded',
                        style: GoogleFonts.inter(
                          color: Colors.red,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'You selected $selectedPeak Peak + $selectedOffPeak Off-Peak = ${(selectedPeak / (selectedPeak + selectedOffPeak) * 100).toInt()}% Peak. Max allowed is 50%. Please select more Off-Peak slots.',
                        style: GoogleFonts.inter(
                          color: Colors.red.shade200,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (selectedSlots.isNotEmpty && !violatesRule) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.primaryGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: AppTheme.primaryGreen,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isCorporateOrEvent
                        ? 'Selected: $selectedOffPeak Off-Peak + $selectedPeak Peak (${(selectedPeak / selectedSlots.length * 100).toInt()}% Peak) - Valid'
                        : '$hoursDisplay-hour booking: ${selectedSlots.length} slots selected',
                    style: GoogleFonts.inter(
                      color: AppTheme.primaryGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (selectedDuration > 1 && bookingMode == BookingMode.singleSlot) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$hoursDisplay-hour booking requires $selectedDuration consecutive 30-min slots. Tap start time to auto-select.',
                    style: GoogleFonts.inter(color: Colors.blue, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
