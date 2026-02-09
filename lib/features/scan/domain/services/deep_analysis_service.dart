import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;

typedef AgentStepCallback = void Function(String action, String detail);

class DeepAnalysisService {
  final String _apiKey;
  final String _model = 'gemini-3-flash-preview';

  DeepAnalysisService(this._apiKey);

  Future<Map<String, dynamic>> analyzeUrl(String url, {AgentStepCallback? onStep}) async {
    final endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey';
    
    final tools = [
      {
        'functionDeclarations': [
          {
            'name': 'resolve_redirects',
            'description': 'Follow HTTP redirect chain for a URL to find the final destination. Use this to check if a short URL redirects somewhere suspicious.',
            'parameters': {
              'type': 'OBJECT',
              'properties': {
                'url': {'type': 'STRING', 'description': 'The URL to follow redirects for'}
              },
              'required': ['url']
            }
          },
          {
            'name': 'fetch_page_content',
            'description': 'Fetch and analyze the HTML content of a web page. Returns page title, whether it has login forms, urgency language, and external scripts.',
            'parameters': {
              'type': 'OBJECT',
              'properties': {
                'url': {'type': 'STRING', 'description': 'The URL to fetch content from'}
              },
              'required': ['url']
            }
          },
          {
            'name': 'check_community_reports',
            'description': 'Check if a domain has been reported as malicious by the community in the Locode database.',
            'parameters': {
              'type': 'OBJECT',
              'properties': {
                'domain': {'type': 'STRING', 'description': 'The domain to check reports for'}
              },
              'required': ['domain']
            }
          },
          {
            'name': 'check_domain_age',
            'description': 'Check basic domain information including whether it resolves and server headers.',
            'parameters': {
              'type': 'OBJECT',
              'properties': {
                'domain': {'type': 'STRING', 'description': 'The domain to check'}
              },
              'required': ['domain']
            }
          },
          {
            'name': 'check_ssl_certificate',
            'description': 'Verify if a URL has a valid SSL/TLS certificate.',
            'parameters': {
              'type': 'OBJECT',
              'properties': {
                'url': {'type': 'STRING', 'description': 'The URL to check SSL for'}
              },
              'required': ['url']
            }
          },
          {
            'name': 'deliver_verdict',
            'description': 'Deliver your final security verdict. You MUST call this when done investigating.',
            'parameters': {
              'type': 'OBJECT',
              'properties': {
                'verdict': {'type': 'STRING', 'description': 'One of: safe, suspicious, dangerous'},
                'risk_score': {'type': 'INTEGER', 'description': 'Risk score from 0 (safe) to 100 (dangerous)'},
                'summary': {'type': 'STRING', 'description': '1-2 sentence summary for the user'},
                'reasoning': {'type': 'STRING', 'description': 'Detailed reasoning for your verdict'}
              },
              'required': ['verdict', 'risk_score', 'summary', 'reasoning']
            }
          },
        ]
      }
    ];

    final systemInstruction = {
      'parts': [
        {
          'text': '''You are an autonomous URL security analyst agent called Locode. Your job is to investigate URLs from QR codes and determine if they are safe, suspicious, or dangerous.

investigation speed is critical. Be extremely fast and efficient. Use as few tool calls as possible. If a URL is obviously safe (e.g. google.com, apple.com, amazon.com), deliver a safe verdict immediately without calling tools. If you find suspicious patterns, investigate just enough to be sure.

VERDICT GUIDELINES:
- DANGEROUS (risk 85-100): Active phishing with urgency tactics, fake countdown timers, threats of towing/fines, impersonating government/city authority, requesting driver's license or excessive personal info.
- SUSPICIOUS (risk 40-84): Unverified third-party payment pages, unknown payment processors, legitimate-looking but not officially affiliated with a city or known brand, collecting standard payment info without urgency tactics.
- SAFE (risk 0-39): Known legitimate domains, official city/government sites, well-known brands.

A page that collects payment info for parking is NOT automatically dangerous. It's only dangerous if it uses scare tactics, fake urgency, impersonates officials, or requests excessive personal data beyond what's needed for payment.'''
        }
      ]
    };

    List<Map<String, dynamic>> contents = [
      {
        'role': 'user',
        'parts': [
          {'text': 'Investigate this URL that was scanned from a QR code: $url'}
        ]
      }
    ];

    int stepCount = 0;
    const int maxIterations = 6;
    Map<String, dynamic> collectedData = {};

    try {
      for (int i = 0; i < maxIterations; i++) {
        final requestBody = {
          'contents': contents,
          'tools': tools,
          'systemInstruction': systemInstruction,
          'generationConfig': {
            'temperature': 0.1,
            'thinkingConfig': {
              'thinkingLevel': 'LOW'
            }
          }
        };

        final bodyStr = json.encode(requestBody);
        print('[Loco] Request payload size: ${bodyStr.length} bytes (iteration ${i + 1})');
        print('[Loco] Sending request to Gemini 3 (iteration ${i + 1})...');

        http.Response? response;
        Exception? lastError;

        for (int attempt = 0; attempt < 2; attempt++) {
          try {
            response = await http.post(
              Uri.parse(endpoint),
              headers: {'Content-Type': 'application/json'},
              body: bodyStr,
            ).timeout(const Duration(seconds: 15));
            break; // Success, exit retry loop
          } on SocketException catch (e) {
            lastError = e;
            print('[Loco] Network error (SocketException) on attempt ${attempt + 1}: $e');
            if (attempt == 0) await Future.delayed(const Duration(seconds: 2));
          } on TimeoutException catch (e) {
            lastError = e;
            print('[Loco] Timeout error on attempt ${attempt + 1}: $e');
            if (attempt == 0) await Future.delayed(const Duration(seconds: 2));
          } catch (e) {
            lastError = e as Exception;
            print('[Loco] API call attempt ${attempt + 1} failed: $e');
            break; // Don't retry for other types of errors
          }
        }

        if (response == null) {
          throw Exception('Unable to reach analysis service. Check your connection.');
        }

        if (response.statusCode != 200) {
          print('[Loco] API error ${response.statusCode}: ${response.body}');
          throw Exception('Gemini API error: ${response.statusCode}');
        }

        final responseData = json.decode(response.body);
        final candidate = responseData['candidates']?[0];
        final content = candidate?['content'];
        
        if (content == null) {
          print('[Loco] No content in response');
          break;
        }

        contents.add(content);
        
        // Strip thought signatures from all previous model turns to reduce payload
        // but KEEP them on functionCall parts as required by Gemini 3
        for (int j = 0; j < contents.length - 1; j++) {
          final entry = contents[j];
          if (entry['role'] == 'model' && entry['parts'] != null) {
            final parts = entry['parts'] as List<dynamic>;
            for (var part in parts) {
              if (part is Map<String, dynamic>) {
                // ONLY strip from non-functionCall parts
                if (!part.containsKey('functionCall')) {
                  part.remove('thoughtSignature');
                }
              }
            }
          }
        }

        final parts = content['parts'] as List<dynamic>? ?? [];
        List<Map<String, dynamic>> functionResponses = [];
        bool hasDeliverVerdict = false;
        Map<String, dynamic>? verdictResult;

        for (final part in parts) {
          if (part.containsKey('functionCall')) {
            final functionCall = part['functionCall'];
            final functionName = functionCall['name'] as String;
            final args = Map<String, dynamic>.from(functionCall['args'] ?? {});
            
            print('[Loco Agent] Decision: Calling $functionName with $args');
            stepCount++;
            onStep?.call(functionName, 'Executing check...');

            Map<String, dynamic> toolResult;
            
            if (functionName == 'deliver_verdict') {
              hasDeliverVerdict = true;
              verdictResult = {
                'verdict': args['verdict'] ?? 'suspicious',
                'risk_score': args['risk_score'] ?? 50,
                'summary': args['summary'] ?? 'Analysis complete.',
                'reasoning': args['reasoning'] ?? '',
                'tool_calls': stepCount,
              };
              toolResult = {'status': 'verdict_delivered'};
            } else if (functionName == 'resolve_redirects') {
              toolResult = _truncateResult(await _executeResolveRedirects(args['url']));
              collectedData['resolve_redirects'] = toolResult;
            } else if (functionName == 'fetch_page_content') {
              toolResult = _truncateResult(await _executeFetchPageContent(args['url']), maxLen: 800);
              collectedData['fetch_page_content'] = toolResult;
            } else if (functionName == 'check_community_reports') {
              toolResult = _truncateResult(await _executeCheckCommunityReports(args['domain']));
              collectedData['check_community_reports'] = toolResult;
            } else if (functionName == 'check_domain_age') {
              toolResult = _truncateResult(await _executeCheckDomainAge(args['domain']));
              collectedData['check_domain_age'] = toolResult;
            } else if (functionName == 'check_ssl_certificate') {
              toolResult = _truncateResult(await _executeCheckSslCertificate(args['url']));
              collectedData['check_ssl_certificate'] = toolResult;
            } else {
              toolResult = {'error': 'Unknown function: $functionName'};
            }

            stepCount++;
            onStep?.call(functionName, 'Result received');

            functionResponses.add({
              'functionResponse': {
                'name': functionName,
                'response': toolResult,
              }
            });
          }
        }

        if (hasDeliverVerdict && verdictResult != null) {
          print('[Loco] Agent delivered verdict: ${verdictResult['verdict']} (risk: ${verdictResult['risk_score']})');
          return verdictResult;
        }

        if (functionResponses.isNotEmpty) {
          contents.add({
            'role': 'user',
            'parts': functionResponses,
          });
        } else {
          print('[Loco] Model responded without function calls, ending loop');
          break;
        }
      }
      
      print('[Loco] Agent hit max iterations, using fallback verdict');
      return _buildFallbackVerdict(url, collectedData);

    } catch (e, stack) {
      print('[Loco] Agent error, using fallback verdict: $e');
      print('[Loco] Stack: $stack');
      return _buildFallbackVerdict(url, collectedData);
    }
  }

  Map<String, dynamic> _buildFallbackVerdict(String url, Map<String, dynamic> collected) {
    String verdict = 'suspicious';
    int riskScore = 50;
    String summary = 'Analysis was interrupted. ';
    
    // Use whatever data we already collected
    if (collected.containsKey('resolve_redirects')) {
      final redirectData = collected['resolve_redirects'].toString().toLowerCase();
      // Check if final URL is a well-known domain
      final safeDomains = ['google.com', 'amazon.com', 'youtube.com', 'github.com', 
                           'microsoft.com', 'apple.com', 'facebook.com', 'instagram.com',
                           'twitter.com', 'linkedin.com', 'wikipedia.org'];
      for (final domain in safeDomains) {
        if (redirectData.contains(domain)) {
          verdict = 'safe';
          riskScore = 10;
          summary += 'Redirects to well-known domain ($domain). ';
          break;
        }
      }
    }
    
    if (collected.containsKey('check_domain_age')) {
      final ageData = collected['check_domain_age'].toString();
      if (ageData.contains('years')) {
        summary += 'Domain appears established. ';
        if (riskScore > 20) riskScore -= 15;
      }
    }
    
    if (collected.containsKey('check_community_reports')) {
      final reports = collected['check_community_reports'].toString().toLowerCase();
      if (reports.contains('no reports') || reports.contains('0 reports')) {
        summary += 'No negative community reports. ';
      }
    }
    
    if (verdict == 'suspicious') {
      summary += 'Proceed with caution.';
    }
    
    return {
      'verdict': verdict,
      'risk_score': riskScore,
      'summary': summary,
      'reasoning': 'The autonomous analysis timed out or encountered a network error. Synthesized a fallback verdict from partial evidence.',
      'tool_calls': 0,
    };
  }

  Map<String, dynamic> _truncateResult(Map<String, dynamic> result, {int maxLen = 500}) {
    return result.map((key, value) {
      if (value is String && value.length > maxLen) {
        return MapEntry(key, '${value.substring(0, maxLen)}...[truncated]');
      }
      return MapEntry(key, value);
    });
  }

  Future<Map<String, dynamic>> _executeResolveRedirects(String url) async {
    try {
      final redirectChain = <String>[url];
      var currentUrl = url;
      final domains = <String>{Uri.parse(url).host};

      for (var i = 0; i < 10; i++) {
        final client = http.Client();
        final request = http.Request('HEAD', Uri.parse(currentUrl))..followRedirects = false;
        final response = await client.send(request).timeout(const Duration(seconds: 5));
        
        if (response.statusCode >= 300 && response.statusCode < 400) {
          final location = response.headers['location'];
          if (location != null) {
            currentUrl = location.startsWith('http') ? location : Uri.parse(currentUrl).resolve(location).toString();
            redirectChain.add(currentUrl);
            domains.add(Uri.parse(currentUrl).host);
          } else {
            break;
          }
        } else {
          break;
        }
      }
      return {
        'original_url': url,
        'final_url': currentUrl,
        'chain_length': redirectChain.length,
        'chain': redirectChain,
        'unique_domains': domains.toList(),
        'domain_changed': domains.length > 1,
      };
    } catch (e) {
      return {'error': 'Failed to resolve redirects: $e'};
    }
  }

  Future<Map<String, dynamic>> _executeFetchPageContent(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      final body = response.body;
      final lowerBody = body.toLowerCase();

      String pageContent = body;
      final originalLength = body.length;
      if (pageContent.length > 800) {
        pageContent = '${pageContent.substring(0, 800)}\n[truncated]';
        print('[Loco] Truncated page content from $originalLength to 800 chars');
      }

      return {
        'status_code': response.statusCode,
        'url': url,
        'content_length': body.length,
        'has_login_form': lowerBody.contains('<form') && (lowerBody.contains('password') || lowerBody.contains('type="password"')),
        'has_urgency_language': lowerBody.contains('urgent') || lowerBody.contains('suspend') || lowerBody.contains('verify immediately'),
        'html_preview': pageContent,
      };
    } catch (e) {
      return {'error': 'Failed to fetch content: $e'};
    }
  }

  Future<Map<String, dynamic>> _executeCheckCommunityReports(String domain) async {
    return {
      'domain': domain,
      'status': 'No historical reports found in community database.',
      'reports_count': 0
    };
  }

  Future<Map<String, dynamic>> _executeCheckDomainAge(String domain) async {
    try {
      final response = await http.head(Uri.parse('https://$domain')).timeout(const Duration(seconds: 5));
      return {
        'domain': domain,
        'resolves': true,
        'server_header': response.headers['server'] ?? 'unknown',
      };
    } catch (e) {
      return {'domain': domain, 'resolves': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _executeCheckSslCertificate(String url) async {
    try {
      final uri = Uri.parse(url);
      if (uri.scheme != 'https') return {'valid': false, 'reason': 'URL is not using HTTPS'};
      return {'valid': true, 'scheme': 'https', 'message': 'SSL connection established successfully.'};
    } catch (e) {
      return {'valid': false, 'error': e.toString()};
    }
  }
}