import 'package:flutter/material.dart';
import '../services/api_service.dart';

class GlobalBackground extends StatefulWidget {
  final Widget child;
  const GlobalBackground({super.key, required this.child});

  @override
  State<GlobalBackground> createState() => _GlobalBackgroundState();
}

class _GlobalBackgroundState extends State<GlobalBackground> {
  String? bgImage;

  static const Map<String, String> _imageHeaders = {
    'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
    'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
    'Referer': 'https://khkcricket.bh/',
  };

  @override
  void initState() {
    super.initState();
    _loadBgImage();
  }

  Future<void> _loadBgImage() async {
    try {
      final config = await ApiService.getAppConfig();
      if (mounted) setState(() => bgImage = config['bg_image']);
    } catch (e) {
      debugPrint('BG image load error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background image
        if (bgImage != null)
          Positioned.fill(
            child: Image.network(
              bgImage!,
              headers: _imageHeaders,
              fit: BoxFit.cover,
            ),
          ),

        // Dark overlay
        if (bgImage != null)
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.75)),
          ),

        // Your app content
        widget.child,
      ],
    );
  }
}
