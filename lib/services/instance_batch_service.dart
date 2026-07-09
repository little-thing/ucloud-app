import '../models/app_models.dart';
import '../models/comp_share_instance.dart';
import '../models/schedule_rule.dart';
import 'api_exception.dart';
import 'compshare_api_client.dart';

/// 批量启停编排。
///
/// 启动：仅 `Stopped` 会真正开机；已 `Running` 等状态记为跳过。
/// 关闭：仅 `Running` 会关机；其余跳过。
class InstanceBatchService {
  InstanceBatchService(this._api);

  final CompShareApiClient _api;

  Future<BatchOpResult> startMany(
    List<CompShareInstance> instances, {
    required StartMode mode,
  }) async {
    final succeeded = <String>[];
    final skipped = <String>[];
    final failed = <({String id, String reason})>[];

    for (final inst in instances) {
      if (!inst.canStart) {
        skipped.add(inst.uHostId);
        continue;
      }
      if (mode.withoutGpu && !inst.supportWithoutGpuStart) {
        failed.add((id: inst.uHostId, reason: '不支持无卡启动'));
        continue;
      }
      try {
        await _api.startInstance(
          zone: inst.zone,
          uHostId: inst.uHostId,
          withoutGpu: mode.withoutGpu,
        );
        succeeded.add(inst.uHostId);
      } on CompShareApiException catch (e) {
        failed.add((id: inst.uHostId, reason: e.toString()));
      } catch (e) {
        failed.add((id: inst.uHostId, reason: e.toString()));
      }
    }

    return BatchOpResult(
      succeeded: succeeded,
      skipped: skipped,
      failed: failed,
    );
  }

  Future<BatchOpResult> stopMany(List<CompShareInstance> instances) async {
    final succeeded = <String>[];
    final skipped = <String>[];
    final failed = <({String id, String reason})>[];

    for (final inst in instances) {
      if (!inst.canStop) {
        skipped.add(inst.uHostId);
        continue;
      }
      try {
        await _api.stopInstance(
          zone: inst.zone,
          uHostId: inst.uHostId,
          force: inst.isSpot,
        );
        succeeded.add(inst.uHostId);
      } on CompShareApiException catch (e) {
        failed.add((id: inst.uHostId, reason: e.toString()));
      } catch (e) {
        failed.add((id: inst.uHostId, reason: e.toString()));
      }
    }

    return BatchOpResult(
      succeeded: succeeded,
      skipped: skipped,
      failed: failed,
    );
  }

  Future<BatchOpResult> runSchedule(
    ScheduleRule rule,
    List<CompShareInstance> allInstances,
  ) async {
    final targets = allInstances
        .where((e) => rule.instanceIds.contains(e.uHostId))
        .toList();
    return switch (rule.action) {
      ScheduleAction.start => startMany(targets, mode: rule.startMode),
      ScheduleAction.stop => stopMany(targets),
    };
  }

  Future<BatchOpResult> rebootMany(List<CompShareInstance> instances) async {
    final succeeded = <String>[];
    final skipped = <String>[];
    final failed = <({String id, String reason})>[];

    for (final inst in instances) {
      if (!inst.canReboot) {
        skipped.add(inst.uHostId);
        continue;
      }
      try {
        await _api.rebootInstance(zone: inst.zone, uHostId: inst.uHostId);
        succeeded.add(inst.uHostId);
      } on CompShareApiException catch (e) {
        failed.add((id: inst.uHostId, reason: e.toString()));
      } catch (e) {
        failed.add((id: inst.uHostId, reason: e.toString()));
      }
    }

    return BatchOpResult(
      succeeded: succeeded,
      skipped: skipped,
      failed: failed,
    );
  }
}
