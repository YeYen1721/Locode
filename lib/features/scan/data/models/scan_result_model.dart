import 'package:locode/features/scan/domain/entities/verdict.dart';
import 'package:locode/features/scan/domain/entities/scan_result.dart';

class ScanResultModel {
  final Verdict verdict;
  final double confidence;
  final List<String> reasons;
  final List<String> discrepancies;
  final String recommendation;
  final DomainAnalysisModel domainAnalysis;

  ScanResultModel({
    required this.verdict,
    required this.confidence,
    required this.reasons,
    required this.discrepancies,
    required this.recommendation,
    required this.domainAnalysis,
  });

  factory ScanResultModel.fromGeminiResponse(Map<String, dynamic> json) {
    return ScanResultModel(
      verdict: _parseVerdict(json['verdict']),
      confidence: (json['confidence'] as num).toDouble(),
      reasons: List<String>.from(json['reasons'] ?? []),
      discrepancies: List<String>.from(json['discrepancies'] ?? []),
      recommendation: json['recommendation'] ?? '',
      domainAnalysis: DomainAnalysisModel.fromJson(json['domain_analysis'] ?? {}),
    );
  }

  static Verdict _parseVerdict(String? v) {
    switch (v?.toLowerCase()) {
      case 'safe': return Verdict.safe;
      case 'suspicious': return Verdict.suspicious;
      case 'danger': return Verdict.danger;
      default: return Verdict.error;
    }
  }

  ScanResult toEntity(String url, {String? finalDestination, AnalysisSource source = AnalysisSource.full}) {
    return ScanResult(
      verdict: verdict,
      confidence: confidence,
      url: url,
      finalDestination: finalDestination,
      reasons: reasons,
      discrepancies: discrepancies,
      recommendation: recommendation,
      source: source,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'verdict': verdict.name,
      'confidence': confidence,
      'reasons': reasons,
      'discrepancies': discrepancies,
      'recommendation': recommendation,
      'domain_analysis': domainAnalysis.toJson(),
    };
  }
}

class DomainAnalysisModel {
  final String domain;
  final bool isKnownBrand;
  final String? possibleImpersonationOf;

  DomainAnalysisModel({
    required this.domain,
    required this.isKnownBrand,
    this.possibleImpersonationOf,
  });

  factory DomainAnalysisModel.fromJson(Map<String, dynamic> json) {
    return DomainAnalysisModel(
      domain: json['domain'] ?? '',
      isKnownBrand: json['is_known_brand'] ?? false,
      possibleImpersonationOf: json['possible_impersonation_of'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'domain': domain,
      'is_known_brand': isKnownBrand,
      'possible_impersonation_of': possibleImpersonationOf,
    };
  }
}