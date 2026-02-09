class ServerException implements Exception {}
class CacheException implements Exception {}
class GeminiApiException implements Exception {
  final String? message;
  GeminiApiException(this.message);
}
