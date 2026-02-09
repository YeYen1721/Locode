import 'dart:async';
import 'package:http/http.dart' as http;

class RedirectChainModel {
  final String originalUrl;
  final String finalDestination;
  final List<String> hops;
  final int totalHops;
  final bool wasShortened;
  final bool suspiciousHopCount;

  RedirectChainModel({
    required this.originalUrl,
    required this.finalDestination,
    required this.hops,
    required this.totalHops,
    required this.wasShortened,
    required this.suspiciousHopCount,
  });
}

abstract class UrlResolverDataSource {
  Future<RedirectChainModel> resolveRedirects(String url, {int maxHops = 10, Duration timeout = const Duration(seconds: 3)});
}

class UrlResolverDataSourceImpl implements UrlResolverDataSource {
  final http.Client _client;

  UrlResolverDataSourceImpl({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<RedirectChainModel> resolveRedirects(
    String url, {
    int maxHops = 10,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final chain = <String>[url];
    var currentUrl = url;
    bool wasShortened = false;

    for (var i = 0; i < maxHops; i++) {
      try {
        final request = http.Request('HEAD', Uri.parse(currentUrl));
        request.followRedirects = false;
        request.headers['User-Agent'] = 'Loco/1.0 (Security Scanner)';

        final response = await _client.send(request).timeout(timeout);

        final statusCode = response.statusCode;
        if (statusCode >= 300 && statusCode < 400) {
          final location = response.headers['location'];
          if (location == null) break;

          currentUrl = Uri.parse(currentUrl).resolve(location).toString();
          chain.add(currentUrl);
          wasShortened = true;
        } else {
          break;
        }
      } catch (e) {
        break;
      }
    }

    return RedirectChainModel(
      originalUrl: url,
      finalDestination: currentUrl,
      hops: chain,
      totalHops: chain.length - 1,
      wasShortened: wasShortened,
      suspiciousHopCount: chain.length > 4,
    );
  }
}
