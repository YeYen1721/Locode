import 'package:hive_flutter/hive_flutter.dart';
import '../../../scan/domain/entities/scan_result.dart';
import '../../../scan/domain/entities/verdict.dart';

class ReportValidator {
  static const int maxReportsPerUserPerHour = 5;
  static const int maxReportsPerUserPerDay = 20;
  static const int minReportsToDisplayOnMap = 3;

  final Box _rateLimitBox;

  ReportValidator(this._rateLimitBox);

  /// Returns null if valid, or an error message string if invalid.
  String? validate({
    required String userId,
    required String scanId,
    required ScanResult? scanRecord,
  }) {
    // 1. Rate limiting — hourly
    final hourlyKey = '${userId}_hourly';
    final hourlyData = _rateLimitBox.get(hourlyKey);
    if (hourlyData != null) {
      final count = hourlyData['count'] as int;
      final timestamp = DateTime.parse(hourlyData['timestamp'] as String);
      if (DateTime.now().difference(timestamp).inHours < 1 && count >= maxReportsPerUserPerHour) {
        return 'You have reached the hourly report limit ($maxReportsPerUserPerHour). Please try again later.';
      }
    }

    // 2. Rate limiting — daily
    final dailyKey = '${userId}_daily';
    final dailyData = _rateLimitBox.get(dailyKey);
    if (dailyData != null) {
      final count = dailyData['count'] as int;
      final timestamp = DateTime.parse(dailyData['timestamp'] as String);
      if (DateTime.now().difference(timestamp).inHours < 24 && count >= maxReportsPerUserPerDay) {
        return 'You have reached the daily report limit.';
      }
    }

    // 3. Verify scan actually happened
    if (scanRecord == null) {
      return 'No scan record found. You must scan a QR code before reporting it.';
    }

    // 4. Block reporting high-confidence safe URLs
    if (scanRecord.verdict == Verdict.safe && scanRecord.confidence > 0.8) {
      return 'This URL was analyzed as safe with high confidence. '
             'If you believe this is incorrect, please provide additional context.';
    }

    return null; // Valid
  }

  void recordReport(String userId) {
    _incrementCounter('${userId}_hourly', const Duration(hours: 1));
    _incrementCounter('${userId}_daily', const Duration(hours: 24));
  }

  void _incrementCounter(String key, Duration window) {
    final existing = _rateLimitBox.get(key);
    if (existing != null) {
      final timestamp = DateTime.parse(existing['timestamp'] as String);
      if (DateTime.now().difference(timestamp) < window) {
        _rateLimitBox.put(key, {
          'count': (existing['count'] as int) + 1,
          'timestamp': existing['timestamp'],
        });
        return;
      }
    }
    // Reset counter
    _rateLimitBox.put(key, {
      'count': 1,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
