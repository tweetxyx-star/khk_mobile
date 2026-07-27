import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../models/package.dart';
import '../../services/api_service.dart';
import '../booking/booking_screen.dart';

class PackagesScreen extends StatefulWidget {
  const PackagesScreen({super.key});

  @override
  State<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends State<PackagesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Package> individualPackages = [];
  List<Package> eventPackages = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    try {
      setState(() => loading = true);
      final all = await ApiService.getPackages();
      if (mounted) {
        setState(() {
          individualPackages = all
              .where((p) => p.category == 'net' || p.category == 'individual')
              .toList();
          eventPackages = all.where((p) => p.category == 'event').toList();
          loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [Packages] Load error: $e');
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        elevation: 0,
        title: Text(
          'BOOKING',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w900,
            color: Colors.white,
            fontSize: 18,
            letterSpacing: 1.2,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppTheme.primaryGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.white54,
              labelStyle: GoogleFonts.montserrat(
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
              unselectedLabelStyle: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              tabs: const [
                Tab(text: 'INDIVIDUAL'),
                Tab(text: 'EVENTS'),
              ],
            ),
          ),
        ),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGreen),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildThumbnailList(individualPackages, 'individual'),
                _buildThumbnailList(eventPackages, 'event'),
              ],
            ),
    );
  }

  Widget _buildThumbnailList(List<Package> packages, String type) {
    if (packages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white10),
              ),
              child: Icon(
                type == 'individual'
                    ? Icons.sports_cricket
                    : Icons.celebration_outlined,
                size: 36,
                color: Colors.white24,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No ${type.toUpperCase()} packages',
              style: GoogleFonts.montserrat(
                color: Colors.white54,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPackages,
      color: AppTheme.primaryGreen,
      backgroundColor: const Color(0xFF1E1E1E),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: packages.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _PremiumThumbnailCard(package: packages[index]);
        },
      ),
    );
  }
}

// ============================================================
// PREMIUM THUMBNAIL CARD
// ============================================================
class _PremiumThumbnailCard extends StatelessWidget {
  final Package package;
  const _PremiumThumbnailCard({required this.package});

  @override
  Widget build(BuildContext context) {
    final isPeakNow =
        package.peakBhd != package.offPeakBhd &&
        package.getCurrentPrice() == package.peakBhd;

    return InkWell(
      onTap: () => _showDetails(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF242424)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: SizedBox(
                width: 92,
                height: 112,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    package.imageUrl != null
                        ? Image.network(
                            package.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) => _iconBox(),
                          )
                        : _iconBox(),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _badgeColor(),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          package.category.toUpperCase(),
                          style: GoogleFonts.montserrat(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      package.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.montserrat(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _meta(Icons.timer_outlined, _duration()),
                        const SizedBox(width: 10),
                        if (package.validDays != null)
                          _meta(Icons.event_outlined, '${package.validDays}d'),
                        if (package.sessionsCount != null)
                          _meta(Icons.repeat, '${package.sessionsCount}S'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        if (package.weekdaysOnly)
                          _miniChip('WEEKDAYS', Icons.calendar_view_week),
                        if (package.weekendsHolidaysOnly)
                          _miniChip('WEEKEND', Icons.weekend),
                        if (package.pricingType == 'hourly_peak_offpeak' &&
                            package.peakBhd != package.offPeakBhd)
                          _miniChip(
                            isPeakNow ? 'PEAK NOW' : 'OFF-PEAK NOW',
                            Icons.bolt_outlined,
                            isActive: isPeakNow,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: _priceWidget()),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'BOOK',
                                style: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 13,
                                color: Colors.black,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBox() {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: Center(
        child: Icon(
          _iconForCategory(),
          size: 28,
          color: AppTheme.primaryGreen.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Color _badgeColor() {
    switch (package.category) {
      case 'net':
      case 'individual':
        return const Color(0xFF4FC3F7);
      case 'event':
        return const Color(0xFFCE93D8);
      default:
        return AppTheme.primaryGreen;
    }
  }

  IconData _iconForCategory() {
    switch (package.category) {
      case 'event':
        return Icons.celebration_outlined;
      default:
        return Icons.sports_cricket;
    }
  }

  String _duration() {
    if (package.pricingType == 'package') {
      return '${package.peakHoursIncluded ?? 0}P+${package.offpeakHoursIncluded ?? 0}OP';
    }
    if (package.pricingType == 'flat_rate') {
      return '${package.durationHours ?? 4}H FLAT';
    }
    return '${package.durationHours ?? 1}H';
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12.5, color: Colors.white38),
        const SizedBox(width: 3),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: Colors.white60,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _miniChip(String label, IconData icon, {bool isActive = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.orange.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isActive
              ? Colors.orange.withValues(alpha: 0.3)
              : Colors.white10,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 10,
            color: isActive ? Colors.orange : Colors.white54,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              color: isActive ? Colors.orange : Colors.white60,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceWidget() {
    String price;
    String subLabel;

    if (package.pricingType == 'hourly_peak_offpeak') {
      final isPeak =
          package.getCurrentPrice() == package.peakBhd &&
          package.peakBhd != package.offPeakBhd;
      price = 'BHD ${package.getCurrentPrice().toStringAsFixed(3)}';
      subLabel = isPeak ? 'Peak/hr now' : 'Off-peak/hr now';
    } else if (package.pricingType == 'flat_rate') {
      price =
          'BHD ${(package.flat4hrBhd ?? 0).toStringAsFixed(0)} - ${(package.flat8hrBhd ?? 0).toStringAsFixed(0)}';
      subLabel = '4hr - 8hr flat';
    } else if (package.pricingType == 'package') {
      final total =
          ((package.peakHoursIncluded ?? 0) * (package.peakBhd ?? 0)) +
          ((package.offpeakHoursIncluded ?? 0) * (package.offPeakBhd ?? 0));
      price = 'BHD ${total.toStringAsFixed(0)}';
      subLabel = 'Package total';
    } else {
      price = 'BHD ${package.getCurrentPrice().toStringAsFixed(3)}';
      subLabel = 'Starting from';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          price,
          style: GoogleFonts.montserrat(
            fontSize: 14.5,
            fontWeight: FontWeight.w900,
            color: AppTheme.primaryGreen,
            height: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subLabel,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: Colors.white38,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _DetailSheet(package: package),
    );
  }
}

class _DetailSheet extends StatelessWidget {
  final Package package;
  const _DetailSheet({required this.package});

  @override
  Widget build(BuildContext context) {
    final bool isDailyNet =
        !package.name.toLowerCase().contains('full') &&
        (package.category == 'net' ||
            package.category == 'individual' ||
            package.bookingMode == BookingMode.singleSlot);

    final bool isPeakNow =
        package.peakBhd != package.offPeakBhd &&
        package.getCurrentPrice() == package.peakBhd;

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF141414),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: package.imageUrl != null
                            ? Image.network(
                                package.imageUrl!,
                                height: 190,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) =>
                                    Container(
                                      height: 190,
                                      color: const Color(0xFF1E1E1E),
                                      child: const Icon(
                                        Icons.image_not_supported,
                                        color: Colors.white24,
                                        size: 40,
                                      ),
                                    ),
                              )
                            : Container(
                                height: 140,
                                width: double.infinity,
                                color: const Color(0xFF1E1E1E),
                                child: Icon(
                                  package.category == 'event'
                                      ? Icons.celebration
                                      : Icons.sports_cricket,
                                  size: 42,
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              package.name,
                              style: GoogleFonts.montserrat(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.25,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: package.category == 'event'
                                  ? const Color(0xFFCE93D8)
                                  : const Color(0xFF4FC3F7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              package.category.toUpperCase(),
                              style: GoogleFonts.montserrat(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.primaryGreen.withValues(
                              alpha: 0.18,
                            ),
                          ),
                        ),
                        child: _buildPriceSection(),
                      ),
                      const SizedBox(height: 16),
                      _row(Icons.timer_outlined, 'Duration', _durationDetail()),
                      _row(
                        Icons.category_outlined,
                        'Type',
                        package.category.toUpperCase(),
                      ),
                      if (isDailyNet)
                        _row(Icons.sports_cricket, 'Coverage', 'Single Net')
                      else
                        _row(
                          Icons.stadium_outlined,
                          'Coverage',
                          'Full Facility',
                        ),
                      _row(
                        Icons.access_time,
                        'Peak Hours',
                        '${package.peakStart ?? '16:00'} - ${package.peakEnd ?? '00:00'}',
                      ),
                      if (package.weekdaysOnly)
                        _row(
                          Icons.calendar_view_week,
                          'Availability',
                          'Weekdays Only (Sun-Thu)',
                        ),
                      if (package.weekendsHolidaysOnly)
                        _row(
                          Icons.weekend,
                          'Availability',
                          'Fri, Sat & Public Holidays',
                        ),
                      if (package.paymentInAdvance == true)
                        _row(
                          Icons.verified_outlined,
                          'Payment',
                          'Advance Payment Required',
                        ),
                      if (package.description != null &&
                          package.description!.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Text(
                          'ABOUT',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white54,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          package.description!,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            color: Colors.white70,
                            height: 1.55,
                          ),
                        ),
                      ],
                      if (isPeakNow &&
                          package.peakBhd != package.offPeakBhd) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.bolt,
                                size: 14,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Peak pricing is currently active',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BookingScreen(
                                  preselectedPackageId: package.id,
                                  isNetBooking: isDailyNet,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'BOOK NOW',
                            style: GoogleFonts.montserrat(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPriceSection() {
    if (package.pricingType == 'hourly_peak_offpeak') {
      return Column(
        children: [
          _priceRow(
            'Off-Peak (07:00-16:00)',
            'BHD ${(package.offPeakBhd ?? 0).toStringAsFixed(3)}',
          ),
          const SizedBox(height: 8),
          _priceRow(
            'Peak (16:00-02:00)',
            'BHD ${(package.peakBhd ?? 0).toStringAsFixed(3)}',
            highlight: true,
          ),
        ],
      );
    } else if (package.pricingType == 'flat_rate') {
      return Column(
        children: [
          _priceRow(
            '4 Hours',
            'BHD ${(package.flat4hrBhd ?? 0).toStringAsFixed(0)}',
          ),
          const SizedBox(height: 8),
          _priceRow(
            '8 Hours',
            'BHD ${(package.flat8hrBhd ?? 0).toStringAsFixed(0)}',
            highlight: true,
          ),
        ],
      );
    } else if (package.pricingType == 'package') {
      return Column(
        children: [
          _priceRow(
            '${package.peakHoursIncluded ?? 0} Peak hrs',
            'BHD ${((package.peakHoursIncluded ?? 0) * (package.peakBhd ?? 0)).toStringAsFixed(0)}',
          ),
          const SizedBox(height: 8),
          _priceRow(
            '${package.offpeakHoursIncluded ?? 0} Off-Peak hrs',
            'BHD ${((package.offpeakHoursIncluded ?? 0) * (package.offPeakBhd ?? 0)).toStringAsFixed(0)}',
          ),
          const Divider(color: Color(0xFF2A2A2A), height: 20),
          _priceRow(
            'Total Package',
            'BHD ${(((package.peakHoursIncluded ?? 0) * (package.peakBhd ?? 0)) + ((package.offpeakHoursIncluded ?? 0) * (package.offPeakBhd ?? 0))).toStringAsFixed(0)}',
            bold: true,
          ),
        ],
      );
    }
    return _priceRow(
      'Price',
      'BHD ${package.getCurrentPrice().toStringAsFixed(3)}',
      bold: true,
    );
  }

  Widget _priceRow(
    String label,
    String value, {
    bool bold = false,
    bool highlight = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.white60,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.montserrat(
            fontSize: bold ? 16 : 13.5,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            color: highlight ? Colors.orange : AppTheme.primaryGreen,
          ),
        ),
      ],
    );
  }

  String _durationDetail() {
    if (package.pricingType == 'package') {
      return '${package.peakHoursIncluded ?? 0}P + ${package.offpeakHoursIncluded ?? 0}OP hrs';
    }
    if (package.pricingType == 'flat_rate') {
      return '${package.durationHours ?? 4} Hours flat';
    }
    if (package.pricingType == 'weekly') {
      return '${package.durationHours ?? 2} hrs/day';
    }
    return '${package.durationHours ?? 1} Hour(s)';
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppTheme.primaryGreen),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: Colors.white60,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
