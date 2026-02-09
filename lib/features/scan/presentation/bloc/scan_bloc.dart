import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:stream_transform/stream_transform.dart';
import 'package:dartz/dartz.dart';
import 'package:locode/core/error/failures.dart';
import 'package:locode/features/scan/domain/entities/scan_result.dart';
import 'package:locode/features/scan/domain/usecases/analyze_qr_code.dart';
import 'package:locode/features/scan/domain/usecases/run_local_heuristics.dart';

abstract class ScanEvent extends Equatable {
  const ScanEvent();
  @override
  List<Object?> get props => [];
}

class ScanStarted extends ScanEvent {
  final String rawUrl;
  final double? latitude;
  final double? longitude;
  final Uint8List? photoBytes;

  const ScanStarted({
    required this.rawUrl,
    this.latitude,
    this.longitude,
    this.photoBytes,
  });

  @override
  List<Object?> get props => [rawUrl, latitude, longitude, photoBytes];
}

class ScanReset extends ScanEvent {
  const ScanReset();
}

abstract class ScanState extends Equatable {
  const ScanState();
  @override
  List<Object?> get props => [];
}

class ScanInitial extends ScanState {
  const ScanInitial();
}

class ScanInProgress extends ScanState {
  const ScanInProgress();
}

class ScanLocalResultReady extends ScanState {
  final ScanResult result;
  const ScanLocalResultReady(this.result);
  @override
  List<Object?> get props => [result];
}

class ScanFullResultReady extends ScanState {
  final ScanResult result;
  const ScanFullResultReady(this.result);
  @override
  List<Object?> get props => [result];
}

class ScanError extends ScanState {
  final String message;
  final ScanResult? partialResult;
  const ScanError(this.message, {this.partialResult});
  @override
  List<Object?> get props => [message, partialResult];
}

class ScanBloc extends Bloc<ScanEvent, ScanState> {
  final AnalyzeQrCode analyzeQrCode;
  final RunLocalHeuristics runLocalHeuristics;

  ScanBloc({
    required this.analyzeQrCode,
    required this.runLocalHeuristics,
  }) : super(const ScanInitial()) {
    
    // Performance: restartable() cancels previous scan if a new one arrives
    on<ScanStarted>(_onScanStarted, transformer: restartable());
    on<ScanReset>((event, emit) => emit(const ScanInitial()));
  }

  Future<void> _onScanStarted(ScanStarted event, Emitter<ScanState> emit) async {
    debugPrint('[ScanBloc] EVENT: ScanStarted for ${event.rawUrl}');
    emit(const ScanInProgress());

    // 1. Local Analysis (Immediate feedback)
    debugPrint('[ScanBloc] Running local heuristics...');
    final Either<Failure, ScanResult> localResult = await runLocalHeuristics(event.rawUrl);
    ScanResult? tempResult;
    
    localResult.fold(
      (failure) {
        debugPrint('[ScanBloc] Local Heuristics FAILED: ${failure.message}');
        emit(ScanError(failure.message));
      },
      (result) {
        debugPrint('[ScanBloc] Local Heuristics SUCCESS: ${result.verdict}');
        tempResult = result;
        emit(ScanLocalResultReady(result));
      },
    );

    // 2. Full Analysis (Remote/AI - Progressive enhancement)
    debugPrint('[ScanBloc] Starting full AI analysis...');
    final Either<Failure, ScanResult> fullResult = await analyzeQrCode(AnalyzeParams(
      rawUrl: event.rawUrl,
      latitude: event.latitude,
      longitude: event.longitude,
      photoBytes: event.photoBytes,
    ));

    fullResult.fold(
      (failure) {
        debugPrint('[ScanBloc] Full AI Analysis FAILED: ${failure.message}');
        emit(ScanError(failure.message, partialResult: tempResult));
      },
      (result) {
        debugPrint('[ScanBloc] Full AI Analysis SUCCESS: ${result.verdict}');
        emit(ScanFullResultReady(result));
      },
    );
  }
}

// Transformer helper
EventTransformer<E> restartable<E>() => (events, mapper) => events.switchMap(mapper);