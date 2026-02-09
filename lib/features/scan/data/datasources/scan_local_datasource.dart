import 'package:hive_flutter/hive_flutter.dart';
import '../models/scan_result_model.dart';
import '../../domain/entities/verdict.dart';

abstract class ScanLocalDataSource {
  Future<void> cacheResult(String url, ScanResultModel result);
  Future<ScanResultModel?> getCachedResult(String url);
}

class ScanLocalDataSourceImpl implements ScanLocalDataSource {
  final Box cacheBox;

  ScanLocalDataSourceImpl({required this.cacheBox});

  @override
  Future<void> cacheResult(String url, ScanResultModel result) async {
    await cacheBox.put(url, {
      'data': result.toJson(),
      'timestamp': DateTime.now().toIso8601String(),
      'verdict': result.verdict.name, // Store verdict for TTL check
    });
  }

  @override
  Future<ScanResultModel?> getCachedResult(String url) async {
    final cached = cacheBox.get(url);
    if (cached == null) return null;
    
    final timestamp = DateTime.parse(cached['timestamp']);
    final verdictString = cached['verdict'] as String?;
    
    Verdict verdict;
    if (verdictString != null) {
      verdict = Verdict.values.firstWhere(
        (e) => e.name == verdictString,
        orElse: () => Verdict.safe,
      );
    } else {
      // Fallback if verdict wasn't stored (migration path)
      final model = ScanResultModel.fromGeminiResponse(cached['data']);
      verdict = model.verdict;
    }

    final ttl = _ttlHoursForVerdict(verdict);
    if (DateTime.now().difference(timestamp).inHours >= ttl) {
      await cacheBox.delete(url);
      return null;
    }
    
    return ScanResultModel.fromGeminiResponse(cached['data']);
  }

  int _ttlHoursForVerdict(Verdict verdict) {
    switch (verdict) {
      case Verdict.safe: return 24;       // Re-check daily
      case Verdict.suspicious: return 6;  // Re-check frequently
      case Verdict.danger: return 48;     // Unlikely to become safe
      default: return 12;
    }
  }
}