import 'dart:math' as math;
import 'package:locode/features/scan/domain/entities/verdict.dart';

class HeuristicResult {
  final Verdict verdict;
  final double confidence;
  final List<String> flags;
  final int riskScore;

  HeuristicResult({
    required this.verdict,
    required this.confidence,
    required this.flags,
    required this.riskScore,
  });
}

class LocalHeuristicEngine {
  /// Runs all checks and returns a scored result.
  /// This MUST complete in under 50ms to keep the UI responsive.
  HeuristicResult analyze(String rawUrl) {
    if (rawUrl.isEmpty) {
      return HeuristicResult(
        verdict: Verdict.danger,
        confidence: 0.95,
        flags: ['Empty URL'],
        riskScore: 10,
      );
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      return HeuristicResult(
        verdict: Verdict.danger,
        confidence: 0.95,
        flags: ['Malformed URL — cannot parse'],
        riskScore: 10,
      );
    }

    int riskScore = 0;
    final flags = <String>[];

    // ──────────────────────────────────────
    // CHECK 1: Suspicious TLDs
    // ──────────────────────────────────────
    final suspiciousTlds = {
      '.cc', '.tk', '.ml', '.ga', '.cf', '.gq',
      '.buzz', '.top', '.xyz', '.club', '.icu',
      '.work', '.link', '.click', '.surf',
    };
    final hostParts = uri.host.toLowerCase().split('.');
    if (hostParts.isNotEmpty) {
      final tld = '.${hostParts.last}';
      if (suspiciousTlds.contains(tld)) {
        riskScore += 3;
        flags.add('Uses commonly-abused TLD: $tld');
      }
    }

    // ──────────────────────────────────────
    // CHECK 2: Homoglyph Attack Detection
    // ──────────────────────────────────────
    final knownBrands = [
      'paypal', 'google', 'apple', 'amazon', 'microsoft',
      'venmo', 'cashapp', 'zelle', 'chase', 'wellsfargo',
      'bankofamerica', 'netflix', 'spotify', 'instagram',
      'facebook', 'twitter',
    ];
    
    if (hostParts.length >= 2) {
      final domainName = hostParts[hostParts.length - 2];

      for (final brand in knownBrands) {
        final distance = _levenshteinDistance(domainName, brand);
        if (distance > 0 && distance <= 2) {
          riskScore += 5;
          flags.add('Domain "$domainName" closely resembles "$brand" — possible spoofing');
          break; // Only flag once
        }
      }
    }

    // ──────────────────────────────────────
    // CHECK 3: Cyrillic / Unicode IDN Homograph Attack
    // ──────────────────────────────────────
    // Check rawUrl for non-ASCII because Uri.parse might punycode it
    if (_containsNonAscii(uri.host) || _containsNonAscii(rawUrl) || uri.host.startsWith('xn--')) {
      riskScore += 4;
      flags.add('Domain contains non-ASCII characters or Punycode — possible IDN homograph attack');
    }
    // Check rawUrl for mixed scripts
    if (_containsMixedScripts(uri.host) || _containsMixedScripts(rawUrl)) {
      riskScore += 5;
      flags.add('Domain mixes Latin and Cyrillic characters — likely homograph attack');
    }

    // ──────────────────────────────────────
    // CHECK 4: IP-Based URL Detection
    // ──────────────────────────────────────
    if (RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(uri.host)) {
      riskScore += 4;
      flags.add('URL points to raw IP address instead of domain name');
    }

    // ──────────────────────────────────────
    // CHECK 5: Excessive Subdomain Detection
    // ──────────────────────────────────────
    final subdomainCount = uri.host.split('.').length;
    if (subdomainCount > 4) {
      riskScore += 2;
      flags.add('Unusual number of subdomains ($subdomainCount levels)');
    }

    // ──────────────────────────────────────
    // CHECK 6: Credential Harvesting Path Keywords
    // ──────────────────────────────────────
    final path = uri.path.toLowerCase();
    final suspiciousPaths = [
      'login', 'signin', 'verify', 'account', 'secure',
      'update', 'confirm', 'authenticate', 'wallet', 'billing',
      'password', 'credential', 'ssn', 'social-security',
    ];
    final matchedPaths = suspiciousPaths.where((p) => path.contains(p)).toList();
    if (matchedPaths.isNotEmpty) {
      riskScore += 3;
      flags.add('URL path contains credential-related keywords: ${matchedPaths.join(", ")}');
    }

    // ──────────────────────────────────────
    // CHECK 7: URL Length Anomaly
    // ──────────────────────────────────────
    if (rawUrl.length > 200) {
      riskScore += 1;
      flags.add('Unusually long URL (${rawUrl.length} characters)');
    }

    // ──────────────────────────────────────
    // CHECK 8: Non-HTTP Scheme Detection
    // ──────────────────────────────────────
    if (uri.scheme == 'data' || uri.scheme == 'javascript') {
      riskScore += 8;
      flags.add('Dangerous non-HTTP scheme detected: ${uri.scheme}');
    }

    // ──────────────────────────────────────
    // CHECK 9: HTTP vs HTTPS
    // ──────────────────────────────────────
    if (uri.scheme == 'http') {
      // Bumped to 3 to ensure it triggers 'Suspicious' on its own per test requirements
      riskScore += 3; 
      flags.add('Uses unencrypted HTTP instead of HTTPS');
    }

    // ──────────────────────────────────────
    // CHECK 10: URL Shortener Detection
    // ──────────────────────────────────────
    final shorteners = {
      'bit.ly', 'tinyurl.com', 't.co', 'goo.gl', 'ow.ly',
      'is.gd', 'buff.ly', 'rb.gy', 'shorturl.at', 'tiny.cc',
    };
    if (shorteners.contains(uri.host.toLowerCase())) {
      riskScore += 2;
      flags.add('URL shortener detected — true destination hidden');
    }

    // ──────────────────────────────────────
    // SCORING (Dynamic Confidence)
    // ──────────────────────────────────────
    Verdict verdict;
    double confidence;

    if (riskScore >= 7) {
      verdict = Verdict.danger;
      confidence = (riskScore / 15).clamp(0.6, 0.95);
    } else if (riskScore >= 3) {
      verdict = Verdict.suspicious;
      confidence = (riskScore / 10).clamp(0.4, 0.8);
    } else {
      verdict = Verdict.safe;
      // Safe is never 100% confident — local heuristics alone can't guarantee safety
      confidence = riskScore == 0 ? 0.7 : 0.5;
    }

    return HeuristicResult(
      verdict: verdict,
      confidence: confidence,
      flags: flags,
      riskScore: riskScore,
    );
  }

  int _levenshteinDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    List<List<int>> matrix = List.generate(
      a.length + 1,
      (i) => List.generate(b.length + 1, (j) => i == 0 ? j : (j == 0 ? i : 0)),
    );

    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        int cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[a.length][b.length];
  }

  bool _containsNonAscii(String input) {
    return input.runes.any((r) => r > 127);
  }

  bool _containsMixedScripts(String input) {
    bool hasLatin = input.runes.any((r) => (r >= 0x41 && r <= 0x5A) || (r >= 0x61 && r <= 0x7A));
    bool hasCyrillic = input.runes.any((r) => r >= 0x400 && r <= 0x4FF);
    return hasLatin && hasCyrillic;
  }
}
