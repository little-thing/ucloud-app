import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_models.dart';
import '../models/schedule_rule.dart';

class SettingsStore {
  SettingsStore({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  static const _kPublicKey = 'public_key';
  static const _kPrivateKey = 'private_key';
  static const _kRegion = 'region';
  static const _kBaseUrl = 'base_url';
  static const _kRules = 'schedule_rules';
  static const _kPollSeconds = 'poll_seconds';

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get prefs {
    final p = _prefs;
    if (p == null) {
      throw StateError('SettingsStore 未初始化');
    }
    return p;
  }

  Future<ApiCredentials> loadCredentials() async {
    await init();
    return ApiCredentials(
      publicKey: prefs.getString(_kPublicKey) ?? '',
      privateKey: prefs.getString(_kPrivateKey) ?? '',
      region: prefs.getString(_kRegion) ?? 'cn-wlcb',
      baseUrl: prefs.getString(_kBaseUrl) ?? 'https://api.compshare.cn',
    );
  }

  Future<void> saveCredentials(ApiCredentials credentials) async {
    await init();
    await prefs.setString(_kPublicKey, credentials.publicKey.trim());
    await prefs.setString(_kPrivateKey, credentials.privateKey.trim());
    await prefs.setString(_kRegion, credentials.region.trim());
    await prefs.setString(_kBaseUrl, credentials.baseUrl.trim());
  }

  Future<int> loadPollSeconds() async {
    await init();
    return prefs.getInt(_kPollSeconds) ?? 4;
  }

  Future<void> savePollSeconds(int seconds) async {
    await init();
    await prefs.setInt(_kPollSeconds, seconds.clamp(2, 30));
  }

  Future<List<ScheduleRule>> loadRules() async {
    await init();
    final raw = prefs.getStringList(_kRules) ?? const [];
    return raw.map(ScheduleRule.decode).toList();
  }

  Future<void> saveRules(List<ScheduleRule> rules) async {
    await init();
    await prefs.setStringList(
      _kRules,
      rules.map((e) => e.encode()).toList(),
    );
  }

  /// 测试辅助：直接写入 JSON 列表。
  Future<void> saveRulesRaw(List<Map<String, dynamic>> rules) async {
    await init();
    await prefs.setStringList(
      _kRules,
      rules.map(jsonEncode).toList(),
    );
  }
}
