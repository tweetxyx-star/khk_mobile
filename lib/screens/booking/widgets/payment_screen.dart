import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import '../../../config/app_theme.dart';
import '../../../services/api_service.dart';
import '../../../models/net.dart';
import '../../../models/package.dart';

class PaymentScreen extends StatefulWidget {
  final String? bookingId;
  final Net? net;
  final Package package;
  final DateTime selectedDate;
  final String selectedStartTime;
  final String selectedEndTime;
  final int selectedDuration;
  final double totalPrice;
  final List<int> facilityIds;
  final int? coachId;
  final int? rescheduleBookingId;
  final bool isFullFacility;
  final VoidCallback onClose;
  final VoidCallback onSuccess;

  // ===== NEW: MEMBERSHIP MODE =====
  final bool isMembershipPurchase;
  final int? membershipPackageId;
  final int? userPackageId; // for confirm payment after purchase

  const PaymentScreen({
    super.key,
    this.bookingId,
    this.net,
    required this.package,
    required this.selectedDate,
    required this.selectedStartTime,
    required this.selectedEndTime,
    required this.selectedDuration,
    required this.totalPrice,
    required this.facilityIds,
    this.coachId,
    this.rescheduleBookingId,
    this.isFullFacility = false,
    required this.onClose,
    required this.onSuccess,
    // membership
    this.isMembershipPurchase = false,
    this.membershipPackageId,
    this.userPackageId,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _ibanNumber = 'BH00ABCD12345678901234';
  String _benefitQrUrl = '${ApiService.baseUrl}/assets/QR-KHK.jpg';
  XFile? _receiptXFile;
  Uint8List? _receiptBytes;
  final ImagePicker _picker = ImagePicker();
  bool _isMarkingPaid = false;

  @override
  void initState() {
    super.initState();
    _loadPaymentSettings();
  }

  Future<void> _loadPaymentSettings() async {
    try {
      final response = await ApiService.get('/payment-settings');
      if (mounted) {
        setState(() {
          _ibanNumber = response['iban'] ?? 'BH00ABCD12345678901234';
          _benefitQrUrl =
              response['benefit_qr_url'] ??
              '${ApiService.baseUrl}/assets/QR-KHK.jpg';
        });
      }
    } catch (e) {
      debugPrint('Failed to load payment settings: $e');
    }
  }

  Future<void> _pickReceipt() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _receiptXFile = image;
          _receiptBytes = bytes;
        });
      }
    } catch (e) {
      _showError('Failed to pick image: ${e.toString()}');
    }
  }

  Future<void> _markPaymentDone() async {
    if (_receiptXFile == null || _receiptBytes == null) {
      _showError('Please upload payment receipt');
      return;
    }

    setState(() => _isMarkingPaid = true);
    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) {
        _showError('Session expired. Please login again.');
        setState(() => _isMarkingPaid = false);
        return;
      }

      // ===== MEMBERSHIP PURCHASE FLOW =====
      if (widget.isMembershipPurchase) {
        final pkgId = widget.membershipPackageId ?? widget.package.id;
        // 1. purchase / get user_package id
        int upId = widget.userPackageId ?? 0;
        if (upId == 0) {
          final purchaseRes = await ApiService.purchaseMembership(pkgId);
          upId = purchaseRes['data']?['id'] ?? purchaseRes['id'] ?? 0;
          if (upId == 0) throw Exception('Failed to create membership order');
        }

        // 2. upload receipt to user_package
        var uploadReq = http.MultipartRequest(
          'POST',
          Uri.parse('${ApiService.baseUrl}/user-packages/$upId/upload-receipt'),
        );
        uploadReq.headers['Authorization'] = 'Bearer $token';
        uploadReq.headers['Accept'] = 'application/json';
        uploadReq.files.add(
          http.MultipartFile.fromBytes(
            'receipt',
            _receiptBytes!,
            filename: _receiptXFile!.name,
            contentType: MediaType('image', 'jpeg'),
          ),
        );
        var upStream = await uploadReq.send();
        var upResp = await http.Response.fromStream(upStream);

        if (upResp.statusCode == 200 || upResp.statusCode == 201) {
          // 3. confirm payment -> activates membership
          try {
            await ApiService.confirmMembershipPayment(upId);
          } catch (_) {
            // even if confirm fails, upload sets status to pending, admin can approve
          }
          if (mounted) {
            _showSuccess(
              'Membership payment uploaded! Admin will verify and activate.',
            );
            await Future.delayed(const Duration(seconds: 1));
            widget.onSuccess();
          }
        } else {
          final err = jsonDecode(upResp.body);
          _showError(
            err['message'] ?? 'Receipt upload failed (${upResp.statusCode})',
          );
        }
        return;
      }

      // ===== EXISTING NET / FACILITY BOOKING FLOW (UNCHANGED) =====
      final isReschedule = widget.rescheduleBookingId != null;
      final endpoint = isReschedule
          ? '/bookings/${widget.rescheduleBookingId}/reschedule'
          : '/bookings';

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.baseUrl}$endpoint'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      request.fields['net_id'] = widget.isFullFacility
          ? ''
          : (widget.net?.id.toString() ?? '');
      request.fields['package_id'] = widget.package.id.toString();
      request.fields['date'] = DateFormat(
        'yyyy-MM-dd',
      ).format(widget.selectedDate);
      request.fields['start_time'] = widget.selectedStartTime;
      request.fields['end_time'] = widget.selectedEndTime;
      request.fields['duration_hours'] = (widget.selectedDuration * 0.5)
          .toString();
      request.fields['is_full_facility'] = widget.isFullFacility ? '1' : '0';

      if (widget.facilityIds.isNotEmpty) {
        for (var i = 0; i < widget.facilityIds.length; i++) {
          request.fields['facility_ids[$i]'] = widget.facilityIds[i].toString();
        }
      }
      if (widget.coachId != null) {
        request.fields['coach_id'] = widget.coachId.toString();
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'receipt',
          _receiptBytes!,
          filename: _receiptXFile!.name,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          _showSuccess(
            isReschedule
                ? 'Booking rescheduled! Awaiting admin confirmation.'
                : 'Booking created! Awaiting admin confirmation.',
          );
          await Future.delayed(const Duration(seconds: 1));
          widget.onSuccess();
        }
      } else if (response.statusCode == 401) {
        _showError('Session expired. Please login again.');
      } else if (response.statusCode == 409) {
        final error = jsonDecode(response.body);
        _showError(error['error'] ?? 'This time slot is already booked');
      } else if (response.statusCode == 422) {
        final error = jsonDecode(response.body);
        _showError(
          error['message'] ?? error['error'] ?? 'Invalid booking data',
        );
      } else {
        _showError('Booking failed (${response.statusCode})');
      }
    } catch (e) {
      _showError('Failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isMarkingPaid = false);
    }
  }

  void _copyIban() {
    Clipboard.setData(ClipboardData(text: _ibanNumber));
    _showSuccess('IBAN copied to clipboard');
  }

  Future<void> _openBenefitQr() async {
    final uri = Uri.parse(_benefitQrUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showError('Could not open QR code');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hours = (widget.selectedDuration * 0.5);
    final hoursDisplay = hours.toStringAsFixed(
      hours.truncateToDouble() == hours ? 0 : 1,
    );
    final isMembership = widget.isMembershipPurchase;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: widget.onClose,
        ),
        title: Text(
          isMembership
              ? 'Membership Payment'
              : (widget.rescheduleBookingId != null
                    ? 'Reschedule Payment'
                    : 'Complete Payment'),
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isMembership
                          ? 'Upload your payment receipt to activate membership. Admin will verify payment before activation.'
                          : (widget.rescheduleBookingId != null
                                ? 'Upload your payment receipt to reschedule booking. Admin will verify payment before confirming your new slot.'
                                : 'Upload your payment receipt to create booking. Admin will verify payment before confirming your slot.'),
                      style: GoogleFonts.inter(
                        color: Colors.orange,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Booking Summary',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardDark.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                children: [
                  _buildSummaryRow('Booking Type', widget.package.name),
                  if (!isMembership && widget.net != null)
                    _buildSummaryRow('Net', widget.net!.name)
                  else if (widget.isFullFacility)
                    _buildSummaryRow('Facility', 'Full Facility (All Nets)')
                  else if (isMembership)
                    _buildSummaryRow(
                      'Package Type',
                      widget.package.category.isNotEmpty
                          ? widget.package.category
                          : 'Membership',
                    ),
                  _buildSummaryRow(
                    'Date',
                    DateFormat('EEE, MMM d, yyyy').format(widget.selectedDate),
                  ),
                  if (!isMembership)
                    _buildSummaryRow(
                      'Time',
                      '${widget.selectedStartTime} - ${widget.selectedEndTime}',
                    ),
                  if (!isMembership)
                    _buildSummaryRow(
                      'Duration',
                      '$hoursDisplay hour${hours > 1 ? 's' : ''}',
                    ),
                  if (isMembership)
                    _buildSummaryRow(
                      'Valid For',
                      '${widget.package.validDays ?? widget.package.membershipDurationDays ?? 30} days',
                    ),
                  const Divider(color: Colors.white12),
                  _buildSummaryRow(
                    'Total Amount',
                    'BHD ${widget.totalPrice.toStringAsFixed(3)}',
                    isBold: true,
                    color: AppTheme.primaryGreen,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Payment Details',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardDark.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bank Transfer (IBAN)',
                    style: GoogleFonts.inter(
                      color: AppTheme.textGrey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _ibanNumber,
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _copyIban,
                        icon: Icon(Icons.copy, color: AppTheme.primaryGreen),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 16),
                  Text(
                    'Benefit Pay QR Code',
                    style: GoogleFonts.inter(
                      color: AppTheme.textGrey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: GestureDetector(
                      onTap: _openBenefitQr,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: _benefitQrUrl,
                            height: 200,
                            width: 200,
                            fit: BoxFit.contain,
                            placeholder: (context, url) => Container(
                              height: 200,
                              width: 200,
                              color: Colors.white,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              height: 200,
                              width: 200,
                              color: Colors.white,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.qr_code_2,
                                    size: 80,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'QR unavailable',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Tap to enlarge',
                      style: GoogleFonts.inter(
                        color: AppTheme.textGrey,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_receiptXFile != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Receipt: ${_receiptXFile!.name}',
                        style: GoogleFonts.inter(
                          color: Colors.green,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.red,
                        size: 20,
                      ),
                      onPressed: () => setState(() {
                        _receiptXFile = null;
                        _receiptBytes = null;
                      }),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pickReceipt,
                icon: Icon(Icons.upload_file, color: AppTheme.primaryGreen),
                label: Text(
                  _receiptXFile == null ? 'UPLOAD RECEIPT' : 'CHANGE RECEIPT',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w900),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryGreen,
                  side: BorderSide(color: AppTheme.primaryGreen),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isMarkingPaid || _receiptXFile == null)
                    ? null
                    : _markPaymentDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey.shade800,
                ),
                child: _isMarkingPaid
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'PAYMENT DONE',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isMembership
                  ? 'Upload receipt and click Payment Done. Your membership will be sent for admin verification.'
                  : (widget.rescheduleBookingId != null
                        ? 'Upload payment receipt and click "Payment Done". Your booking will be rescheduled and sent for admin verification.'
                        : 'Upload payment receipt and click "Payment Done". Your booking will be created and sent for admin verification.'),
              style: GoogleFonts.inter(color: AppTheme.textGrey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(color: AppTheme.textGrey, fontSize: 14),
          ),
          Text(
            value,
            style: GoogleFonts.montserrat(
              color: color ?? Colors.white,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
              fontSize: isBold ? 20 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
