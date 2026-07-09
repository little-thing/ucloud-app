class CompShareApiException implements Exception {
  CompShareApiException({
    required this.message,
    this.retCode,
    this.action,
  });

  final String message;
  final int? retCode;
  final String? action;

  @override
  String toString() {
    if (retCode == null) return message;
    return '[$retCode] $message';
  }
}
