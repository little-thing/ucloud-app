import 'dart:convert';

/// 应用运行日志条目。
class AppLog {
  AppLog({
    required this.id,
    required this.at,
    required this.message,
    this.level = AppLogLevel.info,
  });

  final String id;
  final DateTime at;
  final String message;
  final AppLogLevel level;

  Map<String, dynamic> toJson() => {
        'id': id,
        'at': at.toIso8601String(),
        'message': message,
        'level': level.name,
      };

  factory AppLog.fromJson(Map<String, dynamic> json) {
    return AppLog(
      id: (json['id'] ?? '').toString(),
      at: DateTime.tryParse((json['at'] ?? '').toString()) ?? DateTime.now(),
      message: (json['message'] ?? '').toString(),
      level: AppLogLevel.fromName((json['level'] ?? 'info').toString()),
    );
  }

  String encode() => jsonEncode(toJson());

  static AppLog decode(String raw) =>
      AppLog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

enum AppLogLevel {
  info,
  error;

  static AppLogLevel fromName(String name) {
    return AppLogLevel.values.firstWhere(
      (e) => e.name == name,
      orElse: () => AppLogLevel.info,
    );
  }
}
