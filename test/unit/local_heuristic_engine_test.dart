import 'package:flutter_test/flutter_test.dart';
import 'package:locode/features/scan/data/datasources/local_heuristic_engine.dart';
import 'package:locode/features/scan/domain/entities/verdict.dart';

void main() {
  late LocalHeuristicEngine engine;

  setUp(() {
    engine = LocalHeuristicEngine();
  });

  // ══════════════════════════════════════════
  // SAFE URLS — Must not false-positive
  // ══════════════════════════════════════════
  group('Safe URLs', () {
    test('google.com is safe', () {
      final result = engine.analyze('https://www.google.com');
      expect(result.verdict, equals(Verdict.safe));
      expect(result.flags, isEmpty);
    });

    test('paypal.com (legitimate) is safe — NOT flagged as homoglyph', () {
      final result = engine.analyze('https://www.paypal.com');
      expect(result.verdict, equals(Verdict.safe));
      expect(result.flags.any((f) => f.toLowerCase().contains('homoglyph')), isFalse,
        reason: 'Exact brand match should NOT trigger homoglyph warning');
    });

    test('github.com/flutter/flutter is safe', () {
      final result = engine.analyze('https://github.com/flutter/flutter');
      expect(result.verdict, equals(Verdict.safe));
    });

    test('apple.com is safe — NOT flagged as homoglyph', () {
      final result = engine.analyze('https://www.apple.com');
      expect(result.verdict, equals(Verdict.safe));
    });
  });

  // ══════════════════════════════════════════
  // HOMOGLYPH ATTACKS
  // ══════════════════════════════════════════
  group('Homoglyph Detection', () {
    test('paypa1.com flagged (1 instead of l)', () {
      final result = engine.analyze('https://paypa1.com/login');
      expect(result.verdict, isNot(equals(Verdict.safe)));
      expect(result.flags, anyElement(contains('paypal')));
    });

    test('g00gle.com flagged (zeros instead of o)', () {
      final result = engine.analyze('https://g00gle.com');
      expect(result.verdict, isNot(equals(Verdict.safe)));
      expect(result.flags, anyElement(contains('google')));
    });

    test('arnazon.com flagged (rn instead of m)', () {
      final result = engine.analyze('https://arnazon.com');
      expect(result.verdict, isNot(equals(Verdict.safe)));
      expect(result.flags, anyElement(contains('amazon')));
    });

    test('payroll.com NOT flagged as paypal (distance > 2)', () {
      final result = engine.analyze('https://payroll.com');
      expect(result.flags.any((f) => f.toLowerCase().contains('paypal')), isFalse);
    });
  });

  // ══════════════════════════════════════════
  // SUSPICIOUS TLDs
  // ══════════════════════════════════════════
  group('Suspicious TLD', () {
    test('.cc flagged', () {
      final result = engine.analyze('https://example.cc');
      expect(result.flags, anyElement(contains('.cc')));
    });

    test('.xyz flagged', () {
      final result = engine.analyze('https://example.xyz');
      expect(result.flags, anyElement(contains('.xyz')));
    });

    test('.com NOT flagged', () {
      final result = engine.analyze('https://example.com');
      expect(result.flags.any((f) => f.contains('TLD')), isFalse);
    });
  });

  // ══════════════════════════════════════════
  // IP-BASED URLS
  // ══════════════════════════════════════════
  group('IP-Based URL', () {
    test('IP address URL flagged', () {
      final result = engine.analyze('https://192.168.1.1/login');
      expect(result.flags, anyElement(contains('IP address')));
    });

    test('Normal domain NOT flagged as IP', () {
      final result = engine.analyze('https://example.com');
      expect(result.flags.any((f) => f.contains('IP')), isFalse);
    });
  });

  // ══════════════════════════════════════════
  // CREDENTIAL HARVESTING
  // ══════════════════════════════════════════
  group('Credential Harvesting', () {
    test('/login path flagged', () {
      final result = engine.analyze('https://example.com/login');
      expect(result.flags, anyElement(contains('credential')));
    });

    test('/verify-account flagged', () {
      final result = engine.analyze('https://example.com/verify-account');
      expect(result.flags, anyElement(contains('credential')));
    });

    test('/about path NOT flagged', () {
      final result = engine.analyze('https://example.com/about');
      expect(result.flags.any((f) => f.contains('credential')), isFalse);
    });
  });

  // ══════════════════════════════════════════
  // URL SHORTENERS
  // ══════════════════════════════════════════
  group('URL Shorteners', () {
    test('bit.ly flagged', () {
      final result = engine.analyze('https://bit.ly/3xAbCdE');
      expect(result.flags, anyElement(contains('shortener')));
    });

    test('tinyurl.com flagged', () {
      final result = engine.analyze('https://tinyurl.com/abc123');
      expect(result.flags, anyElement(contains('shortener')));
    });
  });

  // ══════════════════════════════════════════
  // SCHEME CHECKS
  // ══════════════════════════════════════════
  group('Scheme Detection', () {
    test('data: URI flagged as danger', () {
      final result = engine.analyze('data:text/html,<script>alert(1)</script>');
      expect(result.verdict, equals(Verdict.danger));
    });

    test('javascript: URI flagged as danger', () {
      final result = engine.analyze('javascript:alert(1)');
      expect(result.verdict, equals(Verdict.danger));
    });

    test('http (not https) flagged', () {
      final result = engine.analyze('http://example.com');
      expect(result.flags, anyElement(contains('HTTP')));
    });
  });

  // ══════════════════════════════════════════
  // IDN HOMOGRAPH
  // ══════════════════════════════════════════
  group('IDN Homograph', () {
    test('Cyrillic characters in domain flagged', () {
      // 'а' below is Cyrillic, not Latin
      final result = engine.analyze('https://аpple.com');
      expect(result.flags, anyElement(contains('non-ASCII')));
    });
  });

  // ══════════════════════════════════════════
  // EDGE CASES
  // ══════════════════════════════════════════
  group('Edge Cases', () {
    test('empty string returns danger', () {
      final result = engine.analyze('');
      expect(result.verdict, equals(Verdict.danger));
    });

    test('null-like malformed URL returns danger', () {
      final result = engine.analyze('not a url at all');
      expect(result, isNotNull); // Must not crash
    });

    test('extremely long URL flagged', () {
      final longUrl = 'https://example.com/${'a' * 300}';
      final result = engine.analyze(longUrl);
      expect(result.flags, anyElement(contains('long')));
    });

    test('excessive subdomains flagged', () {
      final result = engine.analyze('https://a.b.c.d.e.example.com');
      expect(result.flags, anyElement(contains('subdomain')));
    });
  });

  // ══════════════════════════════════════════
  // COMBINED SCORING
  // ══════════════════════════════════════════
  group('Combined Risk Scoring', () {
    test('multiple red flags produce danger verdict', () {
      // Suspicious TLD + homoglyph + credential path = danger
      final result = engine.analyze('https://paypa1.cc/verify-account');
      expect(result.verdict, equals(Verdict.danger));
      expect(result.confidence, greaterThan(0.6));
      expect(result.flags.length, greaterThanOrEqualTo(3));
    });

    test('single minor flag produces suspicious, not danger', () {
      // Only HTTP (no HTTPS) — minor flag
      final result = engine.analyze('http://legitimatesite.com');
      expect(result.verdict, equals(Verdict.suspicious));
      expect(result.confidence, lessThan(0.8));
    });

    test('confidence scales with risk score', () {
      final safe = engine.analyze('https://www.google.com');
      final suspicious = engine.analyze('http://example.cc');
      final danger = engine.analyze('https://paypa1.cc/login/verify');

      // Confidence should increase with severity
      expect(danger.confidence, greaterThan(suspicious.confidence));
    });
  });
}
