import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import 'dart:convert';
import '../../config/app_theme.dart';
import '../../services/api_service.dart';
import '../home/home_screen.dart';

class OtpVerifyScreen extends StatefulWidget {
  final String phone;
  final String countryCode;
  final String? name;
  final bool isLogin;
  final bool isWhatsApp;

  const OtpVerifyScreen({
    super.key,
    required this.phone,
    required this.countryCode,
    this.name,
    required this.isLogin,
    this.isWhatsApp = false,
  });

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen>
    with TickerProviderStateMixin {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  int _resendTimer = 60;

  late AnimationController _bgController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _startResendTimer();

    _bgController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
        );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _fadeController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _resendTimer > 0) {
        setState(() => _resendTimer--);
        _startResendTimer();
      }
    });
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.length != 6) {
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    try {
      Map<String, dynamic> response;

      if (widget.isLogin) {
        response = await ApiService.verifyLogin(
          countryCode: widget.countryCode,
          mobile: widget.phone,
          otp: _otpController.text,
        );
      } else {
        response = await ApiService.post('/register/verify', {
          'country_code': widget.countryCode,
          'mobile': widget.phone,
          'otp': _otpController.text,
        });
      }

      // Save token and user data
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', response['token']);
      await prefs.setString('user_data', json.encode(response['user']));

      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.black),
                const SizedBox(width: 12),
                Text(
                  widget.isLogin
                      ? 'Login successful!'
                      : 'Registration successful!',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: AppTheme.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(milliseconds: 800),
          ),
        );

        await Future.delayed(const Duration(milliseconds: 800));

        // Navigate to HomeScreen and clear all previous routes
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      _showError('Invalid or expired OTP. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    try {
      await ApiService.post('/resend-otp', {
        'country_code': widget.countryCode,
        'mobile': widget.phone,
        'type': widget.isLogin ? 'login' : 'register',
      });

      setState(() => _resendTimer = 60);
      _startResendTimer();
      _showSuccess('OTP sent to WhatsApp');
    } catch (e) {
      _showError('Failed to resend OTP');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: Colors.red.shade900,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccess(String msg) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.black),
            const SizedBox(width: 12),
            Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: AppTheme.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 64,
      textStyle: GoogleFonts.montserrat(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: AppTheme.primaryGreen, width: 2),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: -2,
          ),
        ],
      ),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.1),
        border: Border.all(color: AppTheme.primaryGreen, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Color.lerp(
                        const Color(0xFF0A0A0A),
                        const Color(0xFF1A1A2E),
                        (_bgController.value * 2) % 1.0,
                      )!,
                      Color.lerp(
                        const Color(0xFF0F0F0F),
                        const Color(0xFF16213E),
                        (_bgController.value * 2 + 0.5) % 1.0,
                      )!,
                    ],
                  ),
                ),
              );
            },
          ),

          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
            child: Container(color: Colors.black.withValues(alpha: 0.3)),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(
                              0xFF25D366,
                            ).withValues(alpha: 0.1),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF25D366,
                                ).withValues(alpha: 0.3),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.chat_bubble_outline,
                            color: Color(0xFF25D366),
                            size: 48,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [Colors.white, AppTheme.primaryGreen],
                        ).createShader(bounds),
                        child: Text(
                          'Verify OTP',
                          style: GoogleFonts.montserrat(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Enter the 6-digit code sent to',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: AppTheme.textGrey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline,
                            color: Color(0xFF25D366),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${widget.countryCode} ${widget.phone}',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Column(
                              children: [
                                Pinput(
                                  controller: _otpController,
                                  length: 6,
                                  defaultPinTheme: defaultPinTheme,
                                  focusedPinTheme: focusedPinTheme,
                                  submittedPinTheme: submittedPinTheme,
                                  onCompleted: (pin) => _verifyOtp(),
                                  hapticFeedbackType:
                                      HapticFeedbackType.lightImpact,
                                  cursor: Container(
                                    width: 2,
                                    height: 30,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ),
                                const SizedBox(height: 32),

                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryGreen.withValues(
                                          alpha: 0.4,
                                        ),
                                        blurRadius: 20,
                                        spreadRadius: -5,
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _verifyOtp,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryGreen,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 18,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      disabledBackgroundColor: AppTheme
                                          .primaryGreen
                                          .withValues(alpha: 0.5),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: CircularProgressIndicator(
                                              color: Colors.black,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : Text(
                                            'VERIFY OTP',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      Center(
                        child: TextButton(
                          onPressed: _resendTimer == 0 && !_isLoading
                              ? _resendOtp
                              : null,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.refresh,
                                size: 18,
                                color: _resendTimer > 0
                                    ? AppTheme.textGrey
                                    : AppTheme.primaryGreen,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _resendTimer > 0
                                    ? 'Resend OTP in ${_resendTimer}s'
                                    : 'Resend OTP',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: _resendTimer > 0
                                      ? AppTheme.textGrey
                                      : AppTheme.primaryGreen,
                                  fontWeight: FontWeight.w600,
                                ),
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
          ),
        ],
      ),
    );
  }
}
