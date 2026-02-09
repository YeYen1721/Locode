import 'package:dartz/dartz.dart';
import 'package:locode/core/error/failures.dart';
import 'package:locode/features/scan/domain/entities/scan_result.dart';
import 'package:locode/features/scan/domain/repositories/scan_repository.dart';

class RunLocalHeuristics {
  final ScanRepository repository;

  RunLocalHeuristics(this.repository);

  Future<Either<Failure, ScanResult>> call(String url) async {
    return await repository.analyzeLocal(url);
  }
}
