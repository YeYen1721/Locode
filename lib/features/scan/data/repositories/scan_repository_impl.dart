import 'package:dartz/dartz.dart';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:locode/core/error/failures.dart';
import 'package:locode/core/network/network_info.dart';
import 'package:locode/features/scan/domain/entities/scan_result.dart';
import 'package:locode/features/scan/domain/entities/verdict.dart';
import 'package:locode/features/scan/domain/repositories/scan_repository.dart';
import 'package:locode/features/scan/data/datasources/gemini_remote_datasource.dart';
import 'package:locode/features/scan/data/datasources/url_resolver_datasource.dart';
import 'package:locode/features/scan/data/datasources/local_heuristic_engine.dart';
import 'package:locode/features/scan/data/datasources/scan_local_datasource.dart';

class ScanRepositoryImpl implements ScanRepository {
  final GeminiRemoteDataSource remoteDataSource;
  final UrlResolverDataSource urlResolver;
  final LocalHeuristicEngine localEngine;
  final ScanLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  ScanRepositoryImpl({
    required this.remoteDataSource,
    required this.urlResolver,
    required this.localEngine,
    required this.localDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, ScanResult>> analyzeLocal(String rawUrl) async {
    final result = localEngine.analyze(rawUrl);
    return Right(ScanResult(
      verdict: result.verdict,
      confidence: result.confidence,
      url: rawUrl,
      reasons: result.flags,
      source: AnalysisSource.localOnly,
    ));
  }

  @override
  Future<Either<Failure, ScanResult>> analyzeFull({
    required String rawUrl,
    double? latitude,
    double? longitude,
    Uint8List? photoBytes,
  }) async {
    final localResult = localEngine.analyze(rawUrl);
    
    // Privacy: GPS Fuzzing (approx 100m)
    final fuzzedLat = latitude != null ? (latitude * 1000).round() / 1000 : null;
    final fuzzedLng = longitude != null ? (longitude * 1000).round() / 1000 : null;

    debugPrint('[ScanRepo] Starting full analysis for: $rawUrl');

    if (await networkInfo.isConnected) {
      debugPrint('[ScanRepo] Device is ONLINE');
      try {
        // Cache Check
        final cached = await localDataSource.getCachedResult(rawUrl);
        if (cached != null) {
          debugPrint('[ScanRepo] CACHE HIT: Returning cached result');
          return Right(cached.toEntity(rawUrl, source: AnalysisSource.cached));
        }
        debugPrint('[ScanRepo] CACHE MISS: Proceeding to remote analysis');

        // Resolve Redirects
        debugPrint('[ScanRepo] Resolving redirects...');
        final redirects = await urlResolver.resolveRedirects(rawUrl)
            .timeout(const Duration(seconds: 5));
        debugPrint('[ScanRepo] Resolved to: ${redirects.finalDestination} (${redirects.totalHops} hops)');

        // Call Gemini
        debugPrint('[ScanRepo] Calling Gemini Remote Data Source...');
        final geminiResult = await remoteDataSource.analyze(
          url: redirects.finalDestination,
          redirectChain: redirects,
          latitude: fuzzedLat,
          longitude: fuzzedLng,
          photoBytes: photoBytes,
        ).timeout(const Duration(seconds: 8));

        // Cache the result
        await localDataSource.cacheResult(rawUrl, geminiResult);
        debugPrint('[ScanRepo] Analysis COMPLETE and cached');

        return Right(geminiResult.toEntity(rawUrl, finalDestination: redirects.finalDestination));
      } on TimeoutException {
        debugPrint('[ScanRepo] ERROR: Analysis TIMED OUT');
        return Right(localResult.toEntity(rawUrl, source: AnalysisSource.localOnly)
            .withNote('AI analysis timed out. Using local heuristics.'));
      } catch (e) {
        debugPrint('[ScanRepo] ERROR: Remote analysis failed: $e');
        return Right(ScanResult(
          verdict: localResult.verdict,
          confidence: localResult.confidence,
          url: rawUrl,
          reasons: localResult.flags,
          note: 'AI analysis failed. Using local heuristics.',
          source: AnalysisSource.localOnly,
        ));
      }
    } else {
      debugPrint('[ScanRepo] Device is OFFLINE: Returning local result');
      return Right(localResult.toEntity(rawUrl, source: AnalysisSource.localOnly)
          .withNote('Offline mode. Using local heuristics only.'));
    }
  }
}

extension HeuristicToScanResult on HeuristicResult {
  ScanResult toEntity(String url, {AnalysisSource source = AnalysisSource.localOnly}) {
    return ScanResult(
      verdict: verdict,
      confidence: confidence,
      url: url,
      reasons: flags,
      source: source,
    );
  }
}