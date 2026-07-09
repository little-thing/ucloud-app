import 'package:compshare_manager/models/app_models.dart';
import 'package:compshare_manager/models/schedule_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScheduleRule', () {
    test('computeNextRun without lastRunAt picks next clock time', () {
      final rule = ScheduleRule(
        id: '1',
        enabled: true,
        intervalDays: 2,
        hour: 3,
        minute: 0,
        action: ScheduleAction.stop,
        instanceIds: const ['a'],
      );
      final from = DateTime(2026, 7, 9, 10, 0);
      final next = rule.computeNextRun(from: from);
      expect(next, DateTime(2026, 7, 10, 3, 0));
    });

    test('computeNextRun respects interval after lastRunAt', () {
      final rule = ScheduleRule(
        id: '1',
        enabled: true,
        intervalDays: 3,
        hour: 4,
        minute: 30,
        action: ScheduleAction.start,
        startMode: StartMode.noGpu,
        instanceIds: const ['a'],
        lastRunAt: DateTime(2026, 7, 9, 4, 30),
      );
      final next = rule.computeNextRun(from: DateTime(2026, 7, 9, 5, 0));
      expect(next, DateTime(2026, 7, 12, 4, 30));
    });

    test('isDue uses nextRunAt', () {
      final rule = ScheduleRule(
        id: '1',
        enabled: true,
        intervalDays: 1,
        hour: 1,
        minute: 0,
        action: ScheduleAction.stop,
        instanceIds: const ['a'],
        nextRunAt: DateTime(2026, 7, 9, 1, 0),
      );
      expect(rule.isDue(DateTime(2026, 7, 9, 1, 0)), isTrue);
      expect(rule.isDue(DateTime(2026, 7, 9, 0, 59)), isFalse);
    });

    test('json roundtrip keeps startMode', () {
      final rule = ScheduleRule(
        id: 'r1',
        enabled: true,
        intervalDays: 5,
        hour: 2,
        minute: 15,
        action: ScheduleAction.start,
        startMode: StartMode.noGpu,
        instanceIds: const ['u1', 'u2'],
        lastRunAt: DateTime(2026, 1, 1, 2, 15),
      );
      final decoded = ScheduleRule.decode(rule.encode());
      expect(decoded.id, 'r1');
      expect(decoded.intervalDays, 5);
      expect(decoded.action, ScheduleAction.start);
      expect(decoded.startMode, StartMode.noGpu);
      expect(decoded.instanceIds, ['u1', 'u2']);
      expect(decoded.lastRunAt, DateTime(2026, 1, 1, 2, 15));
      expect(decoded.actionDetailLabel, '启动（无卡模式）');
    });

    test('legacy reboot action maps to start', () {
      final decoded = ScheduleRule.fromJson({
        'id': 'old',
        'enabled': true,
        'intervalDays': 1,
        'hour': 3,
        'minute': 0,
        'action': 'reboot',
        'instanceIds': ['a'],
      });
      expect(decoded.action, ScheduleAction.start);
      expect(decoded.startMode, StartMode.normal);
    });
  });
}
