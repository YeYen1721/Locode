import 'package:flutter/foundation.dart';

/// Represents the security verdict returned by the Gemini 3 Contextual Guard.
@immutable
class LocodeResult {
  /// The final safety status: 'Safe', 'Danger', or 'Warning'.
  final String status;

  /// A numeric risk value from 0 to 100.
  final int riskScore;

  /// The natural language explanation behind the security decision.
  final String reasoning;

  const LocodeResult({
    required this.status,
    required this.riskScore,
    required this.reasoning,
  });

  /// Factory to create a result from a JSON map.
  /// 
  /// Optimized for use with [compute] to offload parsing from the UI thread.
  factory LocodeResult.fromJson(Map<String, dynamic> json) {
    return LocodeResult(
      status: json['status'] as String? ?? 'Danger',
      riskScore: json['risk_score'] as int? ?? 100,
      reasoning: json['reasoning'] as String? ?? 'Unknown parsing error.',
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'risk_score': riskScore,
    'reasoning': reasoning,
  };
}
