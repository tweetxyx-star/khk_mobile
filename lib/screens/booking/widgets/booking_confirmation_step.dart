import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../config/app_theme.dart';
import '../../../models/net.dart';
import '../../../models/facility.dart';
import '../../../models/coach.dart';
import '../../../models/package.dart';
import 'booking_step_header.dart';

class BookingConfirmationStep extends StatelessWidget {
  final Net? net;
  final Package package;
  final DateTime selectedDate;
  final String? selectedStartTime;
  final String? selectedEndTime;
  final int selectedDuration; // in 30-min slots: 2 = 1hr, 8 = 4hrs
  final List<Facility> selectedFacilities;
  final Coach? selectedCoach;
  final double totalPrice;
  final bool isFullFacility;

  const BookingConfirmationStep({
    super.key,
    this.net,
    required this.package,
    required this.selectedDate,
    this.selectedStartTime,
    this.selectedEndTime,
    required this.selectedDuration,
    required this.selectedFacilities,
    this.selectedCoach,
    required this.totalPrice,
    this.isFullFacility = false,
  });

  bool get _isPeakSlot {
    if (selectedStartTime == null) return false;
    final h = int.tryParse(selectedStartTime!.split(':')[0]) ?? 0;
    // Your working day rule: 07:00-15:59 Off-Peak, 16:00-02:00 Peak (00:00-06:59 is Peak)
    if (h >= 7 && h < 16) return false;
    return true;
  }

  String get _peakLabel {
    if (_isPeakSlot) return 'Peak Hours (04:00 PM - 02:00 AM)';
    return 'Off-Peak Hours (07:00 AM - 03:59 PM)';
  }

  double get _correctedBasePrice {
    final hours = selectedDuration * 0.5;
    // Use new helper from fixed package.dart - this reads DB correctly: 25 Off / 45 Peak
    if (package.pricingType == 'hourly_peak_offpeak') {
      return package.getPriceForSlot(
        startTime: selectedStartTime ?? '10:00',
        hours: hours,
      );
    }
    // For flat_rate/event, keep totalPrice from backend
    return totalPrice;
  }

  double get _facilitiesPrice {
    final hours = selectedDuration * 0.5;
    double total = 0;
    for (final f in selectedFacilities) {
      final isAutoIncluded =
          package.hasBowlingMachine && f.name.toLowerCase().contains('bowling');
      if (isAutoIncluded) continue;
      total += f.price * hours;
    }
    return total;
  }

  double get _coachPrice {
    final hours = selectedDuration * 0.5;
    if (selectedCoach == null) return 0;
    return (selectedCoach!.hourlyRate ?? 25.0) * hours;
  }

  double get _finalTotal {
    // If package is hourly, recalculate correctly, else trust totalPrice passed
    if (package.pricingType == 'hourly_peak_offpeak') {
      return _correctedBasePrice + _facilitiesPrice + _coachPrice;
    }
    return totalPrice;
  }

  @override
  Widget build(BuildContext context) {
    final actualHours = (selectedDuration * 0.5);
    final hoursDisplay = actualHours.toStringAsFixed(
      actualHours.truncateToDouble() == actualHours ? 0 : 1,
    );

    final isEvent = package.bookingMode == BookingMode.eventBlock;
    final isCorporate = package.bookingMode == BookingMode.membershipDaily;
    final rate = package.getHourlyRateForSlot(selectedStartTime ?? '10:00');

    return Column(
      key: const ValueKey('confirm'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BookingStepHeader(
          title: 'CONFIRM BOOKING',
          subtitle: isCorporate
              ? 'Daily booking from your membership'
              : isEvent
              ? 'Review your event booking'
              : 'Review your session',
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.cardDark.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            children: [
              _buildConfirmRow('Booking Type', package.name, Icons.category),

              _buildConfirmRow(
                'Net/Facility',
                isFullFacility || package.isFullFacility
                    ? 'Full Facility (All Nets)'
                    : (net?.name ?? 'N/A'),
                Icons.sports_cricket,
              ),

              if (isCorporate)
                _buildConfirmRow(
                  'Daily Slot',
                  '$hoursDisplay hour${actualHours > 1 ? 's' : ''} per day',
                  Icons.timer,
                )
              else
                _buildConfirmRow(
                  'Duration',
                  '$hoursDisplay hour${actualHours > 1 ? 's' : ''}',
                  Icons.timer,
                ),

              _buildConfirmRow(
                'Date',
                DateFormat('EEE, MMM d, yyyy').format(selectedDate),
                Icons.calendar_today,
              ),

              _buildConfirmRow(
                'Time',
                (selectedStartTime != null && selectedEndTime != null)
                    ? '$selectedStartTime - $selectedEndTime'
                    : 'Not selected',
                Icons.access_time,
              ),

              // NEW: Show Peak / Off-Peak breakdown for hourly packages
              if (package.pricingType == 'hourly_peak_offpeak' &&
                  !isCorporate) ...[
                const Divider(color: Colors.white12, height: 24),
                _buildConfirmRow(
                  'Slot Type',
                  _isPeakSlot ? 'PEAK' : 'OFF-PEAK',
                  _isPeakSlot ? Icons.wb_sunny : Icons.nights_stay,
                  valueColor: _isPeakSlot ? Colors.orange : Colors.blue,
                ),
                _buildConfirmRow(
                  'Rate',
                  'BHD ${rate.toStringAsFixed(3)}/hr',
                  Icons.local_offer,
                  valueColor: Colors.white70,
                ),
                _buildConfirmRow(
                  _peakLabel,
                  'BHD ${_correctedBasePrice.toStringAsFixed(3)}',
                  Icons.price_check,
                ),
              ],

              if (isCorporate) ...[
                const Divider(color: Colors.white12, height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.card_membership,
                        size: 20,
                        color: AppTheme.primaryGreen,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Corporate Membership',
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${package.membershipDays} days • ${package.dailyHours}hrs/day • FREE booking',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppTheme.textGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (selectedFacilities.isNotEmpty) ...[
                const Divider(color: Colors.white12, height: 24),
                ...selectedFacilities.map((f) {
                  final isAutoIncluded =
                      package.hasBowlingMachine &&
                      f.name.toLowerCase().contains('bowling');

                  return _buildConfirmRow(
                    f.name,
                    isAutoIncluded
                        ? 'INCLUDED'
                        : 'BHD ${(f.price * actualHours).toStringAsFixed(3)}',
                    Icons.add_circle_outline,
                    valueColor: isAutoIncluded ? AppTheme.primaryGreen : null,
                  );
                }),
              ],

              if (selectedCoach != null) ...[
                const Divider(color: Colors.white12, height: 24),
                _buildConfirmRow('Coach', selectedCoach!.name, Icons.person),
                _buildConfirmRow(
                  'Coach Fee',
                  'BHD ${((selectedCoach!.hourlyRate ?? 25.0) * actualHours).toStringAsFixed(3)}',
                  Icons.attach_money,
                ),
              ],

              const Divider(color: Colors.white12, height: 32),

              _buildConfirmRow(
                'Payment',
                isCorporate
                    ? 'Membership - No charge'
                    : 'Bank Transfer Required',
                Icons.account_balance,
              ),

              if (package.paymentInAdvance && !isCorporate) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber,
                        size: 18,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Payment in Advance Required',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              _buildConfirmRow(
                'TOTAL',
                isCorporate ? 'FREE' : 'BHD ${_finalTotal.toStringAsFixed(3)}',
                Icons.receipt,
                isTotal: true,
                valueColor: isCorporate ? AppTheme.primaryGreen : null,
              ),

              // Debug helper to show old vs new if mismatch
              if (!isCorporate &&
                  package.pricingType == 'hourly_peak_offpeak' &&
                  (totalPrice - _finalTotal).abs() > 0.01) ...[
                const SizedBox(height: 8),
                Text(
                  'Corrected from BHD ${totalPrice.toStringAsFixed(3)} (was showing off-peak)',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.orange.shade200,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryGreen.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.primaryGreen, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isCorporate
                      ? 'This booking uses your corporate membership. Book your daily slots separately. No additional payment required.'
                      : isEvent
                      ? 'Next: Upload your payment receipt to confirm booking. Your event slot will be reserved after admin verifies payment.'
                      : _isPeakSlot
                      ? 'Peak Hours (04:00 PM - 02:00 AM) - BHD ${package.peakBhd?.toStringAsFixed(3)}/hr applied. Upload receipt to confirm.'
                      : 'Off-Peak Hours (07:00 AM - 03:59 PM) - BHD ${package.offPeakBhd?.toStringAsFixed(3)}/hr applied. Upload receipt to confirm.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmRow(
    String label,
    String value,
    IconData icon, {
    bool isTotal = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isTotal ? AppTheme.primaryGreen : AppTheme.textGrey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: AppTheme.textGrey,
                fontSize: isTotal ? 16 : 14,
                fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.montserrat(
                color:
                    valueColor ??
                    (isTotal ? AppTheme.primaryGreen : Colors.white),
                fontWeight: isTotal ? FontWeight.w900 : FontWeight.w600,
                fontSize: isTotal ? 22 : 14,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
