import 'dart:convert';
import 'package:flutter/material.dart';

enum BookingMode { singleSlot, eventBlock, membershipDaily, prepaidCredit }

class Package {
  final int id;
  final String category;
  final String name;
  final String? description;
  final String pricingType;
  final String? imageUrl;
  final double? offPeakBhd;
  final double? peakBhd;
  final double? fullDayPrice;
  final double? eightHrPrice;
  final double? weeklyPrice;
  final double? monthlyPrice;
  final double? totalPrice;
  final double? sessionPrice;
  final List<String>? includes;
  final bool paymentInAdvance;
  final bool requiresNetSelection;
  final bool requiresDateSelection;
  final double? durationHours;
  final double? flat4hrBhd;
  final double? flat8hrBhd;
  final double? weeklyBhd;
  final double? monthlyBhd;
  final int? peakHoursIncluded;
  final int? offpeakHoursIncluded;
  final bool weekdaysOnly;
  final bool weekendsHolidaysOnly;
  final int? sessionsCount;
  final int? validDays;
  final String? peakStart;
  final String? peakEnd;
  final bool includesFullFacility;
  final bool isActive;
  final bool hasBowlingMachineIncluded;
  final int? dailyHoursAllowed;
  final int? membershipDurationDays;

  Package({
    required this.id,
    required this.category,
    required this.name,
    this.description,
    required this.pricingType,
    this.imageUrl,
    this.offPeakBhd,
    this.peakBhd,
    this.fullDayPrice,
    this.eightHrPrice,
    this.weeklyPrice,
    this.monthlyPrice,
    this.totalPrice,
    this.sessionPrice,
    this.includes,
    this.paymentInAdvance = false,
    this.requiresNetSelection = true,
    this.requiresDateSelection = false,
    this.durationHours,
    this.flat4hrBhd,
    this.flat8hrBhd,
    this.weeklyBhd,
    this.monthlyBhd,
    this.peakHoursIncluded,
    this.offpeakHoursIncluded,
    this.weekdaysOnly = false,
    this.weekendsHolidaysOnly = false,
    this.sessionsCount,
    this.validDays,
    this.peakStart,
    this.peakEnd,
    this.includesFullFacility = false,
    this.isActive = true,
    this.hasBowlingMachineIncluded = false,
    this.dailyHoursAllowed,
    this.membershipDurationDays,
  });

  factory Package.fromJson(Map<String, dynamic> json) {
    return Package(
      id: json['id'] as int,
      category: (json['category'] as String).toLowerCase(),
      name: json['name'] as String,
      description: json['description'] as String?,
      pricingType: (json['pricing_type'] as String?) ?? 'hourly_peak_offpeak',
      imageUrl: json['image_url'] as String?,
      offPeakBhd: json['off_peak_bhd'] != null
          ? double.tryParse(json['off_peak_bhd'].toString())
          : null,
      peakBhd: json['peak_bhd'] != null
          ? double.tryParse(json['peak_bhd'].toString())
          : null,
      fullDayPrice: json['full_day_price'] != null
          ? double.tryParse(json['full_day_price'].toString())
          : null,
      eightHrPrice: json['8hr_price'] != null
          ? double.tryParse(json['8hr_price'].toString())
          : null,
      weeklyPrice: json['weekly_price'] != null
          ? double.tryParse(json['weekly_price'].toString())
          : null,
      monthlyPrice: json['monthly_price'] != null
          ? double.tryParse(json['monthly_price'].toString())
          : null,
      totalPrice: json['total_price'] != null
          ? double.tryParse(json['total_price'].toString())
          : null,
      sessionPrice: json['session_price'] != null
          ? double.tryParse(json['session_price'].toString())
          : null,
      flat4hrBhd: json['flat_4hr_bhd'] != null
          ? double.tryParse(json['flat_4hr_bhd'].toString())
          : null,
      flat8hrBhd: json['flat_8hr_bhd'] != null
          ? double.tryParse(json['flat_8hr_bhd'].toString())
          : null,
      weeklyBhd: json['weekly_bhd'] != null
          ? double.tryParse(json['weekly_bhd'].toString())
          : null,
      monthlyBhd: json['monthly_bhd'] != null
          ? double.tryParse(json['monthly_bhd'].toString())
          : null,
      peakHoursIncluded: json['peak_hours_included'] is int
          ? json['peak_hours_included'] as int
          : int.tryParse(json['peak_hours_included']?.toString() ?? ''),
      offpeakHoursIncluded: json['offpeak_hours_included'] is int
          ? json['offpeak_hours_included'] as int
          : int.tryParse(json['offpeak_hours_included']?.toString() ?? ''),
      includes: json['includes'] != null
          ? (json['includes'] is String
                ? List<String>.from(jsonDecode(json['includes']))
                : List<String>.from(json['includes']))
          : null,
      paymentInAdvance:
          json['payment_in_advance'] == 1 || json['payment_in_advance'] == true,
      requiresNetSelection:
          json['requires_net_selection'] == 1 ||
          json['requires_net_selection'] == true,
      requiresDateSelection:
          json['requires_date_selection'] == 1 ||
          json['requires_date_selection'] == true,
      durationHours: json['duration_hours'] != null
          ? double.tryParse(json['duration_hours'].toString())
          : null,
      sessionsCount: json['sessions_count'] as int?,
      validDays: json['valid_days'] as int?,
      weekdaysOnly:
          json['weekdays_only'] == 1 ||
          json['weekdays_only'] == true ||
          json['rules']?['weekdays_only'] == true,
      weekendsHolidaysOnly:
          json['weekends_holidays_only'] == 1 ||
          json['weekends_holidays_only'] == true,
      includesFullFacility:
          json['includes_full_facility'] == 1 ||
          json['includes_full_facility'] == true ||
          json['category'] == 'corporate' ||
          json['category'] == 'event' ||
          json['category'] == 'full_facility' ||
          (json['name'] as String).toLowerCase().contains('full facility'),
      peakStart: json['peak_start'] as String?,
      peakEnd: json['peak_end'] as String?,
      isActive: json['is_active'] == null
          ? true
          : (json['is_active'] == 1 || json['is_active'] == true),
      hasBowlingMachineIncluded:
          json['has_bowling_machine_included'] == true ||
          json['has_bowling_machine_included'] == 1 ||
          (json['name'] as String).toLowerCase().contains(
            'with bowling machine',
          ),
      dailyHoursAllowed: json['daily_hours_allowed'] is int
          ? json['daily_hours_allowed'] as int
          : int.tryParse(json['daily_hours_allowed']?.toString() ?? '') ??
                (json['category'] == 'corporate' ? 2 : null),
      membershipDurationDays: json['membership_duration_days'] is int
          ? json['membership_duration_days'] as int
          : int.tryParse(json['membership_duration_days']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'name': name,
      'description': description,
      'pricing_type': pricingType,
      'image_url': imageUrl,
      'off_peak_bhd': offPeakBhd,
      'peak_bhd': peakBhd,
      'full_day_price': fullDayPrice,
      '8hr_price': eightHrPrice,
      'weekly_price': weeklyPrice,
      'monthly_price': monthlyPrice,
      'total_price': totalPrice,
      'session_price': sessionPrice,
      'includes': includes,
      'payment_in_advance': paymentInAdvance,
      'requires_net_selection': requiresNetSelection,
      'requires_date_selection': requiresDateSelection,
      'duration_hours': durationHours,
      'flat_4hr_bhd': flat4hrBhd,
      'flat_8hr_bhd': flat8hrBhd,
      'weekly_bhd': weeklyBhd,
      'monthly_bhd': monthlyBhd,
      'peak_hours_included': peakHoursIncluded,
      'offpeak_hours_included': offpeakHoursIncluded,
      'weekdays_only': weekdaysOnly,
      'weekends_holidays_only': weekendsHolidaysOnly,
      'sessions_count': sessionsCount,
      'valid_days': validDays,
      'peak_start': peakStart,
      'peak_end': peakEnd,
      'includes_full_facility': includesFullFacility,
      'is_active': isActive,
      'has_bowling_machine_included': hasBowlingMachineIncluded,
      'daily_hours_allowed': dailyHoursAllowed,
      'membership_duration_days': membershipDurationDays,
    };
  }

  // ===== NEW HELPERS FOR PEAK/OFF-PEAK PRICE - FIXES YOUR 25 vs 45 BUG =====
  double get offPeakBhdValue => offPeakBhd ?? 0.0;
  double get peakBhdValue => peakBhd ?? 0.0;

  bool _isPeakByTime(String time) {
    if (time.isEmpty) return false;
    final h = int.tryParse(time.split(':')[0]) ?? 0;
    // Your working day rule: 07:00-15:59 Off-Peak, 16:00-06:59 Peak (00:00-02:00 is Peak)
    if (h >= 7 && h < 16) return false;
    return true;
  }

  /// Returns correct price for a selected start time
  /// Example: Full Facility with Bowling: 19:00 -> 45 BHD, 10:00 -> 25 BHD
  double getPriceForSlot({required String startTime, required double hours}) {
    if (pricingType == 'hourly_peak_offpeak') {
      final isPeak = _isPeakByTime(startTime);
      final rate = isPeak ? peakBhdValue : offPeakBhdValue;
      return rate * hours;
    }
    if (pricingType == 'flat_rate') {
      if (durationHours == 4) return flat4hrBhd ?? fullDayPrice ?? 70.0;
      if (durationHours == 8) return flat8hrBhd ?? eightHrPrice ?? 140.0;
      return totalPrice ?? 0.0;
    }
    return getCurrentPrice();
  }

  double getHourlyRateForSlot(String startTime) {
    if (pricingType != 'hourly_peak_offpeak') return getCurrentPrice();
    return _isPeakByTime(startTime) ? peakBhdValue : offPeakBhdValue;
  }

  BookingMode get bookingMode {
    switch (category) {
      case 'event':
        return BookingMode.eventBlock;
      case 'corporate':
        return BookingMode.membershipDaily;
      case 'package':
        return BookingMode.prepaidCredit;
      default:
        return BookingMode.singleSlot;
    }
  }

  bool get isFullFacility =>
      includesFullFacility ||
      category == 'event' ||
      category == 'corporate' ||
      category == 'full_facility' ||
      name.toLowerCase().contains('full facility');

  bool get hasBowlingMachine =>
      hasBowlingMachineIncluded ||
      name.toLowerCase().contains('with bowling machine') ||
      category == 'event' ||
      category == 'corporate';

  bool get isCorporateMembership => category == 'corporate';
  bool get isEventBooking => category == 'event';
  bool get isIndividualPackage => category == 'package';
  bool get isDailyNet => category == 'individual' || category == 'net';

  bool get isMembership =>
      bookingMode == BookingMode.membershipDaily ||
      bookingMode == BookingMode.prepaidCredit;

  String get membershipType {
    if (isCorporateMembership) {
      return 'corporate_full_facility';
    }
    if (isIndividualPackage) {
      return 'individual_net';
    }
    return 'single';
  }

  int get dailyHours {
    if (isCorporateMembership) {
      return dailyHoursAllowed ?? 2;
    }
    if (isEventBooking) {
      return durationHours?.toInt() ?? 4;
    }
    return 1;
  }

  int? get membershipDays {
    if (!isMembership) {
      return null;
    }
    if (membershipDurationDays != null) {
      return membershipDurationDays;
    }
    if (isCorporateMembership) {
      return name.toLowerCase().contains('week') ? 7 : 30;
    }
    if (isIndividualPackage) {
      return validDays ?? 30;
    }
    return null;
  }

  int get totalIncludedHours {
    if (!isIndividualPackage) {
      return 0;
    }
    return (peakHoursIncluded ?? 0) + (offpeakHoursIncluded ?? 0);
  }

  String get peakOffPeakLabel {
    if (isIndividualPackage) {
      return '$peakHoursIncluded'
          'P + $offpeakHoursIncluded'
          'OP';
    }
    if (isCorporateMembership) {
      return '$dailyHours hrs/day x $membershipDays days';
    }
    return '';
  }

  double get maxPeakPercentage {
    if (isEventBooking || isCorporateMembership) {
      return 50.0;
    }
    return 100.0;
  }

  bool get enforcesPeakRule => isEventBooking || isCorporateMembership;

  bool canSelectPeakHours({required int peakHours, required int offPeakHours}) {
    if (!enforcesPeakRule) {
      return true;
    }
    final total = peakHours + offPeakHours;
    if (total == 0) {
      return true;
    }
    final peakPercent = (peakHours / total) * 100;
    return peakPercent <= maxPeakPercentage;
  }

  String get peakRuleMessage {
    if (!enforcesPeakRule) {
      return '';
    }
    return 'Max 50% Peak Hours allowed. For $dailyHours hrs booking, max ${dailyHours ~/ 2} hr(s) can be Peak.';
  }

  bool isValidForPackage({
    required int selectedPeakHours,
    required int selectedOffPeakHours,
  }) {
    if (!isIndividualPackage) {
      return true;
    }
    return selectedPeakHours <= (peakHoursIncluded ?? 0) &&
        selectedOffPeakHours <= (offpeakHoursIncluded ?? 0);
  }

  bool get isFreeDailyBookingAfterActivation => isMembership;

  String getDisplayPrice() {
    switch (pricingType) {
      case 'hourly_peak_offpeak':
        final off = offPeakBhd?.toStringAsFixed(3) ?? '0.000';
        final peak = peakBhd?.toStringAsFixed(3) ?? '0.000';
        return 'BHD $off - $peak/hr';

      case 'flat_rate':
        if (isFullFacility) {
          return 'BHD ${totalPrice?.toStringAsFixed(3) ?? flat4hrBhd?.toStringAsFixed(3) ?? '0.000'}';
        }
        final four =
            flat4hrBhd?.toStringAsFixed(3) ??
            fullDayPrice?.toStringAsFixed(3) ??
            '0.000';
        final eight =
            flat8hrBhd?.toStringAsFixed(3) ??
            eightHrPrice?.toStringAsFixed(3) ??
            '0.000';
        return 'BHD $four / BHD $eight';

      case 'weekly':
        final w =
            weeklyBhd?.toStringAsFixed(3) ??
            weeklyPrice?.toStringAsFixed(3) ??
            '0.000';
        return 'BHD $w/week';

      case 'monthly':
        final m =
            monthlyBhd?.toStringAsFixed(3) ??
            monthlyPrice?.toStringAsFixed(3) ??
            '0.000';
        return 'BHD $m/month';

      case 'package':
        return 'BHD ${totalPrice?.toStringAsFixed(3) ?? '0.000'}';

      case 'session':
        return 'BHD ${sessionPrice?.toStringAsFixed(3) ?? '0.000'}/session';

      default:
        if (isCorporateMembership) {
          if (name.toLowerCase().contains('week')) {
            return 'BHD ${weeklyBhd?.toStringAsFixed(0) ?? '200'}';
          }
          return 'BHD ${monthlyBhd?.toStringAsFixed(0) ?? '500'}';
        }
        return 'BHD ${totalPrice?.toStringAsFixed(3) ?? '0.000'}';
    }
  }

  // ===== FIXED: Now peak-aware, but keeps backward compatibility =====
  double getCurrentPrice({String? startTime}) {
    // If startTime provided, return correct peak/off-peak price
    if (startTime != null && pricingType == 'hourly_peak_offpeak') {
      return _isPeakByTime(startTime) ? peakBhdValue : offPeakBhdValue;
    }

    if (isEventBooking) {
      if (totalPrice != null && totalPrice! > 0) {
        return totalPrice!;
      }
      if (durationHours == 4) {
        return flat4hrBhd ?? 70.0;
      }
      if (durationHours == 8) {
        return flat8hrBhd ?? 140.0;
      }
      return 0.0;
    }
    if (isCorporateMembership) {
      if (totalPrice != null && totalPrice! > 0) {
        return totalPrice!;
      }
      if (name.toLowerCase().contains('week')) {
        return weeklyBhd ?? weeklyPrice ?? 200.0;
      }
      return monthlyBhd ?? monthlyPrice ?? 500.0;
    }
    if (isIndividualPackage) {
      return totalPrice ?? 0.0;
    }
    switch (pricingType) {
      case 'hourly_peak_offpeak':
        // IMPORTANT: Default to off-peak for backward compat, but callers should use getPriceForSlot
        return offPeakBhd ?? peakBhd ?? 0.0;
      case 'flat_rate':
        if (includesFullFacility) {
          return totalPrice ?? 0.0;
        }
        return flat4hrBhd ?? fullDayPrice ?? eightHrPrice ?? 0.0;
      case 'weekly':
        return weeklyBhd ?? weeklyPrice ?? 0.0;
      case 'monthly':
        return monthlyBhd ?? monthlyPrice ?? 0.0;
      case 'package':
        return totalPrice ?? 0.0;
      case 'session':
        return sessionPrice ?? 0.0;
      default:
        return totalPrice ?? 0.0;
    }
  }

  Color getCategoryColor() {
    switch (category) {
      case 'individual':
      case 'net':
      case 'full_facility':
        return const Color(0xFF00E676);
      case 'event':
        return const Color(0xFF2196F3);
      case 'corporate':
        return const Color(0xFF9C27B0);
      case 'package':
        return const Color(0xFFFF9800);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  bool get isFullFacilityBooking => isFullFacility;

  String get membershipDescription {
    if (isCorporateMembership) {
      return 'Full Facility - All Nets\n$dailyHours Hours per day for $membershipDays days\nBook daily for FREE after activation';
    }
    if (isIndividualPackage) {
      return 'Individual Net Membership\n$peakHoursIncluded Peak + $offpeakHoursIncluded Off-Peak Hours\nWeekdays Only - Payment in Advance';
    }
    if (isEventBooking) {
      return 'Full Facility Event Booking\n${durationHours?.toInt()} hrs per day - Max 50% Peak allowed';
    }
    return description ?? '';
  }
}
