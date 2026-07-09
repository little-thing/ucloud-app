import 'dart:convert';

import 'app_models.dart';

/// 本地「每 N 天」批量操作规则：启动或关闭。
enum ScheduleAction {
  start,
  stop;

  String get label => switch (this) {
        ScheduleAction.start => '启动',
        ScheduleAction.stop => '关闭',
      };

  static ScheduleAction fromName(String name) {
    // 兼容旧版「重启」规则，按启动处理。
    if (name == 'reboot') return ScheduleAction.start;
    return ScheduleAction.values.firstWhere(
      (e) => e.name == name,
      orElse: () => ScheduleAction.stop,
    );
  }
}

class ScheduleRule {
  ScheduleRule({
    required this.id,
    required this.enabled,
    required this.intervalDays,
    required this.hour,
    required this.minute,
    required this.action,
    required this.instanceIds,
    this.startMode = StartMode.normal,
    this.lastRunAt,
    this.nextRunAt,
  });

  final String id;
  bool enabled;
  int intervalDays;
  int hour;
  int minute;
  ScheduleAction action;

  /// 仅 `action == start` 时生效：正常 / 无卡。
  StartMode startMode;
  List<String> instanceIds;
  DateTime? lastRunAt;
  DateTime? nextRunAt;

  String get timeLabel {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get actionDetailLabel {
    if (action == ScheduleAction.start) {
      return '${action.label}（${startMode.label}）';
    }
    return action.label;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'enabled': enabled,
        'intervalDays': intervalDays,
        'hour': hour,
        'minute': minute,
        'action': action.name,
        'startMode': startMode.name,
        'instanceIds': instanceIds,
        'lastRunAt': lastRunAt?.toIso8601String(),
        'nextRunAt': nextRunAt?.toIso8601String(),
      };

  factory ScheduleRule.fromJson(Map<String, dynamic> json) {
    return ScheduleRule(
      id: (json['id'] ?? '').toString(),
      enabled: json['enabled'] == true,
      intervalDays: (json['intervalDays'] as num?)?.toInt() ?? 1,
      hour: (json['hour'] as num?)?.toInt() ?? 3,
      minute: (json['minute'] as num?)?.toInt() ?? 0,
      action: ScheduleAction.fromName((json['action'] ?? 'stop').toString()),
      startMode: StartMode.fromName((json['startMode'] ?? 'normal').toString()),
      instanceIds: ((json['instanceIds'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      lastRunAt: json['lastRunAt'] == null
          ? null
          : DateTime.tryParse(json['lastRunAt'].toString()),
      nextRunAt: json['nextRunAt'] == null
          ? null
          : DateTime.tryParse(json['nextRunAt'].toString()),
    );
  }

  String encode() => jsonEncode(toJson());

  static ScheduleRule decode(String raw) =>
      ScheduleRule.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  /// 根据上次执行时间与间隔，计算下一次应执行时刻。
  DateTime computeNextRun({DateTime? from}) {
    final now = from ?? DateTime.now();
    var candidate = DateTime(now.year, now.month, now.day, hour, minute);
    if (lastRunAt == null) {
      if (!candidate.isAfter(now)) {
        candidate = candidate.add(const Duration(days: 1));
      }
      return candidate;
    }
    final earliest = lastRunAt!.add(Duration(days: intervalDays));
    while (!candidate.isAfter(now) || candidate.isBefore(earliest)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  bool isDue(DateTime now) {
    if (!enabled || instanceIds.isEmpty) return false;
    final next = nextRunAt ?? computeNextRun(from: now);
    return !next.isAfter(now);
  }
}
