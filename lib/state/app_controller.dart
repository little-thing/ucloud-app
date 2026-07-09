import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_log.dart';
import '../models/app_models.dart';
import '../models/comp_share_instance.dart';
import '../services/compshare_api_client.dart';
import '../services/instance_batch_service.dart';
import '../services/settings_store.dart';

/// 应用状态：实例列表、多选、轮询、运行日志。
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
  List<AppLog> logs = [];
  ApiCredentials credentials = const ApiCredentials(publicKey: '', privateKey: '');
  StartMode startMode = StartMode.normal;
  bool loading = false;
  bool operating = false;
  String? errorMessage;
  String? statusMessage;
  int pollSeconds = 4;
  DateTime? lastRefreshedAt;

  Timer? _pollTimer;
  bool _busyRefresh = false;

  Future<void> bootstrap({bool enableBackgroundTasks = true}) async {
    credentials = await _store.loadCredentials();
    pollSeconds = await _store.loadPollSeconds();
    logs = await _store.loadLogs();
    _api.updateCredentials(credentials);
    notifyListeners();
    if (credentials.isConfigured) {
      await refreshInstances();
    }
    if (enableBackgroundTasks) {
      startPolling();
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
    await _appendLog('已更新 API 密钥配置');
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
      if (!silent) {
        await _appendLog('刷新实例列表：${list.length} 台');
      }
    } catch (e) {
      errorMessage = e.toString();
      await _appendLog('刷新实例失败：$e', level: AppLogLevel.error);
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

  /// 近 7 天日志，按时间倒序。
  List<AppLog> get recentLogs {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final filtered = logs.where((e) => e.at.isAfter(cutoff)).toList();
    filtered.sort((a, b) => b.at.compareTo(a.at));
    return filtered;
  }

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
      await _appendLog(
        '$label ${targets.length} 台：${result.summary(label)}'
        '${startMode.isWithoutGpu && label == '启动' ? '（${startMode.label}）' : ''}',
      );
      await refreshInstances(silent: true);
      return result;
    } catch (e) {
      errorMessage = e.toString();
      statusMessage = null;
      await _appendLog('$label失败：$e', level: AppLogLevel.error);
      return null;
    } finally {
      operating = false;
      notifyListeners();
    }
  }

  Future<void> _appendLog(
    String message, {
    AppLogLevel level = AppLogLevel.info,
  }) async {
    final entry = AppLog(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      at: DateTime.now(),
      message: message,
      level: level,
    );
    logs = [entry, ...logs];
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    logs = logs.where((e) => e.at.isAfter(cutoff)).toList();
    await _store.saveLogs(logs);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
