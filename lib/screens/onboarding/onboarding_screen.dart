import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_theme.dart';
import '../../services/api_service.dart';
import '../home/home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  List<OnboardingData> _pages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOnboardingImages();
  }

  Future<void> _loadOnboardingImages() async {
    try {
      final settings = await ApiService.getAppSettings();

      setState(() {
        _pages = [
          OnboardingData(
            image:
                settings.onboardImage1 ??
                'https://images.unsplash.com/photo-1624526267942-ab0ff8a3e972?q=80&w=1920',
            title: 'Welcome to\nKHK Cricket',
            subtitle: 'Premium Indoor Cricket Nets\nBook Anytime, Anywhere',
          ),
          OnboardingData(
            image:
                settings.onboardImage2 ??
                'https://images.unsplash.com/photo-1531415074968-036ba1b575da?q=80&w=1920',
            title: 'Practice Like\nA Pro',
            subtitle: 'State-of-the-art bowling machines\nand AC indoor arena',
          ),
          OnboardingData(
            image:
                settings.onboardImage3 ??
                'https://images.unsplash.com/photo-1540747913346-19e32dc3e97e?q=80&w=1920',
            title: 'Play. Practice.\nPerform.',
            subtitle:
                'Join the elite cricket community\nStart your journey today',
          ),
        ];
        _loading = false;
      });
    } catch (e) {
      debugPrint('❌ Onboarding load error: $e');
      // Fallback to default images if API fails
      setState(() {
        _pages = [
          OnboardingData(
            image:
                'https://images.unsplash.com/photo-1624526267942-ab0ff8a3e972?q=80&w=1920',
            title: 'Welcome to\nKHK Cricket',
            subtitle: 'Premium Indoor Cricket Nets\nBook Anytime, Anywhere',
          ),
          OnboardingData(
            image:
                'https://images.unsplash.com/photo-1531415074968-036ba1b575da?q=80&w=1920',
            title: 'Practice Like\nA Pro',
            subtitle: 'State-of-the-art bowling machines\nand AC indoor arena',
          ),
          OnboardingData(
            image:
                'https://images.unsplash.com/photo-1540747913346-19e32dc3e97e?q=80&w=1920',
            title: 'Play. Practice.\nPerform.',
            subtitle:
                'Join the elite cricket community\nStart your journey today',
          ),
        ];
        _loading = false;
      });
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryGreen),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // PageView with images
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              final page = _pages[index];
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Full screen image - NO HEADERS for web
                  Image.network(
                    page.image,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: Colors.black,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stack) {
                      debugPrint('Onboarding image error: $error');
                      return Container(
                        color: Colors.black,
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: AppTheme.textGrey,
                            size: 64,
                          ),
                        ),
                      );
                    },
                  ),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.3),
                          Colors.black.withValues(alpha: 0.8),
                        ],
                        stops: const [0.0, 0.9],
                      ),
                    ),
                  ),
                  // Content
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            page.title,
                            style: GoogleFonts.montserrat(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            page.subtitle,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.9),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // Skip button
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _completeOnboarding,
                  child: Text(
                    'Skip',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bottom controls
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dots indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: _currentPage == index ? 24 : 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? AppTheme.primaryGreen
                                : Colors.white.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Next/Get Started button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentPage == _pages.length - 1
                                  ? 'GET STARTED'
                                  : 'NEXT',
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _currentPage == _pages.length - 1
                                  ? Icons.check_circle
                                  : Icons.arrow_forward,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingData {
  final String image;
  final String title;
  final String subtitle;

  OnboardingData({
    required this.image,
    required this.title,
    required this.subtitle,
  });
}
