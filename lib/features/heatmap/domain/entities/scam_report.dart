import 'package:equatable/equatable.dart';

class ScamReport extends Equatable {
  final String id;
  final String url;
  final double latitude;
  final double longitude;
  final List<String> reasons;

  const ScamReport({
    required this.id,
    required this.url,
    required this.latitude,
    required this.longitude,
    this.reasons = const [],
  });

  @override
  List<Object?> get props => [id, url, latitude, longitude, reasons];
}
