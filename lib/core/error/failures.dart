import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure() : super('No internet connection. Using offline analysis.');
}

class GeminiTimeoutFailure extends Failure {
  const GeminiTimeoutFailure() : super('AI analysis timed out. Showing local analysis only.');
}

class GeminiApiFailure extends Failure {
  const GeminiApiFailure(super.message);
}

class ReportValidationFailure extends Failure {
  const ReportValidationFailure(super.message);
}