import 'dart:io';

import 'package:compshare_manager/models/app_models.dart';
import 'package:compshare_manager/services/compshare_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// 真实 API 冒烟：设置环境变量 COMPSHARE_PUBLIC_KEY / COMPSHARE_PRIVATE_KEY 后执行。
void main() {
  test('live DescribeCompShareInstance', () async {
    final publicKey = Platform.environment['COMPSHARE_PUBLIC_KEY'] ?? '';
    final privateKey = Platform.environment['COMPSHARE_PRIVATE_KEY'] ?? '';
    if (publicKey.isEmpty || privateKey.isEmpty) {
      // ignore: avoid_print
      print('skip live API: credentials env not set');
      return;
    }
    final client = CompShareApiClient(
      credentials: ApiCredentials(
        publicKey: publicKey,
        privateKey: privateKey,
      ),
    );
    final list = await client.describeInstances(limit: 10);
    expect(list, isNotEmpty);
    for (final inst in list) {
      expect(inst.uHostId, startsWith('uhost-'));
      expect(inst.state, isNotEmpty);
      expect(inst.zone, isNotEmpty);
    }
  }, timeout: const Timeout(Duration(seconds: 30)));
}
