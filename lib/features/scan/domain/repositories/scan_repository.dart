import 'dart:typed_data';
import 'package:dartz/dartz.dart';
import 'package:locode/core/error/failures.dart';
import 'package:locode/features/scan/domain/entities/scan_result.dart';

abstract class ScanRepository {
  Future<Either<Failure, ScanResult>> analyzeFull({
    required String rawUrl,
    double? latitude,
    double? longitude,
    Uint8List? photoBytes,
  });
  
  Future<Either<Failure, ScanResult>> analyzeLocal(String rawUrl);
}