import 'dart:typed_data';
import 'package:dartz/dartz.dart';
import 'package:locode/core/error/failures.dart';
import 'package:locode/features/scan/domain/entities/scan_result.dart';
import 'package:locode/features/scan/domain/repositories/scan_repository.dart';

class AnalyzeQrCode {
  final ScanRepository repository;

  AnalyzeQrCode(this.repository);

  Future<Either<Failure, ScanResult>> call(AnalyzeParams params) async {
    return await repository.analyzeFull(
      rawUrl: params.rawUrl,
      latitude: params.latitude,
      longitude: params.longitude,
      photoBytes: params.photoBytes,
    );
  }
}

class AnalyzeParams {
  final String rawUrl;
  final double? latitude;
  final double? longitude;
  final Uint8List? photoBytes;

  const AnalyzeParams({
    required this.rawUrl,
    this.latitude,
    this.longitude,
    this.photoBytes,
  });
}
