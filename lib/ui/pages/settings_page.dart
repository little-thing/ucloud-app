import 'package:flutter/cupertino.dart';

import '../../models/app_models.dart';
import '../../state/app_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _publicKey;
  late final TextEditingController _privateKey;
  late final TextEditingController _region;
  late final TextEditingController _baseUrl;
  late int _pollSeconds;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.controller.credentials;
    _publicKey = TextEditingController(text: c.publicKey);
    _privateKey = TextEditingController(text: c.privateKey);
    _region = TextEditingController(text: c.region);
    _baseUrl = TextEditingController(text: c.baseUrl);
    _pollSeconds = widget.controller.pollSeconds;
  }

  @override
  void dispose() {
    _publicKey.dispose();
    _privateKey.dispose();
    _region.dispose();
    _baseUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('设置'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _saving ? null : _save,
          child: _saving
              ? const CupertinoActivityIndicator()
              : const Text('保存'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'API 密钥',
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: _publicKey,
              placeholder: 'PublicKey',
              padding: const EdgeInsets.all(12),
            ),
            const SizedBox(height: 10),
            CupertinoTextField(
              controller: _privateKey,
              placeholder: 'PrivateKey',
              obscureText: true,
              padding: const EdgeInsets.all(12),
            ),
            const SizedBox(height: 16),
            const Text(
              '地域 / 网关',
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: _region,
              placeholder: 'Region，如 cn-wlcb',
              padding: const EdgeInsets.all(12),
            ),
            const SizedBox(height: 10),
            CupertinoTextField(
              controller: _baseUrl,
              placeholder: 'https://api.compshare.cn',
              padding: const EdgeInsets.all(12),
            ),
            const SizedBox(height: 20),
            const Text(
              '状态刷新间隔（秒）',
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            Row(
              children: [
                CupertinoButton(
                  onPressed: () => setState(() {
                    _pollSeconds = (_pollSeconds - 1).clamp(2, 30);
                  }),
                  child: const Icon(CupertinoIcons.minus_circle),
                ),
                Text(
                  '$_pollSeconds',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                CupertinoButton(
                  onPressed: () => setState(() {
                    _pollSeconds = (_pollSeconds + 1).clamp(2, 30);
                  }),
                  child: const Icon(CupertinoIcons.plus_circle),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '密钥保存在本机 SharedPreferences，仅自用。\n'
              '定时规则依赖 App 进程存活：退出或被系统杀掉后不会执行；'
              'Mac 保持开着更稳，iOS 后台不可靠。',
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.controller.saveCredentials(
        ApiCredentials(
          publicKey: _publicKey.text.trim(),
          privateKey: _privateKey.text.trim(),
          region: _region.text.trim().isEmpty ? 'cn-wlcb' : _region.text.trim(),
          baseUrl: _baseUrl.text.trim().isEmpty
              ? 'https://api.compshare.cn'
              : _baseUrl.text.trim(),
        ),
      );
      await widget.controller.setPollSeconds(_pollSeconds);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
