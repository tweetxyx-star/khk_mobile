import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../config/app_theme.dart';
import '../../widgets/quick_action.dart';
import '../../widgets/net_card.dart';
import '../../widgets/package_card.dart';
import '../../services/api_service.dart';
import '../../models/net.dart';
import '../../models/package.dart';
import '../booking/booking_screen.dart';
import '../booking/my_bookings_screen.dart';
import '../packages/packages_screen.dart';
import '../coaching/coaching_screen.dart';
import '../live_stream/live_stream_screen.dart';
import '../profile/profile_screen.dart';
import '../membership/my_memberships_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int currentPackageIndex = 0;
  int _currentBanner = 0;
  final PageController _packageController = PageController();
  final PageController _bannerController = PageController();
  final ScrollController _featuresController = ScrollController();
  Timer? _packageTimer;
  Timer? _bannerTimer;
  Timer? _featuresTimer;
  Timer? _refreshTimer;

  List<Net> nets = [];
  List<Package> packages = [];
  Map<String, String?> appImages = {
    'logo': null,
    'bg_image': null,
    'banner1': null,
    'banner2': null,
    'banner3': null,
  };
  bool loading = true;

  final String baseUrl = 'https://khkcricket.bh';

  final Map<String, dynamic> config = {
    'hero_title': 'PLAY.\nPRACTICE.',
    'hero_title_highlight': 'PERFORM.',
    'hero_subtitle': 'Premium Indoor Cricket Nets\nBook Anytime, Anywhere.',
    'hero_cta_text': 'BOOK NET NOW',
  };

  final List<Map<String, dynamic>> features = [
    {
      'icon': Icons.ac_unit,
      'title': 'AC Indoor Arena',
      'subtitle': 'Comfortable Play',
    },
    {
      'icon': Icons.bolt,
      'title': 'Bowling Machine',
      'subtitle': 'Practice Better',
    },
    {
      'icon': Icons.videocam,
      'title': 'Live Streaming',
      'subtitle': 'Record & Watch',
    },
    {
      'icon': Icons.local_parking,
      'title': 'Ample Parking',
      'subtitle': 'Hassle Free',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _startAutoSlide();
    _startBannerSlide();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _loadNetsWithStatus(),
    );
  }

  Future<void> _loadData() async {
    try {
      await Future.wait([
        _loadNetsWithStatus(),
        _loadPackages(),
        _loadAppImages(),
      ]);
    } catch (e) {
      debugPrint('Load error: $e');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _loadAppImages() async {
    try {
      final data = await ApiService.getAppConfig();
      if (mounted) {
        setState(() {
          appImages = {
            'logo': data['logo'],
            'bg_image': data['bg_image'],
            'banner1': data['banner1'],
            'banner2': data['banner2'],
            'banner3': data['banner3'],
          };
        });
      }
    } catch (e) {
      debugPrint('App images error: $e');
    }
  }

  Future<void> _loadNetsWithStatus() async {
    try {
      final netsData = await ApiService.getNets();
      final bahrainTime = DateTime.now().toUtc().add(const Duration(hours: 3));
      final today = DateFormat('yyyy-MM-dd').format(bahrainTime);
      final currentTimeStr = DateFormat('HH:mm').format(bahrainTime);

      final pkgs = await ApiService.getAllPackages();
      final defaultPackage = pkgs.isNotEmpty
          ? pkgs.firstWhere(
              (p) => p.category == 'individual' || p.category == 'net',
              orElse: () => pkgs.first,
            )
          : null;

      if (defaultPackage == null) {
        if (mounted) {
          setState(() => nets = netsData);
        }
        return;
      }

      final updatedNets = <Net>[];
      for (var net in netsData) {
        try {
          final response = await ApiService.getTimeSlots(
            netId: net.id,
            date: today,
            packageId: defaultPackage.id,
          );
          final slots = response['slots'] as List;
          bool isBusy = slots.any((slot) {
            final start = slot['start_time'] as String;
            final end = slot['end_time'] as String;
            final available = slot['available'] as bool;
            return currentTimeStr.compareTo(start) >= 0 &&
                currentTimeStr.compareTo(end) < 0 &&
                !available;
          });
          String? nextSlot;
          try {
            final nextAvailable = slots.firstWhere((slot) {
              final start = slot['start_time'] as String;
              final available = slot['available'] as bool;
              return available && start.compareTo(currentTimeStr) > 0;
            });
            nextSlot = _formatTime(nextAvailable['start_time'] as String);
          } catch (e) {
            nextSlot = null;
          }
          updatedNets.add(
            net.copyWith(
              status: isBusy ? 'busy' : 'available',
              nextSlot: nextSlot,
            ),
          );
        } catch (e) {
          updatedNets.add(net.copyWith(status: 'available', nextSlot: null));
        }
      }
      if (mounted) {
        setState(() => nets = updatedNets);
      }
    } catch (e) {
      debugPrint('Nets error: $e');
    }
  }

  Future<void> _loadPackages() async {
    try {
      final data = await ApiService.getPackages();
      if (mounted) {
        setState(() => packages = data);
      }
    } catch (e) {
      if (mounted) {
        setState(() => packages = []);
      }
    }
  }

  String _formatTime(String time) {
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$hour12:${parts[1]} $ampm';
  }

  List<Map<String, dynamic>> get _eventBanners {
    final banners = <Map<String, dynamic>>[];
    if (appImages['banner1'] != null) {
      banners.add({
        'image': appImages['banner1']!,
        'action': 'tournament',
        'id': 'winter_cup_2026',
      });
    }
    if (appImages['banner2'] != null) {
      banners.add({
        'image': appImages['banner2']!,
        'action': 'coaching',
        'id': 'elite_camp_dec',
      });
    }
    if (appImages['banner3'] != null) {
      banners.add({
        'image': appImages['banner3']!,
        'action': 'booking',
        'net_id': 3,
      });
    }
    return banners;
  }

  void _startBannerSlide() {
    if (_eventBanners.length > 1) {
      _bannerTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (mounted && _bannerController.hasClients) {
          _currentBanner = (_currentBanner + 1) % _eventBanners.length;
          _bannerController.animateToPage(
            _currentBanner,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  void _startAutoSlide() {
    if (packages.length > 1) {
      _packageTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
        if (mounted && _packageController.hasClients) {
          setState(() {
            currentPackageIndex = (currentPackageIndex + 1) % packages.length;
          });
          _packageController.animateToPage(
            currentPackageIndex,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
      });
    }
    _featuresTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted && _featuresController.hasClients) {
        final maxScroll = _featuresController.position.maxScrollExtent;
        final current = _featuresController.offset;
        if (current >= maxScroll) {
          _featuresController.jumpTo(0);
        } else {
          _featuresController.animateTo(
            current + 1,
            duration: const Duration(milliseconds: 50),
            curve: Curves.linear,
          );
        }
      }
    });
  }

  void _onBannerTap(Map<String, dynamic> banner) {
    switch (banner['action']) {
      case 'tournament':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tournament ${banner['id']} coming soon!')),
        );
        break;
      case 'coaching':
        _navigateToCoaching();
        break;
      case 'booking':
        _navigateToBooking(netId: banner['net_id'], isNetBooking: true);
        break;
    }
  }

  // UPDATED ONLY THIS FUNCTION - FOR NET BOOKING FLOW
  void _navigateToBooking({int? netId, bool isNetBooking = false}) {
    int? dailyPackageId;

    // If it's a Net Booking flow, auto-find Daily Net package
    if (isNetBooking) {
      if (packages.isNotEmpty) {
        try {
          // Try to find Daily / Single Slot package
          final dailyPkg = packages.firstWhere(
            (p) =>
                p.name.toLowerCase().contains('daily') ||
                p.category.toLowerCase().contains('daily') ||
                p.category.toLowerCase().contains('net') ||
                p.category.toLowerCase() == 'individual',
            orElse: () => packages.first,
          );
          dailyPackageId = dailyPkg.id;
        } catch (_) {
          dailyPackageId = packages.first.id;
        }
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingScreen(
          preselectedNetId: netId,
          preselectedPackageId: dailyPackageId,
          isNetBooking: isNetBooking || netId != null,
        ),
      ),
    );
  }

  void _navigateToMyBookings() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
  );
  void _navigateToPackages() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const PackagesScreen()),
  );
  void _navigateToCoaching() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const CoachingScreen()),
  );
  void _navigateToLiveStream() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const LiveStreamScreen()),
  );
  void _navigateToProfile() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const ProfileScreen()),
  );
  void _navigateToMemberships() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const MyMembershipsScreen()),
  );

  @override
  void dispose() {
    _packageTimer?.cancel();
    _bannerTimer?.cancel();
    _featuresTimer?.cancel();
    _refreshTimer?.cancel();
    _packageController.dispose();
    _bannerController.dispose();
    _featuresController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: loading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryGreen),
              )
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 80),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppTheme.cardDark,
                            border: Border.all(color: const Color(0xFF2A2A2A)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: appImages['logo'] != null
                                    ? Image.network(
                                        appImages['logo']!,
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) => const Icon(
                                          Icons.sports_cricket,
                                          color: Color(0xFFFFD700),
                                          size: 32,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.sports_cricket,
                                        color: Color(0xFFFFD700),
                                        size: 32,
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'KHK CRICKET',
                                style: GoogleFonts.orbitron(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFFFD700),
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          height: 256,
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFF2A2A2A)),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: appImages['bg_image'] != null
                                    ? Image.network(
                                        appImages['bg_image']!,
                                        width: double.infinity,
                                        height: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) =>
                                            Container(color: Colors.black),
                                      )
                                    : Image.network(
                                        'https://images.unsplash.com/photo-1624526267942-ab0ff8a3e972?q=80&w=800',
                                        width: double.infinity,
                                        height: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.6),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.7],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      config['hero_title'],
                                      style: GoogleFonts.montserrat(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        height: 1.1,
                                      ),
                                    ),
                                    Text(
                                      config['hero_title_highlight'],
                                      style: GoogleFonts.montserrat(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w900,
                                        color: AppTheme.primaryGreen,
                                        height: 1.1,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      config['hero_subtitle'],
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: Colors.white,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ElevatedButton(
                                      onPressed: () => _navigateToBooking(
                                        isNetBooking: true,
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryGreen,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                        minimumSize: const Size(0, 0),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            config['hero_cta_text'],
                                            style: GoogleFonts.montserrat(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const Icon(
                                            Icons.chevron_right,
                                            size: 16,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_eventBanners.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            height: 120,
                            child: Stack(
                              children: [
                                PageView.builder(
                                  controller: _bannerController,
                                  onPageChanged: (i) =>
                                      setState(() => _currentBanner = i),
                                  itemCount: _eventBanners.length,
                                  itemBuilder: (context, index) {
                                    final banner = _eventBanners[index];
                                    return GestureDetector(
                                      onTap: () => _onBannerTap(banner),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          banner['image'],
                                          fit: BoxFit.cover,
                                          errorBuilder: (c, e, s) => Container(
                                            color: AppTheme.cardDark,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                if (_eventBanners.length > 1)
                                  Positioned(
                                    bottom: 8,
                                    left: 0,
                                    right: 0,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: List.generate(
                                        _eventBanners.length,
                                        (idx) => Container(
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 3,
                                          ),
                                          width: idx == _currentBanner ? 16 : 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: idx == _currentBanner
                                                ? Colors.white
                                                : Colors.white.withAlpha(128),
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GridView.count(
                          crossAxisCount: 4,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.75,
                          children: [
                            QuickAction(
                              icon: Icon(
                                Icons.sports_cricket,
                                color: AppTheme.primaryGreen,
                                size: 24,
                              ),
                              title: 'Net Booking',
                              subtitle: 'Book your',
                              onTap: () =>
                                  _navigateToBooking(isNetBooking: true),
                            ),
                            QuickAction(
                              icon: Icon(
                                Icons.sports,
                                color: Colors.orange,
                                size: 24,
                              ),
                              title: 'Coaching',
                              subtitle: 'Train with',
                              onTap: () => _navigateToCoaching(),
                            ),
                            QuickAction(
                              icon: Icon(
                                Icons.card_giftcard,
                                color: Colors.purple,
                                size: 24,
                              ),
                              title: 'Packages',
                              subtitle: 'View plans',
                              onTap: () => _navigateToPackages(),
                            ),
                            QuickAction(
                              icon: Icon(
                                Icons.live_tv,
                                color: Colors.blue,
                                size: 24,
                              ),
                              title: 'Live Stream',
                              subtitle: 'Watch Our Live',
                              onTap: () => _navigateToLiveStream(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'LIVE NET AVAILABILITY',
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            GestureDetector(
                              onTap: () =>
                                  _navigateToBooking(isNetBooking: true),
                              child: Row(
                                children: [
                                  Text(
                                    'View All',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryGreen,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    size: 14,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 170,
                        child: nets.isEmpty
                            ? Center(
                                child: Text(
                                  'Loading...',
                                  style: GoogleFonts.inter(
                                    color: AppTheme.textGrey,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                itemCount: nets.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (context, index) => NetCard(
                                  net: nets[index].toJson(),
                                  onBook: (id) => _navigateToBooking(
                                    netId: id,
                                    isNetBooking: true,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'POPULAR PACKAGES',
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _navigateToPackages(),
                              child: Row(
                                children: [
                                  Text(
                                    'View All',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryGreen,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    size: 14,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 240,
                        child: packages.isEmpty
                            ? Center(
                                child: Text(
                                  'Loading...',
                                  style: GoogleFonts.inter(
                                    color: AppTheme.textGrey,
                                  ),
                                ),
                              )
                            : PageView.builder(
                                controller: _packageController,
                                onPageChanged: (i) =>
                                    setState(() => currentPackageIndex = i),
                                itemCount: packages.length,
                                itemBuilder: (context, index) {
                                  final package = packages[index];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: GestureDetector(
                                      onTap: () => _navigateToPackages(),
                                      child: PackageCard(
                                        pkg: {
                                          'id': package.id,
                                          'name': package.name,
                                          'duration_hours':
                                              package.durationHours,
                                          'base_price': package.offPeakBhd,
                                          'peak_price': package.peakBhd,
                                          'image_url': package.imageUrl,
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      if (packages.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              packages.length,
                              (idx) => GestureDetector(
                                onTap: () {
                                  _packageController.animateToPage(
                                    idx,
                                    duration: const Duration(milliseconds: 400),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  height: 6,
                                  width: idx == currentPackageIndex ? 24 : 6,
                                  decoration: BoxDecoration(
                                    color: idx == currentPackageIndex
                                        ? AppTheme.primaryGreen
                                        : const Color(0xFF2A2A2A),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.cardDark,
                            border: Border.all(color: const Color(0xFF2A2A2A)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SingleChildScrollView(
                            controller: _featuresController,
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                ...features.map(
                                  (f) => _Feature(
                                    icon: f['icon'],
                                    title: f['title'],
                                    subtitle: f['subtitle'],
                                  ),
                                ),
                                const SizedBox(width: 24),
                                ...features.map(
                                  (f) => _Feature(
                                    icon: f['icon'],
                                    title: f['title'],
                                    subtitle: f['subtitle'],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.cardDark,
          border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _BottomTab(
                icon: Icons.home,
                label: 'Home',
                active: true,
                onTap: () {},
              ),
              _BottomTab(
                icon: Icons.card_membership_rounded,
                label: 'Membership',
                active: false,
                onTap: () => _navigateToMemberships(),
              ),
              _BottomTab(
                icon: Icons.calendar_today,
                label: 'Bookings',
                active: false,
                onTap: () => _navigateToMyBookings(),
              ),
              _BottomTab(
                icon: Icons.person,
                label: 'Profile',
                active: false,
                onTap: () => _navigateToProfile(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _Feature({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 24),
    child: Row(
      children: [
        Icon(icon, color: AppTheme.primaryGreen, size: 16),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textGrey),
            ),
          ],
        ),
      ],
    ),
  );
}

class _BottomTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _BottomTab({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.primaryGreen : AppTheme.textGrey;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
