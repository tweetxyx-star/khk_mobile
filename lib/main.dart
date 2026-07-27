import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/app_theme.dart';
import 'screens/home/home_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init Stripe but don't block app startup
  if (!kIsWeb) {
    Stripe.publishableKey =
        'pk_test_51TeZmpICBdoab2J356jwmPxeen9kS2Q1sVCe1k9Gkvtne3splOAEpDOFekjByxAnsIR4j9Lr6WjuhJmXJfPwL1j100s8zdds1d';

    // Fire and forget with timeout - won't hang app if network fails
    Stripe.instance
        .applySettings()
        .timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            debugPrint('Stripe init timed out - app will continue');
          },
        )
        .catchError((e) {
          debugPrint('Stripe init error: $e');
        });
  }

  // Check if onboarding is complete
  final prefs = await SharedPreferences.getInstance();
  final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

  runApp(KHKApp(showOnboarding: !onboardingComplete));
}

class KHKApp extends StatelessWidget {
  final bool showOnboarding;

  const KHKApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KHK Cricket',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: showOnboarding ? const OnboardingScreen() : const HomeScreen(),
    );
  }
}
