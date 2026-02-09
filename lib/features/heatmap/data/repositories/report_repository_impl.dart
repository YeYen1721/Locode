import 'package:supabase/supabase.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dartz/dartz.dart';
import 'package:locode/core/error/failures.dart';
import 'package:locode/features/scan/domain/entities/scan_result.dart';
import 'package:locode/features/heatmap/data/validators/report_validator.dart';

abstract class ReportRepository {
  Future<Either<Failure, Unit>> submitReport({
    required String url,
    required String scanId,
    required String userId,
    required ScanResult? scanRecord,
  });
}

class ReportRepositoryImpl implements ReportRepository {
  final SupabaseClient supabase;
  final ReportValidator validator;
  
  ReportRepositoryImpl(this.supabase, this.validator);

  @override
  Future<Either<Failure, Unit>> submitReport({
    required String url,
    required String scanId,
    required String userId,
    required ScanResult? scanRecord,
  }) async {
    try {
      final validationError = validator.validate(
        userId: userId,
        scanId: scanId,
        scanRecord: scanRecord,
      );

      if (validationError != null) {
        return Left(ReportValidationFailure(validationError));
      }
      
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      await supabase.from('scams').insert({
        'url': url,
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'reason': 'danger',
        'created_at': DateTime.now().toIso8601String(),
      });

      validator.recordReport(userId);

      return const Right(unit);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
