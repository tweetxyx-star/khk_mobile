import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import '../../config/app_theme.dart';
import '../../services/api_service.dart';
import '../../models/net.dart';
import '../../models/facility.dart';
import '../../models/coach.dart';
import '../../models/package.dart';
import '../auth/login_screen.dart';
import 'widgets/booking_progress_bar.dart';
import 'widgets/booking_step_header.dart';
import 'widgets/rate_card_selection_step.dart';
import 'widgets/net_selection_step.dart';
import 'widgets/date_time_selection_step.dart';
import 'widgets/facility_selection_step.dart';
import 'widgets/booking_confirmation_step.dart';
import 'widgets/payment_screen.dart';

class BookingScreen extends StatefulWidget {
  final int? preselectedNetId;
  final int? preselectedPackageId;
  final bool isNetBooking;

  const BookingScreen({
    super.key,
    this.preselectedNetId,
    this.preselectedPackageId,
    this.isNetBooking = false,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  bool _showPaymentScreen = false;

  List<Package> _packages = [];
  List<Net> _nets = [];
  List<Map<String, dynamic>> _timeSlots = [];
  List<Map<String, dynamic>> _bookedSlots = [];
  List<Facility> _facilities = [];
  List<Coach> _coaches = [];

  List<int> _selectedConsecutiveIndices = [];

  Package? _selectedPackage;
  Net? _selectedNet;
  int _selectedDuration = 2;
  DateTime _selectedDate = DateTime.now();
  String? _selectedStartTime;
  String? _selectedEndTime;
  final Set<int> _selectedFacilityIds = {};
  final Set<int> _autoIncludedFacilityIds = {};
  Coach? _selectedCoach;

  bool _isLoading = true;
  bool _isLoadingSlots = false;
  String? _loadError;

  late AnimationController _pulseController;

  bool get _isEventBooking =>
      _selectedPackage?.bookingMode == BookingMode.eventBlock;

  bool get _isFullFacilityPackage {
    if (_selectedPackage == null) {
      return false;
    }
    final String nameLower = _selectedPackage!.name.toLowerCase();
    final String catLower = _selectedPackage!.category.toLowerCase();
    if (catLower == 'event' ||
        catLower == 'corporate' ||
        catLower == 'full_facility') {
      return true;
    }
    if (nameLower.contains('full facility')) {
      return true;
    }
    if (_selectedPackage!.isFullFacility == true) {
      return true;
    }
    return false;
  }

  bool get _isFullFacility => _isFullFacilityPackage;

  bool get _isDailyFlow {
    if (_isFullFacilityPackage) {
      return false;
    }
    return widget.isNetBooking || widget.preselectedNetId != null;
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _loadInitialData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  int get _totalSteps {
    if (_isFullFacilityPackage) {
      return 3;
    }
    if (_isEventBooking) {
      return 4;
    }
    if (_isDailyFlow) {
      if (widget.preselectedNetId != null) {
        return 4;
      }
      return 5;
    }
    return 6;
  }

  bool _parseIsPeak(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is int) return v == 1;
    if (v is num) return v == 1;
    if (v is String) return v == '1' || v.toLowerCase() == 'true';
    return false;
  }

  int _workingDayMinutes(String time) {
    try {
      final parts = time.split(':');
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      if (h >= 7) return h * 60 + m;
      return (24 * 60) + h * 60 + m;
    } catch (_) {
      return 0;
    }
  }

  bool _isPeakSlot(String? startTime) {
    if (startTime == null) return false;
    final h = int.tryParse(startTime.split(':')[0]) ?? 0;
    if (h >= 7 && h < 16) return false;
    return true;
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        ApiService.getAllPackages().catchError((_) => <Package>[]),
        ApiService.getNets().catchError((_) => <Net>[]),
        ApiService.getFacilities().catchError((_) => <Facility>[]),
      ]);
      _packages = results[0] as List<Package>;
      _nets = results[1] as List<Net>;
      _facilities = results[2] as List<Facility>;

      if (_packages.isEmpty) {
        setState(() {
          _loadError = 'No packages found';
          _isLoading = false;
        });
        return;
      }

      if (widget.preselectedPackageId != null) {
        _selectedPackage = _packages.firstWhereOrNull(
          (p) => p.id == widget.preselectedPackageId,
        );

        if (_selectedPackage != null) {
          if (_isFullFacilityPackage) {
            final int durHours =
                (_selectedPackage!.durationHours?.toInt() ?? 4);
            _selectedDuration = durHours * 2;
            _selectedNet = null;

            if (_selectedPackage!.hasBowlingMachine) {
              final Facility? bm = _facilities.firstWhereOrNull(
                (f) => f.name.toLowerCase().contains('bowling'),
              );
              if (bm != null) {
                _selectedFacilityIds.add(bm.id);
                _autoIncludedFacilityIds.add(bm.id);
              }
            }
            _currentStep = 0;
          } else if (widget.isNetBooking) {
            if (widget.preselectedNetId != null && _nets.isNotEmpty) {
              _selectedNet =
                  _nets.firstWhereOrNull(
                    (n) => n.id == widget.preselectedNetId,
                  ) ??
                  _nets.first;
            }
            _currentStep = 0;
          }
        }
      } else if (widget.preselectedNetId != null) {
        _selectedPackage =
            _packages.firstWhereOrNull(
              (p) =>
                  p.name.toLowerCase().contains('daily') ||
                  p.bookingMode == BookingMode.singleSlot,
            ) ??
            _packages.first;
        if (_nets.isNotEmpty) {
          _selectedNet =
              _nets.firstWhereOrNull((n) => n.id == widget.preselectedNetId) ??
              _nets.first;
        }
        _currentStep = 0;
      }

      setState(() {
        _isLoading = false;
      });

      if (_selectedPackage != null) {
        await _loadTimeSlots();
      }
    } catch (e) {
      setState(() {
        _loadError = 'Failed to load: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTimeSlots() async {
    if (_selectedPackage == null) {
      return;
    }
    setState(() {
      _isLoadingSlots = true;
      _selectedStartTime = null;
      _selectedEndTime = null;
      _selectedConsecutiveIndices = [];
    });
    try {
      final String dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final int netId = _isFullFacilityPackage ? 0 : (_selectedNet?.id ?? 0);

      // FIX: Always use selected package ID for correct pricing (25/45) from DB
      // Previously you were using daily net package ID which has 5/10 price
      final int packageIdForSlots = _selectedPackage!.id;

      final Map<String, dynamic> data = await ApiService.getTimeSlots(
        netId: netId,
        date: dateStr,
        packageId: packageIdForSlots,
      );

      List<Map<String, dynamic>> offPeakApi = [];
      List<Map<String, dynamic>> peakApi = [];
      List<Map<String, dynamic>> allApi = [];

      if (data.containsKey('off_peak_slots') ||
          data.containsKey('peak_slots')) {
        offPeakApi = List<Map<String, dynamic>>.from(
          data['off_peak_slots'] ?? [],
        );
        peakApi = List<Map<String, dynamic>>.from(data['peak_slots'] ?? []);
        allApi = [...offPeakApi, ...peakApi];
        if (allApi.isEmpty) {
          allApi = List<Map<String, dynamic>>.from(data['slots'] ?? []);
        }
      } else {
        allApi = List<Map<String, dynamic>>.from(data['slots'] ?? []);
      }

      List<Map<String, dynamic>> baseSlots = [];
      for (var slot in allApi) {
        final String rawStart = (slot['start_time'] as String?) ?? '';
        final String rawEnd = (slot['end_time'] as String?) ?? '';
        final String start = rawStart.length >= 5
            ? rawStart.substring(0, 5)
            : rawStart;
        final String end = rawEnd.length >= 5 ? rawEnd.substring(0, 5) : rawEnd;
        final bool available = slot['available'] == true;
        final bool isPeak = _parseIsPeak(slot['is_peak']);

        final int endMinRaw = _timeToMinutes(end);
        final int startMinRaw = _timeToMinutes(start);
        int diff = endMinRaw - startMinRaw;
        if (diff <= 0) diff += 24 * 60;

        if (_isFullFacilityPackage && diff > 60) {
          int cur = startMinRaw;
          int targetEnd = startMinRaw + diff;
          while (cur < targetEnd) {
            final int next = cur + 30;
            if (next > targetEnd) break;
            final String curStr = _minutesToTime(cur);
            final String nextStr = _minutesToTime(next);
            final bool curIsPeak = cur >= 16 * 60 || cur < 7 * 60;
            baseSlots.add({
              'start_time': curStr,
              'end_time': nextStr,
              'available': available,
              'is_peak': curIsPeak,
              'label': curIsPeak ? 'Peak' : 'Off-Peak',
            });
            cur = next;
          }
        } else {
          baseSlots.add({
            'start_time': start,
            'end_time': end.isEmpty
                ? _minutesToTime(_timeToMinutes(start) + 30)
                : end,
            'available': available,
            'is_peak': isPeak,
            'label': isPeak ? 'Peak' : 'Off-Peak',
          });
        }
      }

      baseSlots.sort(
        (a, b) => _workingDayMinutes(
          a['start_time'] as String,
        ).compareTo(_workingDayMinutes(b['start_time'] as String)),
      );

      setState(() {
        _timeSlots = baseSlots;
        _bookedSlots = _timeSlots
            .where((s) => s['available'] == false)
            .toList();
        _isLoadingSlots = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingSlots = false;
      });
      debugPrint('Load slots error: $e');
    }
  }

  int _timeToMinutes(String time) {
    try {
      final parts = time.split(':');
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      return h * 60 + m;
    } catch (_) {
      return 0;
    }
  }

  String _minutesToTime(int mins) {
    final total = mins % (24 * 60);
    final h = total ~/ 60;
    final m = total % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  Future<void> _loadCoaches(String date, String start, String end) async {
    try {
      final List<Coach> c = await ApiService.getAvailableCoaches(
        date: date,
        startTime: start,
        endTime: end,
      );
      if (mounted) {
        setState(() {
          _coaches = c;
        });
      }
    } catch (_) {}
  }

  bool _canContinue() {
    if (_isFullFacilityPackage) {
      switch (_currentStep) {
        case 0:
          return _selectedStartTime != null && _selectedEndTime != null;
        case 1:
          return true;
        case 2:
          return true;
        default:
          return false;
      }
    }
    if (_isDailyFlow) {
      if (widget.preselectedNetId != null) {
        switch (_currentStep) {
          case 0:
            return _selectedDuration > 0;
          case 1:
            return _selectedStartTime != null;
          case 2:
            return true;
          case 3:
            return true;
          default:
            return false;
        }
      } else {
        switch (_currentStep) {
          case 0:
            return _selectedNet != null;
          case 1:
            return _selectedDuration > 0;
          case 2:
            return _selectedStartTime != null;
          case 3:
            return true;
          case 4:
            return true;
          default:
            return false;
        }
      }
    }
    switch (_currentStep) {
      case 0:
        return _selectedPackage != null;
      case 1:
        return _selectedNet != null;
      case 2:
        return _selectedDuration > 0;
      case 3:
        return _selectedStartTime != null;
      case 4:
        return true;
      case 5:
        return true;
      default:
        return false;
    }
  }

  void _onContinue() {
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
      if (_isFullFacilityPackage) {
        if (_currentStep == 1 && _selectedStartTime != null) {
          _loadCoaches(
            DateFormat('yyyy-MM-dd').format(_selectedDate),
            _selectedStartTime!,
            _selectedEndTime!,
          );
        }
      } else if (_isDailyFlow) {
        if (widget.preselectedNetId != null && _currentStep == 1) {
          _loadTimeSlots();
        }
        if (widget.preselectedNetId == null && _currentStep == 2) {
          _loadTimeSlots();
        }
      } else {
        if (_currentStep == 3) {
          _loadTimeSlots();
        }
      }
    } else {
      _goToPayment();
    }
  }

  void _onBack() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    } else {
      Navigator.pop(context);
    }
  }

  void _goToPayment() async {
    if (_selectedStartTime == null) {
      return;
    }
    final bool loggedIn = await ApiService.isLoggedIn();
    if (!loggedIn && mounted) {
      final bool? res = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (res != true) {
        return;
      }
    }
    setState(() {
      _showPaymentScreen = true;
    });
  }

  double get _totalPrice {
    if (_selectedPackage == null) return 0;
    final pkg = _selectedPackage!;
    final double hours = _selectedDuration * 0.5;

    double base = 0;
    if (_selectedStartTime != null &&
        pkg.pricingType == 'hourly_peak_offpeak') {
      // FIX: Use peak-aware pricing from DB (25 Off / 45 Peak)
      base = pkg.getPriceForSlot(startTime: _selectedStartTime!, hours: hours);
    } else {
      base = pkg.getCurrentPrice(startTime: _selectedStartTime);
      if (pkg.pricingType == 'hourly_peak_offpeak') {
        base = base * hours;
      }
    }

    double fac = 0;
    for (final int id in _selectedFacilityIds) {
      if (_autoIncludedFacilityIds.contains(id)) continue;
      try {
        fac += _facilities.firstWhere((f) => f.id == id).price * hours;
      } catch (_) {}
    }
    final double coach = _selectedCoach != null
        ? (_selectedCoach!.hourlyRate ?? 25) * hours
        : 0;
    return base + fac + coach;
  }

  Widget _buildFullFacilityDateTimeStep() {
    final int durationHours = (_selectedPackage?.durationHours?.toInt() ?? 4);
    final int neededSlots = durationHours * 2;

    final offPeak = _timeSlots
        .where((s) => _parseIsPeak(s['is_peak']) == false)
        .toList();
    final peak = _timeSlots
        .where((s) => _parseIsPeak(s['is_peak']) == true)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BookingStepHeader(
          title: 'SELECT DATE & TIME',
          subtitle: 'Full Facility - 07:00 AM to 02:00 AM',
          icon: Icons.calendar_today_outlined,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.calendar_today,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textGrey,
                    ),
                  ),
                  Text(
                    DateFormat('EEE, MMM dd, yyyy').format(_selectedDate),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 60)),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedDate = picked;
                    });
                    _loadTimeSlots();
                  }
                },
                child: Text(
                  'CHANGE',
                  style: GoogleFonts.montserrat(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_isLoadingSlots)
          const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryGreen),
          )
        else if (_timeSlots.isEmpty)
          Text(
            'No slots available for this date',
            style: GoogleFonts.inter(color: AppTheme.textGrey),
          )
        else ...[
          Row(
            children: [
              Container(
                width: 4,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'OFF-PEAK',
                style: GoogleFonts.montserrat(
                  color: Colors.blue,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                '${offPeak.length} slots',
                style: GoogleFonts.inter(color: Colors.blue, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '07:00 AM - 03:59 PM',
            style: GoogleFonts.inter(color: AppTheme.textGrey, fontSize: 11),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: offPeak
                .asMap()
                .entries
                .map((e) => _buildFullFacilityChip(e, neededSlots))
                .toList(),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 4,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'PEAK',
                style: GoogleFonts.montserrat(
                  color: Colors.orange,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                '${peak.length} slots',
                style: GoogleFonts.inter(color: Colors.orange, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '04:00 PM - 02:00 AM',
            style: GoogleFonts.inter(color: AppTheme.textGrey, fontSize: 11),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: peak.asMap().entries.map((e) {
              final slot = e.value;
              final globalIndex = _timeSlots.indexWhere(
                (s) => s['start_time'] == slot['start_time'],
              );
              return _buildFullFacilityChip(
                MapEntry(globalIndex, slot),
                neededSlots,
              );
            }).toList(),
          ),
        ],
        if (_selectedPackage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedStartTime != null && _selectedEndTime != null
                        ? '$durationHours hour booking - Selected: $_selectedStartTime - $_selectedEndTime - Full Facility (All Nets) - ${_isPeakSlot(_selectedStartTime) ? 'Peak 45 BHD/hr' : 'Off-Peak 25 BHD/hr'}'
                        : '$durationHours hour booking - Tap a start time, $neededSlots consecutive 30-min slots will be auto-selected',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.blue.shade200,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFullFacilityChip(
    MapEntry<int, Map<String, dynamic>> entry,
    int neededSlots,
  ) {
    final int index = entry.key;
    final slot = entry.value;
    final bool available = slot['available'] == true;
    final bool isSelected = _selectedConsecutiveIndices.contains(index);
    final bool isStart = _selectedStartTime == slot['start_time'] && isSelected;
    final String start = (slot['start_time'] as String?) ?? '';
    final bool isPeak = _parseIsPeak(slot['is_peak']);

    return GestureDetector(
      onTap: !available
          ? null
          : () {
              List<int> consecutive = [];
              bool canBook = true;

              for (int i = 0; i < neededSlots; i++) {
                final int checkIndex = index + i;
                if (checkIndex >= _timeSlots.length) {
                  canBook = false;
                  break;
                }
                final checkSlot = _timeSlots[checkIndex];
                if (checkSlot['available'] != true) {
                  canBook = false;
                  break;
                }
                consecutive.add(checkIndex);
              }

              if (!canBook) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Not enough consecutive slots available from $start for ${neededSlots ~/ 2} hours',
                    ),
                    backgroundColor: Colors.red.shade800,
                  ),
                );
                return;
              }

              setState(() {
                _selectedConsecutiveIndices = consecutive;
                _selectedStartTime =
                    _timeSlots[consecutive.first]['start_time'] as String;
                _selectedEndTime =
                    _timeSlots[consecutive.last]['end_time'] as String;
              });
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryGreen
              : (available ? AppTheme.cardDark : Colors.grey.shade900),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isStart
                ? AppTheme.primaryGreen
                : (isSelected
                      ? AppTheme.primaryGreen.withValues(alpha: 0.5)
                      : (available
                            ? (isPeak
                                  ? Colors.orange.withValues(alpha: 0.3)
                                  : Colors.white24)
                            : Colors.transparent)),
            width: isStart ? 2 : 1,
          ),
        ),
        child: Text(
          start,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
            color: isSelected
                ? Colors.black
                : (available ? Colors.white : Colors.white30),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryGreen),
        ),
      );
    }
    if (_loadError != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(_loadError!, style: const TextStyle(color: Colors.white)),
        ),
      );
    }
    if (_showPaymentScreen) {
      return PaymentScreen(
        net: null,
        package: _selectedPackage!,
        selectedDate: _selectedDate,
        selectedStartTime: _selectedStartTime!,
        selectedEndTime: _selectedEndTime!,
        selectedDuration: _selectedDuration,
        totalPrice: _totalPrice,
        facilityIds: _selectedFacilityIds.toList(),
        coachId: _selectedCoach?.id,
        isFullFacility: true,
        onClose: () {
          setState(() {
            _showPaymentScreen = false;
          });
        },
        onSuccess: () => Navigator.pop(context, true),
        bookingId: null,
        rescheduleBookingId: null,
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isFullFacilityPackage
                        ? 'Full Facility Booking'
                        : (_isDailyFlow
                              ? 'Book Net Session'
                              : 'Book Your Session'),
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            BookingProgressBar(
              currentStep: _currentStep,
              totalSteps: _totalSteps,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildContent(),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isFullFacilityPackage) {
      switch (_currentStep) {
        case 0:
          return _buildFullFacilityDateTimeStep();
        case 1:
          return FacilitySelectionStep(
            key: const ValueKey('fac_full'),
            facilities: _facilities,
            coaches: _coaches,
            selectedFacilityIds: _selectedFacilityIds,
            selectedCoach: _selectedCoach,
            selectedStartTime: _selectedStartTime,
            selectedEndTime: _selectedEndTime,
            selectedDate: _selectedDate,
            selectedDuration: _selectedDuration,
            autoIncludedFacilityIds: _autoIncludedFacilityIds,
            onFacilityToggle: (id, sel) {
              setState(() {
                if (sel) {
                  _selectedFacilityIds.add(id);
                } else {
                  _selectedFacilityIds.remove(id);
                }
              });
            },
            onCoachSelect: (c) {
              setState(() {
                _selectedCoach = c;
              });
            },
            onLoadCoaches: _loadCoaches,
          );
        case 2:
          return BookingConfirmationStep(
            key: const ValueKey('conf_full'),
            net: null,
            package: _selectedPackage!,
            selectedDate: _selectedDate,
            selectedStartTime: _selectedStartTime,
            selectedEndTime: _selectedEndTime,
            selectedDuration: _selectedDuration,
            selectedFacilities: _facilities
                .where((f) => _selectedFacilityIds.contains(f.id))
                .toList(),
            selectedCoach: _selectedCoach,
            totalPrice: _totalPrice,
            isFullFacility: true,
          );
        default:
          return const SizedBox();
      }
    }
    if (_isDailyFlow) {
      if (widget.preselectedNetId != null) {
        switch (_currentStep) {
          case 0:
            return _buildDurationStep();
          case 1:
            return DateTimeSelectionStep(
              key: const ValueKey('dt'),
              selectedNet: _selectedNet,
              selectedPackage: _selectedPackage,
              selectedDate: _selectedDate,
              selectedDuration: _selectedDuration,
              timeSlots: _timeSlots,
              bookedSlots: _bookedSlots,
              isLoadingSlots: _isLoadingSlots,
              selectedStartTime: _selectedStartTime,
              isFullFacility: _isFullFacility,
              onDateChanged: (d) {
                setState(() {
                  _selectedDate = d;
                });
                _loadTimeSlots();
              },
              onSlotSelected: (s, e, _, ad) {
                setState(() {
                  _selectedStartTime = s;
                  _selectedEndTime = e;
                  _selectedDate = ad;
                });
              },
            );
          case 2:
            return FacilitySelectionStep(
              key: const ValueKey('fac'),
              facilities: _facilities,
              coaches: _coaches,
              selectedFacilityIds: _selectedFacilityIds,
              selectedCoach: _selectedCoach,
              selectedStartTime: _selectedStartTime,
              selectedEndTime: _selectedEndTime,
              selectedDate: _selectedDate,
              selectedDuration: _selectedDuration,
              autoIncludedFacilityIds: _autoIncludedFacilityIds,
              onFacilityToggle: (id, sel) {
                setState(() {
                  if (sel) {
                    _selectedFacilityIds.add(id);
                  } else {
                    _selectedFacilityIds.remove(id);
                  }
                });
              },
              onCoachSelect: (c) {
                setState(() {
                  _selectedCoach = c;
                });
              },
              onLoadCoaches: _loadCoaches,
            );
          case 3:
            return BookingConfirmationStep(
              key: const ValueKey('conf'),
              net: _selectedNet,
              package: _selectedPackage!,
              selectedDate: _selectedDate,
              selectedStartTime: _selectedStartTime,
              selectedEndTime: _selectedEndTime,
              selectedDuration: _selectedDuration,
              selectedFacilities: _facilities
                  .where((f) => _selectedFacilityIds.contains(f.id))
                  .toList(),
              selectedCoach: _selectedCoach,
              totalPrice: _totalPrice,
              isFullFacility: _isFullFacility,
            );
          default:
            return const SizedBox();
        }
      } else {
        switch (_currentStep) {
          case 0:
            return NetSelectionStep(
              key: const ValueKey('net'),
              nets: _nets,
              selectedNet: _selectedNet,
              onSelect: (n) {
                setState(() {
                  _selectedNet = n;
                });
              },
            );
          case 1:
            return _buildDurationStep();
          case 2:
            return DateTimeSelectionStep(
              key: const ValueKey('dt'),
              selectedNet: _selectedNet,
              selectedPackage: _selectedPackage,
              selectedDate: _selectedDate,
              selectedDuration: _selectedDuration,
              timeSlots: _timeSlots,
              bookedSlots: _bookedSlots,
              isLoadingSlots: _isLoadingSlots,
              selectedStartTime: _selectedStartTime,
              isFullFacility: _isFullFacility,
              onDateChanged: (d) {
                setState(() {
                  _selectedDate = d;
                });
                _loadTimeSlots();
              },
              onSlotSelected: (s, e, _, ad) {
                setState(() {
                  _selectedStartTime = s;
                  _selectedEndTime = e;
                  _selectedDate = ad;
                });
              },
            );
          case 3:
            return FacilitySelectionStep(
              key: const ValueKey('fac'),
              facilities: _facilities,
              coaches: _coaches,
              selectedFacilityIds: _selectedFacilityIds,
              selectedCoach: _selectedCoach,
              selectedStartTime: _selectedStartTime,
              selectedEndTime: _selectedEndTime,
              selectedDate: _selectedDate,
              selectedDuration: _selectedDuration,
              autoIncludedFacilityIds: _autoIncludedFacilityIds,
              onFacilityToggle: (id, sel) {
                setState(() {
                  if (sel) {
                    _selectedFacilityIds.add(id);
                  } else {
                    _selectedFacilityIds.remove(id);
                  }
                });
              },
              onCoachSelect: (c) {
                setState(() {
                  _selectedCoach = c;
                });
              },
              onLoadCoaches: _loadCoaches,
            );
          case 4:
            return BookingConfirmationStep(
              key: const ValueKey('conf'),
              net: _selectedNet,
              package: _selectedPackage!,
              selectedDate: _selectedDate,
              selectedStartTime: _selectedStartTime,
              selectedEndTime: _selectedEndTime,
              selectedDuration: _selectedDuration,
              selectedFacilities: _facilities
                  .where((f) => _selectedFacilityIds.contains(f.id))
                  .toList(),
              selectedCoach: _selectedCoach,
              totalPrice: _totalPrice,
              isFullFacility: _isFullFacility,
            );
          default:
            return const SizedBox();
        }
      }
    }
    switch (_currentStep) {
      case 0:
        return RateCardSelectionStep(
          key: const ValueKey('pkg'),
          categories: _packages,
          selectedCard: _selectedPackage,
          onSelect: (p) {
            setState(() {
              _selectedPackage = p;
            });
          },
        );
      case 1:
        return NetSelectionStep(
          key: const ValueKey('net'),
          nets: _nets,
          selectedNet: _selectedNet,
          onSelect: (n) {
            setState(() {
              _selectedNet = n;
            });
          },
        );
      case 2:
        return _buildDurationStep();
      case 3:
        return DateTimeSelectionStep(
          key: const ValueKey('dt'),
          selectedNet: _selectedNet,
          selectedPackage: _selectedPackage,
          selectedDate: _selectedDate,
          selectedDuration: _selectedDuration,
          timeSlots: _timeSlots,
          bookedSlots: _bookedSlots,
          isLoadingSlots: _isLoadingSlots,
          selectedStartTime: _selectedStartTime,
          isFullFacility: _isFullFacility,
          onDateChanged: (d) {
            setState(() {
              _selectedDate = d;
            });
            _loadTimeSlots();
          },
          onSlotSelected: (s, e, _, ad) {
            setState(() {
              _selectedStartTime = s;
              _selectedEndTime = e;
              _selectedDate = ad;
            });
          },
        );
      case 4:
        return FacilitySelectionStep(
          key: const ValueKey('fac'),
          facilities: _facilities,
          coaches: _coaches,
          selectedFacilityIds: _selectedFacilityIds,
          selectedCoach: _selectedCoach,
          selectedStartTime: _selectedStartTime,
          selectedEndTime: _selectedEndTime,
          selectedDate: _selectedDate,
          selectedDuration: _selectedDuration,
          autoIncludedFacilityIds: _autoIncludedFacilityIds,
          onFacilityToggle: (id, sel) {
            setState(() {
              if (sel) {
                _selectedFacilityIds.add(id);
              } else {
                _selectedFacilityIds.remove(id);
              }
            });
          },
          onCoachSelect: (c) {
            setState(() {
              _selectedCoach = c;
            });
          },
          onLoadCoaches: _loadCoaches,
        );
      case 5:
        return BookingConfirmationStep(
          key: const ValueKey('conf'),
          net: _selectedNet,
          package: _selectedPackage!,
          selectedDate: _selectedDate,
          selectedStartTime: _selectedStartTime,
          selectedEndTime: _selectedEndTime,
          selectedDuration: _selectedDuration,
          selectedFacilities: _facilities
              .where((f) => _selectedFacilityIds.contains(f.id))
              .toList(),
          selectedCoach: _selectedCoach,
          totalPrice: _totalPrice,
          isFullFacility: _isFullFacility,
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildDurationStep() {
    return Column(
      key: const ValueKey('dur'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BookingStepHeader(
          title: 'SELECT DURATION',
          subtitle: 'How long do you want to play?',
          icon: Icons.timer_outlined,
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [2, 4, 6, 8, 10]
              .map(
                (s) => _buildDurationOption(
                  s,
                  '${s ~/ 2} hour${s > 2 ? 's' : ''}',
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildDurationOption(int slots, String label) {
    final bool sel = _selectedDuration == slots;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDuration = slots;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: sel
              ? AppTheme.primaryGreen
              : AppTheme.cardDark.withValues(alpha: 0.6),
          border: Border.all(
            color: sel ? AppTheme.primaryGreen : Colors.white24,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: sel ? Colors.black : Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.9),
        border: const Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _onBack,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'BACK',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _canContinue() ? _onContinue : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: Colors.grey.shade800,
              ),
              child: Text(
                _currentStep == _totalSteps - 1
                    ? 'CONFIRM BOOKING'
                    : 'CONTINUE',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
