import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_models.dart';
import '../models/comp_share_instance.dart';
import '../models/schedule_rule.dart';
import '../services/compshare_api_client.dart';
import '../services/instance_batch_service.dart';
import '../services/settings_store.dart';

/// 应用状态：实例列表、多选、轮询、本地定时规则。
class AppController extends ChangeNotifier {
  AppController({
    required CompShareApiClient api,
    required SettingsStore store,
    InstanceBatchService? batch,
  })  : _api = api,
        _store = store,
        _batch = batch ?? InstanceBatchService(api);

  final CompShareApiClient _api;
  final SettingsStore _store;
  final InstanceBatchService _batch;

  List<CompShareInstance> instances = const [];
  final Set<String> selectedIds = {};
  List<ScheduleRule> rules = [];
  ApiCredentials credentials = const ApiCredentials(publicKey: '', privateKey: '');
  StartMode startMode = StartMode.normal;
  bool loading = false;
  bool operating = false;
  String? errorMessage;
  String? statusMessage;
  int pollSeconds = 4;
  DateTime? lastRefreshedAt;

  Timer? _pollTimer;
  Timer? _scheduleTimer;
  bool _busyRefresh = false;

  Future<void> bootstrap({bool enableBackgroundTasks = true}) async {
    credentials = await _store.loadCredentials();
    pollSeconds = await _store.loadPollSeconds();
    rules = await _store.loadRules();
    _api.updateCredentials(credentials);
    for (final rule in rules) {
      rule.nextRunAt ??= rule.computeNextRun();
    }
    await _store.saveRules(rules);
    notifyListeners();
    if (credentials.isConfigured) {
      await refreshInstances();
    }
    if (enableBackgroundTasks) {
      startPolling();
      startScheduleWatcher();
    }
  }

  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(Duration(seconds: pollSeconds), (_) {
      if (credentials.isConfigured && !operating) {
        unawaited(refreshInstances(silent: true));
      }
    });
  }

  void startScheduleWatcher() {
    _scheduleTimer?.cancel();
    _scheduleTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(_tickSchedules());
    });
  }

  Future<void> setPollSeconds(int seconds) async {
    pollSeconds = seconds.clamp(2, 30);
    await _store.savePollSeconds(pollSeconds);
    startPolling();
    notifyListeners();
  }

  Future<void> saveCredentials(ApiCredentials next) async {
    credentials = next;
    await _store.saveCredentials(next);
    _api.updateCredentials(next);
    errorMessage = null;
    notifyListeners();
    if (next.isConfigured) {
      await refreshInstances();
    }
  }

  Future<void> refreshInstances({bool silent = false}) async {
    if (_busyRefresh) return;
    if (!credentials.isConfigured) {
      errorMessage = '请先配置 API 密钥';
      notifyListeners();
      return;
    }
    _busyRefresh = true;
    if (!silent) {
      loading = true;
      notifyListeners();
    }
    try {
      final list = await _api.describeInstances(limit: 100, offset: 0);
      instances = list;
      selectedIds.removeWhere((id) => !list.any((e) => e.uHostId == id));
      lastRefreshedAt = DateTime.now();
      errorMessage = null;
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      loading = false;
      _busyRefresh = false;
      notifyListeners();
    }
  }

  List<CompShareInstance> get selectedInstances =>
      instances.where((e) => selectedIds.contains(e.uHostId)).toList();

  bool get allSelected =>
      instances.isNotEmpty && selectedIds.length == instances.length;

  void toggleSelect(String id) {
    if (selectedIds.contains(id)) {
      selectedIds.remove(id);
    } else {
      selectedIds.add(id);
    }
    notifyListeners();
  }

  void selectAll() {
    selectedIds
      ..clear()
      ..addAll(instances.map((e) => e.uHostId));
    notifyListeners();
  }

  void clearSelection() {
    selectedIds.clear();
    notifyListeners();
  }

  void setStartMode(StartMode mode) {
    startMode = mode;
    notifyListeners();
  }

  Future<BatchOpResult?> startSelected() =>
      _runBatch('启动', (list) => _batch.startMany(list, mode: startMode));

  Future<BatchOpResult?> stopSelected() =>
      _runBatch('关闭', _batch.stopMany);

  Future<BatchOpResult?> rebootSelected() =>
      _runBatch('重启', _batch.rebootMany);

  Future<BatchOpResult?> _runBatch(
    String label,
    Future<BatchOpResult> Function(List<CompShareInstance>) runner,
  ) async {
    final targets = selectedInstances;
    if (targets.isEmpty) {
      statusMessage = '请先选择实例';
      notifyListeners();
      return null;
    }
    operating = true;
    statusMessage = '正在$label ${targets.length} 台实例…';
    notifyListeners();
    try {
      final result = await runner(targets);
      statusMessage = result.summary(label);
      await refreshInstances(silent: true);
      return result;
    } catch (e) {
      errorMessage = e.toString();
      statusMessage = null;
      return null;
    } finally {
      operating = false;
      notifyListeners();
    }
  }

  Future<void> upsertRule(ScheduleRule rule) async {
    rule.nextRunAt = rule.computeNextRun();
    final idx = rules.indexWhere((e) => e.id == rule.id);
    if (idx >= 0) {
      rules[idx] = rule;
    } else {
      rules = [...rules, rule];
    }
    await _store.saveRules(rules);
    notifyListeners();
  }

  Future<void> deleteRule(String id) async {
    rules = rules.where((e) => e.id != id).toList();
    await _store.saveRules(rules);
    notifyListeners();
  }

  Future<void> _tickSchedules() async {
    if (!credentials.isConfigured || operating || instances.isEmpty) return;
    final now = DateTime.now();
    var changed = false;
    for (final rule in rules) {
      if (!rule.isDue(now)) continue;
      operating = true;
      statusMessage = '定时规则执行中：${rule.action.label}';
      notifyListeners();
      try {
        final result = await _batch.runSchedule(rule, instances);
        rule.lastRunAt = now;
        rule.nextRunAt = rule.computeNextRun(from: now);
        statusMessage =
            '定时${rule.actionDetailLabel}：${result.summary(rule.action.label)}';
        changed = true;
        await refreshInstances(silent: true);
      } catch (e) {
        errorMessage = '定时任务失败: $e';
      } finally {
        operating = false;
        notifyListeners();
      }
    }
    if (changed) {
      await _store.saveRules(rules);
      notifyListeners();
    }
  }

  /// 测试用：立即检查并执行到期规则。
  Future<void> tickSchedulesNow() => _tickSchedules();

  @override
  void dispose() {
    _pollTimer?.cancel();
    _scheduleTimer?.cancel();
    super.dispose();
  }
}
