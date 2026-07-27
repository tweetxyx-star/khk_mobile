import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/app_theme.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _bookings = [];
  bool _isLoading = true;
  bool _isLoggedIn = false;
  bool _isProcessing = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkLoginAndLoad();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkLoginAndLoad() async {
    setState(() => _isLoading = true);
    final loggedIn = await ApiService.isLoggedIn();
    setState(() => _isLoggedIn = loggedIn);

    if (loggedIn) {
      await _loadBookings();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    try {
      final bookings = await ApiService.get('/user/bookings');
      setState(() {
        _bookings = List<Map<String, dynamic>>.from(bookings);
        _isLoading = false;
      });
    } catch (e) {
      _showError('Failed to load bookings: ${e.toString()}');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateToLogin() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (result == true) {
      _checkLoginAndLoad();
    }
  }

  bool _isUpcoming(Map<String, dynamic> booking) {
    try {
      if (booking['status'] != 'confirmed') return false;

      final dateStr = booking['date'] as String?;
      if (dateStr == null || dateStr.isEmpty) return false;

      final date = DateFormat('yyyy-MM-dd').parse(dateStr);
      final time = booking['start_time'] as String;
      final timeParts = time.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      var bookingDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        hour,
        minute,
      );
      if (hour < 7) {
        bookingDateTime = bookingDateTime.add(const Duration(days: 1));
      }
      return bookingDateTime.isAfter(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  bool _canReschedule(Map<String, dynamic> booking) {
    if (booking['status'] != 'confirmed') return false;
    if (!_isUpcoming(booking)) return false;
    return true;
  }

  bool _canCancel(Map<String, dynamic> booking) {
    if (booking['status'] != 'confirmed') return false;
    if (!_isUpcoming(booking)) return false;
    return true;
  }

  Future<void> _cancelBooking(Map<String, dynamic> booking) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: Text(
          'Request Cancellation?',
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your cancellation request will be sent to admin.',
              style: GoogleFonts.inter(color: AppTheme.textGrey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Admin will review your booking and process refund manually. You will be contacted shortly.',
                      style: GoogleFonts.inter(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'No',
              style: GoogleFonts.montserrat(color: AppTheme.textGrey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              'Yes, Send Request',
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      await ApiService.post('/bookings/${booking['id']}/cancel', {});
      _showSuccess(
        'Cancellation request sent. Admin will contact you shortly.',
      );
      _loadBookings();
    } catch (e) {
      _showError('Failed to send request: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _rescheduleBooking(Map<String, dynamic> booking) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: Text(
          'Request Reschedule?',
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your reschedule request will be sent to admin.',
              style: GoogleFonts.inter(color: AppTheme.textGrey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Admin will contact you to arrange a new time slot. Your current booking remains confirmed until changed.',
                      style: GoogleFonts.inter(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'No',
              style: GoogleFonts.montserrat(color: AppTheme.textGrey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
            ),
            child: Text(
              'Yes, Send Request',
              style: GoogleFonts.montserrat(
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      await ApiService.post('/bookings/${booking['id']}/reschedule', {});
      _showSuccess('Reschedule request sent. Admin will contact you shortly.');
      _loadBookings();
    } catch (e) {
      _showError('Failed to send request: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.primaryGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_isLoggedIn && !_isLoading) _buildTabBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Text(
            'My Bookings',
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          if (_isLoggedIn)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadBookings,
            ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppTheme.primaryGreen,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.black,
        unselectedLabelColor: Colors.white54,
        labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        tabs: const [
          Tab(text: 'Upcoming'),
          Tab(text: 'Completed'),
          Tab(text: 'Cancelled'),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.primaryGreen),
      );
    }

    if (!_isLoggedIn) {
      return _buildLoginPrompt();
    }

    if (_bookings.isEmpty) {
      return _buildEmptyState();
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildBookingsList(_getUpcomingBookings()),
        _buildBookingsList(_getCompletedBookings()),
        _buildBookingsList(_getCancelledBookings()),
      ],
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 80, color: AppTheme.primaryGreen),
            const SizedBox(height: 24),
            Text(
              'Login Required',
              style: GoogleFonts.montserrat(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Please login to view your bookings',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppTheme.textGrey, fontSize: 16),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _navigateToLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'LOGIN',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 80, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            'No Bookings Yet',
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Book your first session now',
            style: GoogleFonts.inter(color: AppTheme.textGrey),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getUpcomingBookings() {
    return _bookings
        .where((b) => b['status'] == 'confirmed' && _isUpcoming(b))
        .toList();
  }

  List<Map<String, dynamic>> _getCompletedBookings() {
    return _bookings
        .where((b) => b['status'] == 'confirmed' && !_isUpcoming(b))
        .toList();
  }

  List<Map<String, dynamic>> _getCancelledBookings() {
    return _bookings.where((b) => b['status'] == 'cancelled').toList();
  }

  Widget _buildBookingsList(List<Map<String, dynamic>> bookings) {
    if (bookings.isEmpty) {
      return Center(
        child: Text(
          'No bookings in this category',
          style: GoogleFonts.inter(color: AppTheme.textGrey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, index) => _buildBookingCard(bookings[index]),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final isUpcoming = _isUpcoming(booking);
    final canReschedule = _canReschedule(booking);
    final canCancel = _canCancel(booking);
    final isCancelled = booking['status'] == 'cancelled';
    final isPending = booking['status'] == 'payment_verification_pending';
    final isConfirmed = booking['status'] == 'confirmed';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardDark.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCancelled
              ? Colors.red.withValues(alpha: 0.5)
              : isPending
              ? Colors.orange.withValues(alpha: 0.5)
              : Colors.white24,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.sports_cricket,
                  color: AppTheme.primaryGreen,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking['net_name'] ??
                          'Net ${booking['net_id'] ?? 'N/A'}',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _formatBookingDate(booking['date']),
                      style: GoogleFonts.inter(
                        color: AppTheme.textGrey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(booking),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
          if (booking['rate_card_name'] != null)
            _buildDetailRow(Icons.category, 'Type', booking['rate_card_name']),
          _buildDetailRow(
            Icons.access_time,
            'Time',
            '${booking['start_time']} - ${booking['end_time']}',
          ),
          _buildDetailRow(
            Icons.timer,
            'Duration',
            '${_getDurationHours(booking)} hour(s)',
          ),
          _buildDetailRow(
            Icons.payments,
            'Amount',
            'BHD ${double.parse(booking['total_price'].toString()).toStringAsFixed(3)}',
          ),
          if (booking['coach_name'] != null)
            _buildDetailRow(Icons.person, 'Coach', booking['coach_name']),

          if (isPending) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.pending, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Payment verification pending. You will be notified once admin confirms.',
                      style: GoogleFonts.inter(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isConfirmed && isUpcoming && !isCancelled) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (canReschedule)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isProcessing
                          ? null
                          : () => _rescheduleBooking(booking),
                      icon: const Icon(Icons.edit_calendar, size: 18),
                      label: const Text('Request Reschedule'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                if (canReschedule && canCancel) const SizedBox(width: 12),
                if (canCancel)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing
                          ? null
                          : () => _cancelBooking(booking),
                      icon: const Icon(Icons.cancel, size: 18),
                      label: const Text('Request Cancel'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.withValues(alpha: 0.2),
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatBookingDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Unknown date';
    try {
      final date = DateFormat('yyyy-MM-dd').parse(dateStr);
      return DateFormat('EEE, MMM d, yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _getDurationHours(Map<String, dynamic> booking) {
    try {
      final startParts = (booking['start_time'] as String).split(':');
      final endParts = (booking['end_time'] as String).split(':');
      final startHour = int.parse(startParts[0]);
      final startMin = int.parse(startParts[1]);
      final endHour = int.parse(endParts[0]);
      final endMin = int.parse(endParts[1]);

      var startMins = startHour * 60 + startMin;
      var endMins = endHour * 60 + endMin;

      if (endMins <= startMins) {
        endMins += 24 * 60;
      }

      final durationMins = endMins - startMins;
      final hours = durationMins / 60;
      return hours.toStringAsFixed(hours % 1 == 0 ? 0 : 1);
    } catch (e) {
      return booking['duration']?.toString() ?? '1';
    }
  }

  Widget _buildStatusBadge(Map<String, dynamic> booking) {
    String text;
    Color color;

    if (booking['status'] == 'cancelled') {
      text = 'CANCELLED';
      color = Colors.red;
    } else if (booking['status'] == 'payment_verification_pending') {
      text = 'PAYMENT PENDING';
      color = Colors.orange;
    } else if (_isUpcoming(booking)) {
      text = 'CONFIRMED';
      color = AppTheme.primaryGreen;
    } else {
      text = 'COMPLETED';
      color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: GoogleFonts.montserrat(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textGrey),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(color: AppTheme.textGrey, fontSize: 14),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
