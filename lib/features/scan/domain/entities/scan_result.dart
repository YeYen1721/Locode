import 'verdict.dart';

enum AnalysisSource {
  localOnly,
  localAndRedirect,
  full,
  cached,
}

class ScanResult {
  final Verdict verdict;
  final double confidence;
  final String url;
  final String? finalDestination;
  final List<String> reasons;
  final List<String> discrepancies;
  final String recommendation;
  final String? note;
  final AnalysisSource source;

  const ScanResult({
    required this.verdict,
    required this.confidence,
    required this.url,
    this.finalDestination,
    this.reasons = const [],
    this.discrepancies = const [],
    this.recommendation = '',
    this.note,
    this.source = AnalysisSource.localOnly,
  });

  ScanResult withNote(String newNote) {
    return ScanResult(
      verdict: verdict,
      confidence: confidence,
      url: url,
      finalDestination: finalDestination,
      reasons: reasons,
      discrepancies: discrepancies,
      recommendation: recommendation,
      note: newNote,
      source: source,
    );
  }
}
