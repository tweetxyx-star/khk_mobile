import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../config/app_theme.dart';
import '../../../services/api_service.dart';
import 'membership_booking_sheet.dart';

class MembershipDetailScreen extends StatefulWidget {
  final Map<String, dynamic> userPackage;
  const MembershipDetailScreen({super.key, required this.userPackage});
  @override
  State<MembershipDetailScreen> createState() => _MembershipDetailScreenState();
}

class _MembershipDetailScreenState extends State<MembershipDetailScreen> {
  List<dynamic> bookings = [];
  bool _loadingBookings = true;

  bool get isCorporate =>
      (widget.userPackage['package_type'] ??
          widget.userPackage['membership_package']?['type']) ==
      'corporate';

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _loadingBookings = true);
    try {
      final res = await ApiService.getMembershipBookings(
        widget.userPackage['id'],
      );
      if (mounted) {
        setState(() {
          bookings = res;
          _loadingBookings = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingBookings = false);
    }
  }

  List<DateTime> get _dateRange {
    try {
      final fromStr = widget.userPackage['valid_from'] as String?;
      final toStr = widget.userPackage['valid_until'] as String?;
      if (fromStr == null || toStr == null) {
        final now = DateTime.now();
        return List.generate(30, (i) => now.add(Duration(days: i)));
      }
      final from = DateTime.parse(fromStr);
      final to = DateTime.parse(toStr);
      final days = to.difference(from).inDays + 1;
      if (days <= 0 || days > 365) {
        return List.generate(30, (i) => from.add(Duration(days: i)));
      }
      return List.generate(days, (i) => from.add(Duration(days: i)));
    } catch (_) {
      final now = DateTime.now();
      return List.generate(30, (i) => now.add(Duration(days: i)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mp =
        widget.userPackage['membership_package'] as Map<String, dynamic>?;
    final pkgName =
        mp?['name'] ?? widget.userPackage['package_type'] ?? 'Membership';

    // Remaining for Individual
    final peakRem = widget.userPackage['peak_hours_remaining'];
    final offRem = widget.userPackage['offpeak_hours_remaining'];
    final int peakRemInt = peakRem is int
        ? peakRem
        : int.tryParse('$peakRem') ?? 0;
    final int offRemInt = offRem is int ? offRem : int.tryParse('$offRem') ?? 0;

    final dailyLimit =
        (mp?['daily_hours_allowed'] ??
        widget.userPackage['daily_hours_allowed'] ??
        2);
    final int dailyLimitInt = dailyLimit is int
        ? dailyLimit
        : int.tryParse('$dailyLimit') ?? 2;
    final maxPeak =
        (mp?['max_peak_per_day'] ??
        widget.userPackage['max_peak_per_day'] ??
        1.0);
    final double maxPeakDouble = double.tryParse('$maxPeak') ?? 1.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          pkgName,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Summary Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isCorporate
                  ? Colors.purple.withValues(alpha: 0.12)
                  : AppTheme.primaryGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCorporate
                    ? Colors.purpleAccent.withValues(alpha: 0.3)
                    : AppTheme.primaryGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isCorporate ? Icons.apartment : Icons.sports_cricket,
                      color: isCorporate
                          ? Colors.purpleAccent
                          : AppTheme.primaryGreen,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isCorporate
                            ? 'CORPORATE - FULL FACILITY (All 5 Nets)'
                            : 'INDIVIDUAL - SINGLE NET ONLY (Net 1-5)',
                        style: GoogleFonts.montserrat(
                          color: isCorporate
                              ? Colors.purpleAccent
                              : AppTheme.primaryGreen,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (isCorporate)
                  Text(
                    '• Daily Limit: $dailyLimitInt hrs/day\n• Max Peak: $maxPeakDouble hr/day (only 1 Peak slot)\n• Max 2 Off-Peak slots/day\n• 2-hr Peak NOT allowed\n• Full Facility = blocks all nets at that time\n• Cannot cross 16:00 boundary',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  )
                else
                  Text(
                    '• Peak: ${mp?['peak_hours_included'] ?? peakRemInt} hrs total | Remaining: $peakRemInt hr\n• Off-Peak: ${mp?['offpeak_hours_included'] ?? offRemInt} hrs total | Remaining: $offRemInt hr\n• Weekdays Only (Sun-Thu) ${mp?['weekdays_only'] == 1 ? '(Enforced)' : ''}\n• Single Net booking only (choose Net 1-5)\n• Cannot cross 16:00 boundary',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 12, color: Colors.white38),
                    const SizedBox(width: 6),
                    Text(
                      'Valid: ${widget.userPackage['valid_from'] ?? ''} → ${widget.userPackage['valid_until'] ?? ''}',
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (_loadingBookings)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: AppTheme.primaryGreen),
              ),
            )
          else if (isCorporate)
            ..._buildCorporateTable(dailyLimitInt, maxPeakDouble)
          else
            ..._buildIndividualTable(peakRemInt, offRemInt),
        ],
      ),
    );
  }

  List<Widget> _buildCorporateTable(int dailyLimit, double maxPeak) {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _dateRange
        .where(
          (d) => !d.isBefore(DateTime.now().subtract(const Duration(days: 1))),
        )
        .take(14)
        .map((date) {
          final dateStr = DateFormat('yyyy-MM-dd').format(date);
          final isToday = dateStr == todayStr;
          final dayBookings = bookings
              .where((b) => b['booking_date'] == dateStr)
              .toList();
          final totalUsed = dayBookings.fold<double>(
            0.0,
            (a, b) => a + ((b['hours_used'] as num?)?.toDouble() ?? 1.0),
          );
          final peakUsed = dayBookings
              .where((b) => b['is_peak'] == 1 || b['is_peak'] == true)
              .fold<double>(
                0.0,
                (a, b) => a + ((b['hours_used'] as num?)?.toDouble() ?? 0),
              );
          final bool isWeekend =
              date.weekday == DateTime.friday ||
              date.weekday == DateTime.saturday;

          return Card(
            color: isToday ? const Color(0xFF1E2A1E) : AppTheme.cardDark,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: isToday
                    ? AppTheme.primaryGreen.withValues(alpha: 0.5)
                    : Colors.white10,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              title: Row(
                children: [
                  Text(
                    DateFormat('EEE, MMM d').format(date),
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  if (isToday)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'TODAY',
                        style: GoogleFonts.montserrat(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  if (isWeekend)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'FRI/SAT',
                        style: GoogleFonts.inter(
                          fontSize: 8,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  if (dayBookings.isEmpty)
                    Text(
                      'Free - $dailyLimit hrs available (Full Facility)',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white54,
                      ),
                    )
                  else
                    ...dayBookings.map<Widget>((b) {
                      final netLabel = b['net_id'] == null
                          ? 'FULL FACILITY'
                          : 'Net ${b['net_id']}';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          children: [
                            Container(
                              width: 3,
                              height: 12,
                              decoration: BoxDecoration(
                                color:
                                    (b['is_peak'] == 1 || b['is_peak'] == true)
                                    ? Colors.orange
                                    : Colors.lightBlue,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${(b['start_time'] ?? '').toString().substring(0, 5)}-${(b['end_time'] ?? '').toString().substring(0, 5)}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (b['is_peak'] == 1 || b['is_peak'] == true)
                                    ? Colors.orange.withValues(alpha: 0.2)
                                    : Colors.blue.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                (b['is_peak'] == 1 || b['is_peak'] == true)
                                    ? 'PEAK'
                                    : 'OFF-PEAK',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      (b['is_peak'] == 1 ||
                                          b['is_peak'] == true)
                                      ? Colors.orange
                                      : Colors.lightBlue,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              netLabel,
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                color: Colors.purpleAccent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  if (dayBookings.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Used: ${totalUsed}h / $dailyLimit h | Peak: ${peakUsed}h / $maxPeak h',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                ],
              ),
              trailing: totalUsed >= dailyLimit
                  ? const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 22,
                    )
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isToday
                            ? AppTheme.primaryGreen
                            : Colors.white12,
                        minimumSize: const Size(62, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: isWeekend ? null : () => _openBooking(date),
                      child: Text(
                        'BOOK',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isToday ? Colors.black : Colors.white,
                        ),
                      ),
                    ),
            ),
          );
        })
        .toList();
  }

  List<Widget> _buildIndividualTable(int peakRem, int offRem) {
    return [
      // Balance header
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: _balanceItem(
                'PEAK REMAINING',
                '$peakRem hr',
                Colors.orange,
                Icons.wb_sunny,
              ),
            ),
            Container(width: 1, height: 36, color: Colors.white12),
            Expanded(
              child: _balanceItem(
                'OFF-PEAK REMAINING',
                '$offRem hr',
                Colors.lightBlue,
                Icons.nights_stay,
              ),
            ),
            Container(width: 1, height: 36, color: Colors.white12),
            Expanded(
              child: _balanceItem(
                'TOTAL BOOKINGS',
                '${bookings.length}',
                AppTheme.primaryGreen,
                Icons.receipt_long,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      if (bookings.isEmpty)
        Padding(
          padding: const EdgeInsets.all(28),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.event_busy, size: 40, color: Colors.white24),
                const SizedBox(height: 10),
                Text(
                  'No bookings yet',
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap BOOK NEW SLOT to use your $peakRem Peak + $offRem Off-Peak hours',
                  style: GoogleFonts.inter(color: Colors.white30, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        )
      else
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF151515),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                Colors.white.withValues(alpha: 0.04),
              ),
              dataRowMinHeight: 44,
              dataRowMaxHeight: 50,
              columns: [
                DataColumn(label: Text('DATE', style: _headerStyle())),
                DataColumn(label: Text('TIME', style: _headerStyle())),
                DataColumn(label: Text('NET', style: _headerStyle())),
                DataColumn(label: Text('TYPE', style: _headerStyle())),
                DataColumn(label: Text('STATUS', style: _headerStyle())),
              ],
              rows: bookings.map<DataRow>((b) {
                final isPeak = b['is_peak'] == 1 || b['is_peak'] == true;
                final netId = b['net_id'];
                final netLabel = netId == null ? 'FULL' : 'Net $netId';
                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        (b['booking_date'] ?? '').toString().substring(0, 10),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${(b['start_time'] ?? '').toString().substring(0, 5)}-${(b['end_time'] ?? '').toString().substring(0, 5)}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          netLabel,
                          style: TextStyle(
                            color: AppTheme.primaryGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isPeak
                              ? Colors.orange.withValues(alpha: 0.18)
                              : Colors.blue.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isPeak ? 'PEAK' : 'OFF-PEAK',
                          style: TextStyle(
                            color: isPeak ? Colors.orange : Colors.lightBlue,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          (b['status'] ?? 'confirmed').toString().toUpperCase(),
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      const SizedBox(height: 18),
      ElevatedButton.icon(
        onPressed: () => _openBooking(DateTime.now()),
        icon: const Icon(Icons.add, color: Colors.black, size: 18),
        label: Text(
          'BOOK NEW SLOT (Select Net 1-5)',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w800,
            color: Colors.black,
            fontSize: 13,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryGreen,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Individual = One Net per booking | Corporate = Full Facility (all 5 nets blocked)',
        style: GoogleFonts.inter(color: Colors.white24, fontSize: 10),
        textAlign: TextAlign.center,
      ),
    ];
  }

  Widget _balanceItem(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white38,
            fontSize: 8,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  TextStyle _headerStyle() => GoogleFonts.montserrat(
    fontSize: 10,
    color: Colors.white38,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );

  void _openBooking(DateTime date) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MembershipBookingSheet(
        userPackage: widget.userPackage,
        selectedDate: date,
      ),
    );
    if (result == true) _loadBookings();
  }
}
