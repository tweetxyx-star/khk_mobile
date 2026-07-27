import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../services/api_service.dart';
import '../../models/package.dart';
import '../booking/widgets/payment_screen.dart';
import 'membership_detail_screen.dart';

class MyMembershipsScreen extends StatefulWidget {
  const MyMembershipsScreen({super.key});
  @override
  State<MyMembershipsScreen> createState() => _MyMembershipsScreenState();
}

class _MyMembershipsScreenState extends State<MyMembershipsScreen> {
  List<dynamic> myPackages = [];
  List<dynamic> storePackages = [];
  bool loading = true;
  String? errorMsg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() {
        loading = true;
        errorMsg = null;
      });
      final my = await ApiService.getMyMemberships();
      List<dynamic> store = [];
      try {
        store = await ApiService.getMembershipPackages();
      } catch (_) {
        store = [];
      }
      final activeMembershipIds = <int>{};
      for (final raw in my) {
        if (raw is! Map) continue;
        final m = raw;
        final status = (m['status'] ?? '').toString().toLowerCase();
        if (status != 'active') continue;
        final mp = m['membership_package'];
        if (mp is Map && mp['id'] != null) {
          activeMembershipIds.add(_asInt(mp['id']));
        } else if (m['membership_package_id'] != null) {
          activeMembershipIds.add(_asInt(m['membership_package_id']));
        }
      }
      store = store.where((p) {
        if (p is! Map) return true;
        final id = _asInt(p['id']);
        return !activeMembershipIds.contains(id);
      }).toList();
      if (!mounted) return;
      setState(() {
        myPackages = my;
        storePackages = store;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMsg = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _handleRenew(Map<String, dynamic> pkg) async {
    try {
      final id = _asInt(pkg['id']); // user_package id
      if (id == 0) throw 'Invalid package id';
      await ApiService.renewMembership(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Renew request sent'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  Future<void> _handleBuy(Map<String, dynamic> pkg) async {
    try {
      final id = _asInt(pkg['id']);
      if (id == 0) throw 'Invalid package id';
      final double price = _parsePrice(pkg);
      final Package payPkg = Package(
        id: id,
        name: pkg['name']?.toString() ?? 'Membership',
        category: pkg['type']?.toString() ?? 'membership',
        pricingType: 'package',
        description: pkg['description']?.toString() ?? '',
        totalPrice: price,
        includesFullFacility: (pkg['type']?.toString() == 'corporate'),
        isActive: true,
        validDays:
            int.tryParse(
              (pkg['valid_days'] ?? pkg['duration_days'] ?? 30).toString(),
            ) ??
            30,
        membershipDurationDays:
            int.tryParse(
              (pkg['duration_days'] ?? pkg['valid_days'] ?? 30).toString(),
            ) ??
            30,
      );
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryGreen),
        ),
      );
      Map<String, dynamic> pending;
      try {
        pending = await ApiService.purchaseMembership(id);
      } catch (e) {
        if (mounted) Navigator.pop(context);
        rethrow;
      }
      if (!mounted) return;
      Navigator.pop(context);
      // FIXED: backend returns { user_package: { id: 15 } } not { id: 15 }
      final int userPackageId = _asInt(
        pending['user_package']?['id'] ??
            pending['user_package']?['user_package_id'] ??
            pending['data']?['id'] ??
            pending['data']?['user_package']?['id'] ??
            pending['id'],
      );
      if (userPackageId == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${pkg['name']} - Request submitted'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
        _load();
        return;
      }
      final bool? paid = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            net: null,
            package: payPkg,
            selectedDate: DateTime.now(),
            selectedStartTime: '00:00',
            selectedEndTime: '00:00',
            selectedDuration: 2,
            totalPrice: price,
            facilityIds: const [],
            isFullFacility: false,
            isMembershipPurchase: true,
            membershipPackageId: id,
            userPackageId: userPackageId,
            onClose: () => Navigator.pop(context, false),
            onSuccess: () async {
              try {
                await ApiService.confirmMembershipPayment(userPackageId);
              } catch (_) {}
              if (mounted) Navigator.pop(context, true);
            },
          ),
        ),
      );
      if (paid == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${pkg['name']} - Payment successful, awaiting admin approval',
            ),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
        _load();
      }
    } catch (e) {
      if (!mounted) return;
      try {
        Navigator.pop(context);
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  double _parsePrice(Map<String, dynamic> pkg) {
    final cands = [pkg['price_bhd'], pkg['price'], pkg['amount']];
    for (final c in cands) {
      if (c == null) continue;
      if (c is num && c > 0) return c.toDouble();
      final d = double.tryParse(c.toString());
      if (d != null && d > 0) return d;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.bgBlack,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'MY MEMBERSHIPS',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w900,
            fontSize: 17,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGreen),
            )
          : RefreshIndicator(
              color: AppTheme.primaryGreen,
              backgroundColor: AppTheme.cardDark,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  if (errorMsg != null &&
                      myPackages.isEmpty &&
                      storePackages.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        errorMsg!,
                        style: GoogleFonts.inter(
                          color: Colors.redAccent,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (myPackages.isNotEmpty) ...[
                    _sectionHeader(
                      'MY ACTIVE MEMBERSHIPS',
                      Icons.verified_rounded,
                    ),
                    const SizedBox(height: 10),
                    ...myPackages.map((raw) {
                      final pkg = raw is Map<String, dynamic>
                          ? raw
                          : Map<String, dynamic>.from(raw as Map);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _MembershipHeroCard(
                          pkg: pkg,
                          onView: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  MembershipDetailScreen(userPackage: pkg),
                            ),
                          ).then((_) => _load()),
                          onRenew: () => _handleRenew(pkg),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                  ],
                  _sectionHeader(
                    myPackages.isEmpty
                        ? 'BUY MEMBERSHIP'
                        : 'BUY MORE MEMBERSHIPS',
                    Icons.card_membership_outlined,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    myPackages.isEmpty
                        ? 'Purchase Corporate (200 BHD) or Individual (80 / 150 BHD) to start booking.'
                        : 'You own ${myPackages.length} membership(s). Add another plan below.',
                    style: GoogleFonts.inter(
                      color: AppTheme.textGrey,
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (storePackages.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.cardDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.storefront_outlined,
                            color: Colors.white24,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No more packages to buy',
                            style: GoogleFonts.inter(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'You already own all available memberships',
                            style: GoogleFonts.inter(
                              color: Colors.white24,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...storePackages.map((raw) {
                      final pkg = raw is Map<String, dynamic>
                          ? raw
                          : <String, dynamic>{'id': 0, 'name': raw.toString()};
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _BuyMembershipCard(
                          pkg: pkg,
                          onBuy: () => _handleBuy(pkg),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 14, color: AppTheme.primaryGreen),
      ),
      const SizedBox(width: 8),
      Text(
        title,
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 0.8,
          color: Colors.white,
        ),
      ),
    ],
  );
  int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}

class _BuyMembershipCard extends StatelessWidget {
  final Map<String, dynamic> pkg;
  final VoidCallback onBuy;
  const _BuyMembershipCard({required this.pkg, required this.onBuy});
  double _parsePrice() {
    final candidates = [
      pkg['price_bhd'],
      pkg['price'],
      pkg['price_BHD'],
      pkg['amount'],
      pkg['off_peak_bhd'],
    ];
    for (final c in candidates) {
      if (c == null) continue;
      if (c is num && c > 0) return c.toDouble();
      final d = double.tryParse(c.toString());
      if (d != null && d > 0) return d;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final name = (pkg['name'] ?? '').toString();
    final type = (pkg['type'] ?? pkg['category'] ?? 'individual')
        .toString()
        .toLowerCase();
    final isCorporate = type == 'corporate';
    final price = _parsePrice();
    final imageUrl = (pkg['image_url'] ?? pkg['image'] ?? '').toString();
    final validDays = (pkg['valid_days'] ?? pkg['duration_days'] ?? 30)
        .toString();
    final dailyHours = (pkg['daily_hours_allowed'] ?? 2).toString();
    final maxPeak = (pkg['max_peak_per_day'] ?? 1).toString();
    final peakInc = (pkg['peak_hours_included'] ?? pkg['peak_hours'] ?? '0')
        .toString();
    final offInc = (pkg['offpeak_hours_included'] ?? pkg['off_hours'] ?? '0')
        .toString();
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              bottomLeft: Radius.circular(14),
            ),
            child: Container(
              width: 92,
              height: 112,
              color: const Color(0xFF1E1E1E),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => _fallbackIcon(isCorporate),
                        )
                      : _fallbackIcon(isCorporate),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isCorporate
                            ? const Color(0xFFFFA726)
                            : const Color(0xFF4FC3F7),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        isCorporate ? 'CORPORATE' : 'INDIVIDUAL',
                        style: GoogleFonts.montserrat(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isCorporate
                        ? '$dailyHours hrs/day • Max ${maxPeak}h Peak'
                        : '$peakInc Peak + $offInc Off • $validDays days',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.textGrey,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isCorporate
                          ? '2 Off-Peak ✓ • 2 Peak ✗'
                          : 'No cross 16:00',
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'BHD ${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)}',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 32,
                        width: 84,
                        child: ElevatedButton(
                          onPressed: onBuy,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            foregroundColor: Colors.black,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'BUY',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
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
    );
  }

  Widget _fallbackIcon(bool isCorporate) => Center(
    child: Icon(
      isCorporate ? Icons.business : Icons.person,
      size: 26,
      color: AppTheme.primaryGreen.withValues(alpha: 0.4),
    ),
  );
}

class _MembershipHeroCard extends StatelessWidget {
  final Map<String, dynamic> pkg;
  final VoidCallback onView;
  final VoidCallback onRenew;
  const _MembershipHeroCard({
    required this.pkg,
    required this.onView,
    required this.onRenew,
  });
  int _toInt(dynamic v, {int def = 0}) {
    if (v == null) return def;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? def;
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final mpRaw = pkg['membership_package'] ?? pkg['package'];
    final Map<String, dynamic> mp = mpRaw is Map<String, dynamic>
        ? mpRaw
        : <String, dynamic>{};
    final status = (pkg['status'] ?? 'pending').toString();
    final isActive = status == 'active';
    final isExpired = status == 'expired';
    final type =
        (mp['type'] ?? mp['category'] ?? pkg['package_type'] ?? 'individual')
            .toString()
            .toLowerCase();
    final isCorporate = type == 'corporate';
    final validUntilStr = (pkg['valid_until'] ?? '').toString();
    String validUntilDisplay = '-';
    int daysLeft = 0;
    try {
      if (validUntilStr.isNotEmpty) {
        final dt = DateTime.parse(validUntilStr);
        validUntilDisplay = validUntilStr.substring(0, 10);
        daysLeft = dt.difference(DateTime.now()).inDays;
      }
    } catch (_) {}
    final imageUrl = (mp['image_url'] ?? mp['image'] ?? '').toString();

    // ===== FIXED: TOTALS - read from mp, fallback to pkg =====
    final int peakTotal = _toInt(
      mp['peak_hours_included'] ??
          mp['peak_hours'] ??
          pkg['peak_hours_total'] ??
          pkg['peak_hours_included'] ??
          5,
      def: 5,
    );
    final int offTotal = _toInt(
      mp['offpeak_hours_included'] ??
          mp['off_peak_hours_included'] ??
          mp['off_hours'] ??
          pkg['offpeak_hours_total'] ??
          pkg['offpeak_hours_included'] ??
          3,
      def: 3,
    );

    // ===== FIXED: REMAINING - support both spellings, API now returns updated values =====
    int peakRem = _toInt(
      pkg['peak_hours_remaining'] ??
          pkg['peak_remaining'] ??
          pkg['peak_hours_left'],
      def: peakTotal,
    );
    int offRem = _toInt(
      pkg['offpeak_hours_remaining'] ??
          pkg['off_peak_hours_remaining'] ??
          pkg['offpeak_remaining'] ??
          pkg['off_remaining'],
      def: offTotal,
    );

    final int effectivePeakTotal = peakTotal > 0
        ? peakTotal
        : (peakRem > 0 ? peakRem : 1);
    final int effectiveOffTotal = offTotal > 0
        ? offTotal
        : (offRem > 0 ? offRem : 1);

    final double peakProgress =
        (effectivePeakTotal > 0
                ? _toDouble(peakRem) / _toDouble(effectivePeakTotal)
                : 0.0)
            .clamp(0.0, 1.0);
    final double offProgress =
        (effectiveOffTotal > 0
                ? _toDouble(offRem) / _toDouble(effectiveOffTotal)
                : 0.0)
            .clamp(0.0, 1.0);

    final int peakUsed = (effectivePeakTotal - peakRem).clamp(0, 999);
    final int offUsed = (effectiveOffTotal - offRem).clamp(0, 999);

    final dailyHours = _toInt(
      mp['daily_hours_allowed'] ?? pkg['daily_hours_allowed'],
      def: 2,
    );
    final maxPeak = _toDouble(
      mp['max_peak_per_day'] ?? pkg['max_peak_per_day'],
    );

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? AppTheme.primaryGreen.withValues(alpha: 0.5)
              : AppTheme.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              height: 128,
              width: double.infinity,
              color: const Color(0xFF1E1E1E),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) =>
                              _gradientFallback(isCorporate),
                        )
                      : _gradientFallback(isCorporate),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.15),
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 12,
                    right: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isCorporate
                                ? const Color(0xFFFFA726)
                                : const Color(0xFF4FC3F7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isCorporate ? 'CORPORATE' : 'INDIVIDUAL',
                            style: GoogleFonts.montserrat(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppTheme.primaryGreen
                                : Colors.orange,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: GoogleFonts.montserrat(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: isActive ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 12,
                    right: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mp['name']?.toString() ??
                              (isCorporate
                                  ? 'Corporate Membership'
                                  : 'Individual Membership'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Expires $validUntilDisplay • $daysLeft days',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCorporate) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.purple.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.apartment,
                          size: 16,
                          color: Colors.purpleAccent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Full Facility • $dailyHours hrs/day • Max ${maxPeak.toStringAsFixed(maxPeak.truncateToDouble() == maxPeak ? 0 : 1)}h Peak',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _infoChip(
                        Icons.access_time_rounded,
                        '$dailyHours hrs/day',
                      ),
                      _infoChip(Icons.bolt_rounded, 'Max $maxPeak hr Peak'),
                      _infoChip(
                        Icons.calendar_today_outlined,
                        validUntilDisplay,
                      ),
                      _infoChip(Icons.rule_outlined, 'No cross 16:00'),
                    ],
                  ),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'PEAK $peakRem/$effectivePeakTotal hrs remaining',
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: peakRem == 0
                              ? Colors.redAccent
                              : AppTheme.textGrey,
                        ),
                      ),
                      Text(
                        '${(peakProgress * 100).toInt()}% left',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: peakProgress < 0.3
                              ? Colors.redAccent
                              : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: peakProgress,
                      minHeight: 6,
                      backgroundColor: AppTheme.bgSecond,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        peakProgress < 0.3 ? Colors.redAccent : Colors.orange,
                      ),
                    ),
                  ),
                  if (peakUsed > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Used $peakUsed hr',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'OFF-PEAK $offRem/$effectiveOffTotal hrs remaining',
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: offRem == 0
                              ? Colors.redAccent
                              : AppTheme.textGrey,
                        ),
                      ),
                      Text(
                        '${(offProgress * 100).toInt()}% left',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: offProgress < 0.3
                              ? Colors.redAccent
                              : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: offProgress,
                      minHeight: 6,
                      backgroundColor: AppTheme.bgSecond,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        offProgress < 0.3 ? Colors.redAccent : Colors.lightBlue,
                      ),
                    ),
                  ),
                  if (offUsed > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Used $offUsed hr • Booked Net 1-5',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 84,
                      height: 38,
                      child: OutlinedButton(
                        onPressed: onView,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF3A3A3A)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(
                          'VIEW',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: ElevatedButton(
                          onPressed: isActive || isExpired ? onView : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isActive || isExpired
                                ? AppTheme.primaryGreen
                                : const Color(0xFF2A2A2A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                            elevation: 0,
                            padding: EdgeInsets.zero,
                          ),
                          child: Text(
                            isExpired
                                ? 'RENEW'
                                : isCorporate
                                ? 'BOOK DAILY SLOTS'
                                : 'BOOK SLOTS',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: isActive || isExpired
                                  ? Colors.black
                                  : Colors.white38,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (isExpired) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 84,
                        height: 38,
                        child: ElevatedButton(
                          onPressed: onRenew,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                            elevation: 0,
                            padding: EdgeInsets.zero,
                          ),
                          child: Text(
                            'RENEW',
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradientFallback(bool isCorporate) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: isCorporate
            ? [const Color(0xFF2C2A12), const Color(0xFF1A1A0A)]
            : [const Color(0xFF12202E), const Color(0xFF1A1A0A)],
      ),
    ),
    child: Center(
      child: Icon(
        isCorporate ? Icons.business : Icons.person,
        size: 32,
        color: AppTheme.primaryGreen.withValues(alpha: 0.3),
      ),
    ),
  );
  Widget _infoChip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: AppTheme.bgSecond,
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: AppTheme.cardBorder),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppTheme.primaryGreen),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, color: Colors.white),
        ),
      ],
    ),
  );
}
