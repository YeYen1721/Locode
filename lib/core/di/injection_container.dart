import 'package:get_it/get_it.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:locode/core/network/network_info.dart';
import 'package:locode/features/scan/data/datasources/gemini_remote_datasource.dart';
import 'package:locode/features/scan/data/datasources/url_resolver_datasource.dart';
import 'package:locode/features/scan/data/datasources/local_heuristic_engine.dart';
import 'package:locode/features/scan/data/datasources/scan_local_datasource.dart';
import 'package:locode/features/scan/data/repositories/scan_repository_impl.dart';
import 'package:locode/features/scan/domain/repositories/scan_repository.dart';
import 'package:locode/features/scan/domain/usecases/analyze_qr_code.dart';
import 'package:locode/features/scan/domain/usecases/run_local_heuristics.dart';
import 'package:locode/features/scan/presentation/bloc/scan_bloc.dart';
import 'package:locode/features/heatmap/data/validators/report_validator.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // External
  sl.registerLazySingleton(() => InternetConnectionChecker.instance);
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));
  
  // Gemini Configuration (Secure compile-time variables)
  const geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
  sl.registerSingleton<String>(geminiApiKey, instanceName: 'geminiApiKey');
  debugPrint('[DI] GEMINI_API_KEY length: ${geminiApiKey.length}');
  if (geminiApiKey.isEmpty) {
    debugPrint('[DI] WARNING: GEMINI_API_KEY is empty! Gemini calls will fail.');
  }
  
  sl.registerLazySingleton<GenerativeModel>(
    () => GenerativeModel(
      model: 'gemini-3-flash-preview',
      apiKey: geminiApiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.2, // Low temp for consistent safety analysis
        maxOutputTokens: 1024,
      ),
    ),
  );

  final scanCacheBox = await Hive.openBox('scan_cache');
  sl.registerLazySingleton(() => scanCacheBox);
  
  final rateLimitBox = await Hive.openBox('rate_limits');
  sl.registerLazySingleton(() => ReportValidator(rateLimitBox));

  // Data Sources
  sl.registerLazySingleton<GeminiRemoteDataSource>(
    () => GeminiRemoteDataSourceImpl(generativeModel: sl()),
  );
  sl.registerLazySingleton<UrlResolverDataSource>(
    () => UrlResolverDataSourceImpl(),
  );
  sl.registerLazySingleton<LocalHeuristicEngine>(
    () => LocalHeuristicEngine(),
  );
  sl.registerLazySingleton<ScanLocalDataSource>(
    () => ScanLocalDataSourceImpl(cacheBox: sl()),
  );

  // Repositories
  sl.registerLazySingleton<ScanRepository>(
    () => ScanRepositoryImpl(
      remoteDataSource: sl(),
      urlResolver: sl(),
      localEngine: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // Use Cases
  sl.registerLazySingleton(() => AnalyzeQrCode(sl()));
  sl.registerLazySingleton(() => RunLocalHeuristics(sl()));

  // Blocs
  sl.registerFactory(() => ScanBloc(
    analyzeQrCode: sl(),
    runLocalHeuristics: sl(),
  ));
}