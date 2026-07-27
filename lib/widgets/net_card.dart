import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_theme.dart';

class NetCard extends StatelessWidget {
  final Map<String, dynamic> net;
  final Function(int) onBook;

  const NetCard({super.key, required this.net, required this.onBook});

  @override
  Widget build(BuildContext context) {
    final isAvailable = net['status'] == 'available';

    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        border: Border.all(color: const Color(0xFF2A2A2A)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                net['name'] ?? 'Net',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isAvailable
                      ? AppTheme.primaryGreen.withValues(alpha: 0.2)
                      : Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isAvailable ? AppTheme.primaryGreen : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isAvailable ? 'AVAILABLE' : 'BUSY',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isAvailable ? AppTheme.primaryGreen : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Pitch icon
          SizedBox(
            height: 36,
            child: CustomPaint(
              painter: PitchPainter(
                color: isAvailable ? AppTheme.primaryGreen : Colors.red,
              ),
              size: const Size(double.infinity, 36),
            ),
          ),
          const SizedBox(height: 12),
          if (isAvailable)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => onBook(net['id']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  minimumSize: const Size(0, 0),
                  textStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                child: const Text('BOOK NOW'),
              ),
            )
          else
            Column(
              children: [
                Text(
                  'Next Slot',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppTheme.textGrey,
                  ),
                ),
                Text(
                  net['next_slot'] ?? 'N/A',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class PitchPainter extends CustomPainter {
  final Color color;
  PitchPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;

    // Outer rectangle
    canvas.drawRect(Rect.fromLTWH(w * 0.17, 4, w * 0.66, h - 8), paint);
    // Inner rectangle
    canvas.drawRect(Rect.fromLTWH(w * 0.32, 12, w * 0.36, h - 24), paint);
    // Lines
    canvas.drawLine(Offset(w * 0.43, 4), Offset(w * 0.43, h - 4), paint);
    canvas.drawLine(Offset(w * 0.57, 4), Offset(w * 0.57, h - 4), paint);
    // Circle
    canvas.drawCircle(Offset(w * 0.5, h / 2), 2.5, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
