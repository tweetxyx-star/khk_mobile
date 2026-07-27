import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/app_theme.dart';
import '../../services/api_service.dart';

class MembershipBookingSheet extends StatefulWidget {
  final Map<String, dynamic> userPackage;
  final DateTime selectedDate;
  const MembershipBookingSheet({
    super.key,
    required this.userPackage,
    required this.selectedDate,
  });

  @override
  State<MembershipBookingSheet> createState() => _MembershipBookingSheetState();
}

class _MembershipBookingSheetState extends State<MembershipBookingSheet> {
  late DateTime _date;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  List<Map<String, dynamic>> _timeSlots = [];
  List<Map<String, dynamic>> _bookedSlots = [];
  Map<String, dynamic>? _selectedSlot;

  double _peakUsed = 0;
  double _totalUsed = 0;
  late int _dailyLimit;
  late double _maxPeakPerDay;
  late bool _isCorporate;

  int _selectedNetId = 1;
  final List<int> _availableNets = [1, 2, 3, 4, 5];

  @override
  void initState() {
    super.initState();
    _date = widget.selectedDate;
    final pkgType = widget.userPackage['package_type'] as String?;
    final memType =
        widget.userPackage['membership_package']?['type'] as String?;
    _isCorporate = (pkgType ?? memType) == 'corporate';

    final daily =
        widget.userPackage['daily_hours_allowed'] ??
        widget.userPackage['membership_package']?['daily_hours_allowed'] ??
        2;
    _dailyLimit = daily is int ? daily : int.tryParse(daily.toString()) ?? 2;

    final maxPeak =
        widget.userPackage['max_peak_per_day'] ??
        widget.userPackage['membership_package']?['max_peak_per_day'] ??
        1.0;
    _maxPeakPerDay = double.tryParse(maxPeak.toString()) ?? 1.0;

    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    setState(() {
      _loading = true;
      _selectedSlot = null;
      _error = null;
    });
    try {
      final data = await ApiService.getMembershipAvailability(
        date: DateFormat('yyyy-MM-dd').format(_date),
        userPackageId: widget.userPackage['id'] as int,
        netId: _isCorporate ? null : _selectedNetId,
      );

      _peakUsed = (data['peak_used'] as num?)?.toDouble() ?? 0;
      _totalUsed = (data['total_used'] as num?)?.toDouble() ?? 0;

      final dynamic rawBookings = data['bookings'];
      final List allBooked = rawBookings is List ? rawBookings : <dynamic>[];

      List<Map<String, dynamic>> slots = [];
      final dynamic rawTimeSlots = data['time_slots'];

      if (rawTimeSlots is List && rawTimeSlots.isNotEmpty) {
        for (var e in rawTimeSlots) {
          if (e is! Map) continue;
          final String startRaw = (e['start_time'] as String);
          final String endRaw = (e['end_time'] as String);
          final String startStr = startRaw.substring(0, 5);
          final String endStr = endRaw.substring(0, 5);
          final bool isPeak = e['is_peak'] == true || e['is_peak'] == 1;
          final bool isBooked = e['is_booked'] == true;

          final bool isToday =
              DateFormat('yyyy-MM-dd').format(_date) ==
              DateFormat('yyyy-MM-dd').format(DateTime.now());

          DateTime slotDateTime;
          try {
            final parts = startStr.split(':');
            slotDateTime = DateTime(
              _date.year,
              _date.month,
              _date.day,
              int.parse(parts[0]),
              int.parse(parts[1]),
            );
          } catch (_) {
            slotDateTime = DateTime.now().add(const Duration(days: 1));
          }
          final bool isPast = isToday && slotDateTime.isBefore(DateTime.now());

          slots.add({
            'start_time': startStr,
            'end_time': endStr,
            'is_peak': isPeak,
            'available': !isBooked && !isPast,
            'is_past': isPast,
            'is_booked': isBooked,
          });
        }
        // Sort by time
        slots.sort(
          (a, b) =>
              (a['start_time'] as String).compareTo(b['start_time'] as String),
        );
      } else {
        DateTime cursor = DateTime(_date.year, _date.month, _date.day, 7, 0);
        final DateTime endDay = DateTime(
          _date.year,
          _date.month,
          _date.day + 1,
          2,
          0,
        );
        while (cursor.isBefore(endDay)) {
          final DateTime next = cursor.add(const Duration(minutes: 30));
          final String startStr = DateFormat('HH:mm').format(cursor);
          final String endStr = DateFormat('HH:mm').format(next);
          final bool isPeak = cursor.hour >= 16 || cursor.hour < 7;
          final bool isToday =
              DateFormat('yyyy-MM-dd').format(_date) ==
              DateFormat('yyyy-MM-dd').format(DateTime.now());
          final bool isPast = isToday && cursor.isBefore(DateTime.now());
          bool isBooked = false;
          for (var b in allBooked) {
            if (b is! Map) continue;
            final String bStart = (b['start_time'] as String).substring(0, 5);
            final String bEnd = (b['end_time'] as String).substring(0, 5);
            if (_overlaps(startStr, endStr, bStart, bEnd)) {
              isBooked = true;
              break;
            }
          }
          slots.add({
            'start_time': startStr,
            'end_time': endStr,
            'is_peak': isPeak,
            'available': !isBooked && !isPast,
            'is_past': isPast,
            'is_booked': isBooked,
          });
          cursor = next;
        }
      }

      if (!mounted) return;
      setState(() {
        _timeSlots = slots;
        _bookedSlots = allBooked.whereType<Map<String, dynamic>>().toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception:', '').trim();
      });
    }
  }

  bool _overlaps(String s1, String e1, String s2, String e2) {
    int toMin(String t) {
      final p = t.split(':');
      return int.parse(p[0]) * 60 + int.parse(p[1]);
    }

    int aS = toMin(s1);
    int aE = toMin(e1);
    int bS = toMin(s2);
    int bE = toMin(e2);
    if (aE <= aS) aE += 1440;
    if (bE <= bS) bE += 1440;
    return aS < bE && bS < aE;
  }

  void _onSelectSlot(Map<String, dynamic> slot) {
    if (slot['is_past'] == true || slot['is_booked'] == true) return;

    final int currentIndex = _timeSlots.indexWhere(
      (s) => s['start_time'] == slot['start_time'],
    );
    if (currentIndex == -1) return;

    // FIXED: Need 1 hour = 2 x 30-min slots
    if (currentIndex + 1 >= _timeSlots.length) {
      setState(
        () => _error =
            'Cannot book last slot alone. Minimum 1 hour required (2 slots).',
      );
      return;
    }

    final nextSlot = _timeSlots[currentIndex + 1];

    if (nextSlot['is_booked'] == true) {
      setState(
        () => _error =
            'Next slot ${nextSlot['start_time']} is already booked (red). Need 1 hour continuous. Choose another time.',
      );
      return;
    }
    if (nextSlot['is_past'] == true) {
      setState(() => _error = 'Next slot is in the past. Cannot book 1 hour.');
      return;
    }
    // Cannot cross 16:00 boundary
    if (slot['is_peak'] != nextSlot['is_peak']) {
      setState(
        () => _error =
            'Cannot cross 16:00 boundary. Book Off-Peak (07:00-16:00) and Peak (16:00-02:00) separately. 16:00 slot starts new period.',
      );
      return;
    }

    final bool isPeak = slot['is_peak'] == true;

    if (_isCorporate) {
      if (_totalUsed + 1 > _dailyLimit) {
        setState(
          () => _error =
              'Daily limit $_dailyLimit hrs exceeded. Today used: $_totalUsed hr',
        );
        return;
      }
      if (isPeak && _peakUsed + 1 > _maxPeakPerDay) {
        setState(
          () => _error =
              'Max $_maxPeakPerDay hr Peak allowed. Peak used today: $_peakUsed hr. Book Off-Peak instead.',
        );
        return;
      }
    } else {
      final dynamic peakRem = widget.userPackage['peak_hours_remaining'];
      final dynamic offRem = widget.userPackage['offpeak_hours_remaining'];
      final int remaining = isPeak
          ? (peakRem is int ? peakRem : int.tryParse('$peakRem') ?? 0)
          : (offRem is int ? offRem : int.tryParse('$offRem') ?? 0);
      if (1 > remaining) {
        setState(
          () => _error =
              'Not enough ${isPeak ? 'Peak' : 'Off-Peak'} hours. Remaining: ${remaining}hr',
        );
        return;
      }
    }

    final weekdaysOnly =
        widget.userPackage['membership_package']?['weekdays_only'] == 1;
    if (weekdaysOnly &&
        (_date.weekday == DateTime.friday ||
            _date.weekday == DateTime.saturday)) {
      setState(
        () => _error =
            'This package weekdays only (Sun-Thu). ${DateFormat('EEEE').format(_date)} not allowed.',
      );
      return;
    }

    // FIXED: Combine 2 slots into 1 hour booking
    final String combinedEnd = nextSlot['end_time'] as String;

    setState(() {
      _selectedSlot = {
        'start_time': slot['start_time'],
        'end_time': combinedEnd, // 11:00 -> 12:00 (not 11:30)
        'is_peak': isPeak,
        'is_booked': false,
        'is_past': false,
        'original_start': slot['start_time'],
        'next_start': nextSlot['start_time'],
      };
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_selectedSlot == null) return;
    setState(() => _submitting = true);
    try {
      final String dateStr = DateFormat('yyyy-MM-dd').format(_date);
      await ApiService.bookMembershipSlot(
        userPackageId: widget.userPackage['id'] as int,
        bookingDate: dateStr,
        startTime: '${_selectedSlot!['start_time']}:00',
        endTime:
            '${_selectedSlot!['end_time']}:00', // Now 11:00:00 - 12:00:00 = 1 hour
        netId: _isCorporate ? null : _selectedNetId,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Booked ${_selectedSlot!['is_peak'] ? 'PEAK' : 'OFF-PEAK'} ${_selectedSlot!['start_time']}-${_selectedSlot!['end_time']} (1 hr) ${_isCorporate ? '(Full Facility)' : '(Net $_selectedNetId)'}',
          ),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e.toString().replaceAll('Exception:', '').trim(),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offPeak = _timeSlots.where((s) => s['is_peak'] == false).toList();
    final peak = _timeSlots.where((s) => s['is_peak'] == true).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'BOOK SLOT',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white54),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  color: AppTheme.primaryGreen,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(
                  DateFormat('EEEE, MMM d, yyyy').format(_date),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    final validUntilStr =
                        widget.userPackage['valid_until'] as String?;
                    final DateTime lastDate = validUntilStr != null
                        ? (DateTime.tryParse(validUntilStr) ??
                              DateTime.now().add(const Duration(days: 365)))
                        : DateTime.now().add(const Duration(days: 365));
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime.now(),
                      lastDate: lastDate,
                      builder: (c, ch) =>
                          Theme(data: ThemeData.dark(), child: ch!),
                    );
                    if (picked != null) {
                      setState(() => _date = picked);
                      _loadAvailability();
                    }
                  },
                  child: Text(
                    'CHANGE',
                    style: GoogleFonts.montserrat(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _isCorporate
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.purpleAccent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.apartment,
                          color: Colors.purpleAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Full Facility Booking (All 5 Nets)',
                          style: GoogleFonts.montserrat(
                            color: Colors.purpleAccent,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purpleAccent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'CORPORATE',
                            style: GoogleFonts.montserrat(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.sports_cricket,
                          color: AppTheme.primaryGreen,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Select Net:',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        DropdownButton<int>(
                          value: _selectedNetId,
                          dropdownColor: const Color(0xFF2A2A2A),
                          underline: const SizedBox(),
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                          items: _availableNets
                              .map(
                                (n) => DropdownMenuItem(
                                  value: n,
                                  child: Text('Net $n'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _selectedNetId = v);
                              _loadAvailability();
                            }
                          },
                        ),
                        const Spacer(),
                        Text(
                          'Single Net Only',
                          style: GoogleFonts.inter(
                            color: Colors.white38,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          if (_isCorporate)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Used today: $_totalUsed hr / $_dailyLimit hr | Peak: $_peakUsed hr / $_maxPeakPerDay hr',
                        style: GoogleFonts.inter(
                          color: Colors.orange.shade200,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryGreen,
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionHeader(
                          'OFF-PEAK',
                          '07:00 - 16:00 (30-min slots, 1hr = 2 slots)',
                          Colors.blue,
                          offPeak.length,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: offPeak.map((s) => _buildChip(s)).toList(),
                        ),
                        const SizedBox(height: 22),
                        _sectionHeader(
                          'PEAK',
                          '16:00 - 02:00 (30-min slots, 1hr = 2 slots)',
                          Colors.orange,
                          peak.length,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: peak.map((s) => _buildChip(s)).toList(),
                        ),
                        if (_bookedSlots.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            _isCorporate
                                ? 'Full Facility blocked: ${_bookedSlots.length} booking(s) at this time'
                                : 'Already booked on Net $_selectedNetId (red): ${_bookedSlots.length} slot(s)',
                            style: GoogleFonts.inter(
                              color: Colors.redAccent,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
          if (_error != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: GoogleFonts.inter(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedSlot == null
                      ? Colors.grey.shade800
                      : AppTheme.primaryGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _selectedSlot == null || _submitting
                    ? null
                    : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Text(
                        _selectedSlot == null
                            ? 'SELECT A SLOT (1 HOUR = 2 SLOTS)'
                            : 'CONFIRM ${_selectedSlot!['is_peak'] ? 'PEAK' : 'OFF-PEAK'} ${_selectedSlot!['start_time']}-${_selectedSlot!['end_time']} (1HR) ${_isCorporate ? '(FULL)' : '(NET $_selectedNetId)'}',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          color: Colors.black,
                        ),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Tap 11:00 → books 11:00-12:00 | Peak = 16:00-02:00 | Red = booked | Grey = past',
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String t, String sub, Color c, int count) => Row(
    children: [
      Container(
        width: 4,
        height: 14,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        t,
        style: GoogleFonts.montserrat(
          color: c,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          sub,
          style: GoogleFonts.inter(color: Colors.white38, fontSize: 10),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '$count',
          style: GoogleFonts.inter(
            color: c,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );

  Widget _buildChip(Map<String, dynamic> s) {
    final bool isPast = s['is_past'] == true;
    final bool isBooked = s['is_booked'] == true;
    final int idx = _timeSlots.indexWhere(
      (e) => e['start_time'] == s['start_time'],
    );
    final bool nextBooked = idx != -1 && idx + 1 < _timeSlots.length
        ? _timeSlots[idx + 1]['is_booked'] == true
        : true;
    final bool cannotBookOneHour =
        nextBooked ||
        (idx != -1 &&
            idx + 1 < _timeSlots.length &&
            _timeSlots[idx + 1]['is_peak'] != s['is_peak']);
    final bool isSelected =
        _selectedSlot != null &&
        _selectedSlot!['original_start'] == s['start_time'];
    Color bg;
    Color border;
    Color txt;
    if (isPast) {
      bg = const Color(0xFF1E1E1E);
      border = Colors.transparent;
      txt = Colors.white24;
    } else if (isBooked) {
      bg = Colors.red.shade900.withValues(alpha: 0.35);
      border = Colors.redAccent;
      txt = Colors.red.shade200;
    } else if (cannotBookOneHour && !isSelected) {
      bg = const Color(0xFF1E1E1E);
      border = Colors.white12;
      txt = Colors.white30;
    } else if (isSelected) {
      bg = AppTheme.primaryGreen;
      border = AppTheme.primaryGreen;
      txt = Colors.black;
    } else {
      bg = const Color(0xFF1E1E1E);
      final bool peak = s['is_peak'] == true;
      border = peak
          ? Colors.orange.withValues(alpha: 0.25)
          : Colors.blue.withValues(alpha: 0.25);
      txt = Colors.white;
    }
    return GestureDetector(
      onTap: isPast || isBooked || cannotBookOneHour
          ? () {
              if (cannotBookOneHour && !isPast && !isBooked) {
                setState(
                  () => _error =
                      'Need 2 free slots for 1 hour. Next slot ${idx + 1 < _timeSlots.length ? _timeSlots[idx + 1]['start_time'] : 'missing'} is booked or crosses 16:00.',
                );
              }
            }
          : () => _onSelectSlot(s),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border, width: isSelected ? 2 : 1),
        ),
        child: Text(
          s['start_time'] as String,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            color: txt,
          ),
        ),
      ),
    );
  }
}
