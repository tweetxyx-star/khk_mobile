import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/net.dart';
import '../models/package.dart';
import '../models/facility.dart';
import '../models/coach.dart';
import '../models/app_setting.dart';

class ApiService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'https://khkcricket.bh/api';
    }
    return 'https://khkcricket.bh/api';
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(tokenKey);
    if (kDebugMode) {
      debugPrint(
        '🔑 [ApiService] _getToken() → ${token != null ? "${token.substring(0, 20)}..." : "NULL"}',
      );
    }
    return token;
  }

  static Future<bool> isLoggedIn() async {
    final token = await _getToken();
    final loggedIn = token != null && token.isNotEmpty;
    if (kDebugMode) debugPrint('🔒 [ApiService] isLoggedIn() → $loggedIn');
    return loggedIn;
  }

  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, token);
    if (kDebugMode) debugPrint('✅ [ApiService] _saveToken() → Token saved');
  }

  static Future<void> _saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(userKey, jsonEncode(user));
    if (kDebugMode)
      debugPrint(
        '✅ [ApiService] _saveUser() → ${user['name']} (ID: ${user['id']})',
      );
  }

  static Future<Map<String, dynamic>?> getCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(userKey);
    return userJson != null ? jsonDecode(userJson) : null;
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
    await prefs.remove(userKey);
    if (kDebugMode) debugPrint('🗑 [ApiService] clearToken() → Cleared');
  }

  static Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'KHKCricket/1.0 Mobile',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    if (kDebugMode)
      debugPrint(
        '📋 [ApiService] Headers → ${token != null ? "Bearer AUTH" : "NO AUTH"}',
      );
    return headers;
  }

  static Future<dynamic> get(String endpoint) async {
    try {
      final headers = await _headers();
      final url = '$baseUrl$endpoint';
      if (kDebugMode) debugPrint('⬆ [ApiService] GET: $url');
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 15));
      if (kDebugMode) {
        debugPrint('⬇ [ApiService] Response ${response.statusCode}');
        if (response.body.length < 3000) {
          debugPrint('⬇ [ApiService] Body: ${response.body}');
        } else {
          debugPrint(
            '⬇ [ApiService] Body (first 3000): ${response.body.substring(0, 3000)}',
          );
        }
      }
      return _handleResponse(response, endpoint);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [ApiService] Network error: $e');
      throw Exception('Network error: ${e.toString()}');
    }
  }

  static Future<dynamic> post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    try {
      final headers = await _headers();
      final url = '$baseUrl$endpoint';
      if (kDebugMode) {
        debugPrint('⬆ [ApiService] POST: $url');
        debugPrint('📦 [ApiService] Body: ${jsonEncode(data)}');
      }
      final response = await http
          .post(Uri.parse(url), headers: headers, body: jsonEncode(data))
          .timeout(const Duration(seconds: 15));
      if (kDebugMode) {
        debugPrint('⬇ [ApiService] Response ${response.statusCode}');
        debugPrint('⬇ [ApiService] Body: ${response.body}');
      }
      return _handleResponse(response, endpoint);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [ApiService] Network error: $e');
      throw Exception('Network error: ${e.toString()}');
    }
  }

  static dynamic _handleResponse(http.Response response, String endpoint) {
    final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    if (response.statusCode == 401) {
      if (endpoint == '/user' ||
          endpoint == '/login' ||
          endpoint == '/verify-login') {
        clearToken();
      }
      if (kDebugMode) debugPrint('⚠ 401 on $endpoint -> ${response.body}');
      throw Exception('Session expired on $endpoint. Please login again.');
    } else if (response.statusCode == 403) {
      final error = body['error'] ?? body['message'] ?? 'Forbidden';
      throw Exception(error);
    } else if (response.statusCode == 422) {
      final errors =
          body['errors'] ??
          body['message'] ??
          body['error'] ??
          'Validation failed';
      throw Exception(errors.toString());
    } else {
      final error =
          body['error'] ?? body['message'] ?? 'Error ${response.statusCode}';
      throw Exception('$error (endpoint: $endpoint)');
    }
  }

  static Future<Map<String, dynamic>> getAppConfig() async {
    try {
      final data = await get('/app-config');
      return data as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }

  static Future<AppSetting> getAppSettings() async {
    final data = await get('/app-config');
    return AppSetting.fromJson(data as Map<String, dynamic>);
  }

  static Future<List<Net>> getNets() async {
    final data = await get('/nets');
    return (data as List).map((e) => Net.fromJson(e)).toList();
  }

  static Future<List<Package>> getPackages() async {
    if (kDebugMode) debugPrint('🎫 [ApiService] getPackages() → Fetching');
    final data = await get('/packages');
    final packages = (data as List).map((e) => Package.fromJson(e)).toList();
    if (kDebugMode)
      debugPrint('✅ [ApiService] getPackages() → ${packages.length} packages');
    return packages;
  }

  static Future<List<dynamic>> getPackagesRaw() async {
    try {
      final data = await get('/packages');
      if (data is List) return data;
      if (data is Map && data['data'] is List) return data['data'] as List;
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<Package>> getBookingTypes() async {
    final data = await get('/booking-types');
    final List<Package> allTypes = [];
    for (var categoryGroup in data as List) {
      final types = categoryGroup['types'] as List;
      for (var type in types) {
        allTypes.add(Package.fromJson(type));
      }
    }
    return allTypes;
  }

  static Future<List<Package>> getAllPackages() async {
    final data = await get('/packages');
    return (data as List).map((e) => Package.fromJson(e)).toList();
  }

  static Future<List<Package>> getEventRates() async {
    final data = await get('/packages');
    return (data as List)
        .map((e) => Package.fromJson(e))
        .where((p) => p.category == 'event')
        .toList();
  }

  static Future<List<Package>> getCoachingRates() async {
    final data = await get('/packages');
    return (data as List)
        .map((e) => Package.fromJson(e))
        .where((p) => p.category == 'coaching')
        .toList();
  }

  static Future<List<Facility>> getFacilities() async {
    final data = await get('/facilities');
    return (data as List).map((e) => Facility.fromJson(e)).toList();
  }

  static Future<List<Coach>> getCoaches() async {
    final data = await get('/coaches/available');
    return (data as List).map((e) => Coach.fromJson(e)).toList();
  }

  static Future<List<Coach>> getAvailableCoaches({
    required String date,
    required String startTime,
    required String endTime,
  }) async {
    final data = await get(
      '/coaches/available?date=$date&start_time=$startTime&end_time=$endTime',
    );
    return (data as List).map((e) => Coach.fromJson(e)).toList();
  }

  static Future<List<dynamic>> getRates() async {
    final data = await get('/rates');
    return data as List;
  }

  static Future<List<dynamic>> getGccCountries() async {
    final data = await get('/gcc-countries');
    return data as List;
  }

  static Future<Map<String, dynamic>> getAvailability({
    required String date,
    required String start,
    required String end,
  }) async {
    return await get('/availability?date=$date&start=$start&end=$end')
        as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getNetAvailability({
    required String date,
    required int netId,
    required int packageId,
  }) async {
    return await get(
          '/net-availability?date=$date&net_id=$netId&package_id=$packageId',
        )
        as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getTimeSlots({
    required int netId,
    required String date,
    required int packageId,
  }) async {
    return await get(
          '/time-slots?net_id=$netId&date=$date&package_id=$packageId',
        )
        as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getMembershipAvailability({
    required String date,
    required int userPackageId,
    int? netId,
  }) async {
    final qp = StringBuffer(
      '/membership-availability?date=$date&user_package_id=$userPackageId',
    );
    if (netId != null) qp.write('&net_id=$netId');
    return await get(qp.toString()) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getMembershipSlots({
    required String date,
    required int userPackageId,
    int? netId,
  }) async {
    return getMembershipAvailability(
      date: date,
      userPackageId: userPackageId,
      netId: netId,
    );
  }

  static Future<Map<String, dynamic>> registerSendOtp({
    required String name,
    required String mobile,
    required String countryCode,
    String? email,
    required String password,
  }) async {
    return await post('/register/send-otp', {
      'name': name,
      'mobile': mobile,
      'country_code': countryCode,
      if (email != null && email.isNotEmpty) 'email': email,
      'password': password,
    });
  }

  static Future<Map<String, dynamic>> registerVerifyOtp({
    required String countryCode,
    required String mobile,
    required String otp,
  }) async {
    final data = await post('/register/verify', {
      'country_code': countryCode,
      'mobile': mobile,
      'otp': otp,
    });
    if (data['token'] != null)
      await _saveToken(data['token']);
    else
      throw Exception('No token received from server');
    if (data['user'] != null) await _saveUser(data['user']);
    return data;
  }

  static Future<Map<String, dynamic>> login({
    required String countryCode,
    required String mobile,
    String? password,
  }) async {
    final data = await post('/login', {
      'country_code': countryCode,
      'mobile': mobile,
      if (password != null) 'password': password,
    });
    if (data['token'] != null) {
      await _saveToken(data['token']);
      if (data['user'] != null) await _saveUser(data['user']);
    }
    return data;
  }

  static Future<Map<String, dynamic>> verifyLogin({
    required String countryCode,
    required String mobile,
    required String otp,
  }) async {
    final data = await post('/verify-login', {
      'country_code': countryCode,
      'mobile': mobile,
      'otp': otp,
    });
    if (data['token'] != null)
      await _saveToken(data['token']);
    else
      throw Exception('No token received from server');
    if (data['user'] != null) await _saveUser(data['user']);
    return data;
  }

  static Future<Map<String, dynamic>> resendOtp({
    required String countryCode,
    required String mobile,
    String type = 'login',
  }) async {
    return await post('/resend-otp', {
      'country_code': countryCode,
      'mobile': mobile,
      'type': type,
    });
  }

  static Future<Map<String, dynamic>> getUser() async {
    final cachedUser = await getCachedUser();
    if (cachedUser != null) return cachedUser;
    final data = await get('/user');
    await _saveUser(data);
    return data;
  }

  static Future<void> logout() async {
    try {
      await post('/logout', {});
    } catch (e) {
      // ignore
    } finally {
      await clearToken();
    }
  }

  static Future<List<dynamic>> getBookings() async {
    final data = await get('/bookings');
    return data as List;
  }

  static Future<Map<String, dynamic>> getBooking(int id) async {
    final data = await get('/bookings/$id');
    return data as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getUserBookings() async {
    final data = await get('/user/bookings');
    return data as List;
  }

  static Future<Map<String, dynamic>> createBooking({
    required int? netId,
    required int packageId,
    required String bookingType,
    required String date,
    required String startTime,
    required String endTime,
    List<int>? facilityIds,
    int? coachId,
    String? paymentMethod,
    double? totalPrice,
    String? paymentIntentId,
  }) async {
    return await post('/bookings', {
      'net_id': netId,
      'package_id': packageId,
      'booking_type': bookingType,
      'booking_date': date,
      'start_time': startTime,
      'end_time': endTime,
      if (facilityIds != null && facilityIds.isNotEmpty)
        'facility_ids': facilityIds,
      if (coachId != null) 'coach_id': coachId,
      'payment_method': paymentMethod ?? 'cash',
      'total_price': totalPrice,
      if (paymentIntentId != null) 'payment_intent_id': paymentIntentId,
    });
  }

  static Future<Map<String, dynamic>> cancelBooking(int bookingId) async =>
      await post('/bookings/$bookingId/cancel', {});
  static Future<Map<String, dynamic>> rescheduleBooking(int bookingId) async =>
      await post('/bookings/$bookingId/reschedule', {});

  // ============================================================
  // MEMBERSHIP PACKAGES - FIXED
  // ============================================================

  static Future<List<dynamic>> getMembershipPackages() async {
    if (kDebugMode)
      debugPrint(
        '🎫 [ApiService] getMembershipPackages() → /membership-packages',
      );
    final data = await get('/membership-packages');
    if (kDebugMode) debugPrint('🎫 RAW membership-packages: $data');
    if (data is List) return data;
    if (data is Map) {
      if (data['data'] is List) return data['data'] as List;
      if (data['packages'] is List) return data['packages'] as List;
    }
    throw Exception('Unexpected format from /membership-packages: $data');
  }

  static Future<List<dynamic>> getMembershipStore() async =>
      getMembershipPackages();

  static Future<List<dynamic>> getMyMemberships() async {
    if (kDebugMode)
      debugPrint('🎫 [ApiService] getMyMemberships() → /user-packages/my');
    final data = await get('/user-packages/my');
    if (kDebugMode) debugPrint('🎫 RAW my memberships: $data');
    if (data is List) return data;
    if (data is Map && data['data'] is List) return data['data'] as List;
    if (data is Map && data['memberships'] is List)
      return data['memberships'] as List;
    return [];
  }

  static Future<List<dynamic>> getMembershipBookings(int userPackageId) async {
    try {
      final data = await get('/user-packages/$userPackageId/bookings');
      if (data is List) return data;
      if (data is Map && data['data'] is List) return data['data'] as List;
      return [];
    } catch (e) {
      try {
        final data = await get('/membership-bookings/$userPackageId');
        if (data is List) return data;
        if (data is Map && data['data'] is List) return data['data'] as List;
      } catch (_) {}
      return [];
    }
  }

  static Future<Map<String, dynamic>> bookMembershipSlot({
    required int userPackageId,
    required String bookingDate,
    required String startTime,
    required String endTime,
    int? isPeak,
    double? hoursUsed,
    int? netId,
  }) async {
    String s = startTime.length >= 5 ? startTime.substring(0, 5) : startTime;
    String e = endTime.length >= 5 ? endTime.substring(0, 5) : endTime;
    final Map<String, dynamic> body = {
      'user_package_id': userPackageId,
      'booking_date': bookingDate,
      'start_time': s,
      'end_time': e,
    };
    if (netId != null) {
      body['net_id'] = netId;
    }
    return await post('/membership-bookings', body);
  }

  static Future<Map<String, dynamic>> confirmMembershipPayment(
    int userPackageId, {
    String? paymentIntentId,
  }) async {
    return await post('/user-packages/$userPackageId/confirm-payment', {
      if (paymentIntentId != null) 'payment_intent_id': paymentIntentId,
    });
  }

  static Future<Map<String, dynamic>> createMembershipActivation({
    required int membershipPackageId,
    String? paymentIntentId,
    String? paymentReceiptPath,
  }) async {
    return await post('/user-packages/activate', {
      'membership_package_id': membershipPackageId,
      if (paymentIntentId != null) 'payment_intent_id': paymentIntentId,
      if (paymentReceiptPath != null)
        'payment_receipt_path': paymentReceiptPath,
    });
  }

  static Future<Map<String, dynamic>> purchaseMembership(int packageId) async {
    if (kDebugMode)
      debugPrint('💳 purchaseMembership $packageId -> /user-packages/purchase');
    return await post('/user-packages/purchase', {
      'membership_package_id': packageId,
      'payment_method': 'benefit_pay',
    });
  }

  static Future<Map<String, dynamic>> buyMembership(int packageId) async =>
      purchaseMembership(packageId);
  static Future<Map<String, dynamic>> purchasePackage({
    required int packageId,
    String paymentMethod = 'benefit_pay',
  }) async => purchaseMembership(packageId);
  static Future<Map<String, dynamic>> buyPackage(int packageId) async =>
      purchaseMembership(packageId);
  static Future<Map<String, dynamic>> purchaseCorporateMembership({
    required int packageId,
  }) async => purchaseMembership(packageId);
  static Future<Map<String, dynamic>> purchaseIndividualMembership({
    required int packageId,
  }) async => purchaseMembership(packageId);

  static Future<Map<String, dynamic>> uploadMembershipReceipt({
    required int userPackageId,
    required String filePath,
  }) async {
    try {
      final token = await _getToken();
      final url = '$baseUrl/user-packages/$userPackageId/upload-receipt';
      var request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers['Accept'] = 'application/json';
      request.headers['User-Agent'] = 'KHKCricket/1.0 Mobile';
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('receipt', filePath));
      final streamed = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamed);
      return _handleResponse(
        response,
        '/user-packages/$userPackageId/upload-receipt',
      );
    } catch (e) {
      throw Exception('Upload failed: $e');
    }
  }

  static Future<Map<String, dynamic>> cancelMembershipBooking(
    int membershipBookingId,
  ) async {
    try {
      return await post('/membership-bookings/$membershipBookingId/cancel', {});
    } catch (_) {
      try {
        final headers = await _headers();
        final url = '$baseUrl/membership-bookings/$membershipBookingId';
        final resp = await http
            .delete(Uri.parse(url), headers: headers)
            .timeout(const Duration(seconds: 15));
        return _handleResponse(
              resp,
              '/membership-bookings/$membershipBookingId',
            )
            as Map<String, dynamic>;
      } catch (e) {
        rethrow;
      }
    }
  }

  static Future<Map<String, dynamic>> renewMembership(
    int userPackageId,
  ) async => await post('/user-packages/$userPackageId/renew', {});

  // ============================================================
  // LIVE STREAMS - NEW (YouTube Live)
  // ============================================================

  static Future<List<dynamic>> getLiveStreams() async {
    if (kDebugMode)
      debugPrint('📺 [ApiService] getLiveStreams() → /live-streams');
    final data = await get('/live-streams');
    if (data is List) return data;
    if (data is Map && data['data'] is List) return data['data'] as List;
    if (data is Map && data['streams'] is List) return data['streams'] as List;
    return [];
  }

  static Future<Map<String, dynamic>> getLiveStream(int id) async {
    final data = await get('/live-streams/$id');
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> createLiveStream({
    required String youtubeUrl,
    String? title,
    String? netName,
    String status = 'live',
  }) async {
    return await post('/admin/live-streams', {
          'youtube_url': youtubeUrl,
          if (title != null) 'title': title,
          if (netName != null) 'net_name': netName,
          'status': status,
        })
        as Map<String, dynamic>;
  }

  static Future<void> deleteLiveStream(int id) async {
    final headers = await _headers();
    final url = '$baseUrl/admin/live-streams/$id';
    final resp = await http
        .delete(Uri.parse(url), headers: headers)
        .timeout(const Duration(seconds: 15));
    _handleResponse(resp, '/admin/live-streams/$id');
  }
}
