import 'dart:convert';

import 'package:compshare_manager/models/app_models.dart';
import 'package:compshare_manager/services/compshare_api_client.dart';
import 'package:compshare_manager/services/settings_store.dart';
import 'package:compshare_manager/state/app_controller.dart';
import 'package:compshare_manager/ui/pages/instances_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

http.Response jsonOk(Object data) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(data)),
    200,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppController controller;
  late List<Map<String, dynamic>> postedBodies;

  Future<void> buildController() async {
    SharedPreferences.setMockInitialValues({});
    postedBodies = [];
    final store = SettingsStore();
    await store.init();
    await store.saveCredentials(
      const ApiCredentials(publicKey: 'pk', privateKey: 'sk'),
    );
    final api = CompShareApiClient(
      credentials: const ApiCredentials(publicKey: 'pk', privateKey: 'sk'),
      poster: (url, {headers, body}) async {
        final payload = jsonDecode(body! as String) as Map<String, dynamic>;
        postedBodies.add(payload);
        final action = payload['Action'];
        if (action == 'DescribeCompShareInstance') {
          return jsonOk({
            'RetCode': 0,
            'UHostSet': [
              {
                'UHostId': 'uhost-a',
                'Name': '训练机 A',
                'State': 'Stopped',
                'Zone': 'cn-wlcb-01',
                'Region': 'cn-wlcb',
                'GPU': 1,
                'GpuType': '4090',
                'CPU': 16,
                'Memory': 65536,
                'SupportWithoutGpuStart': true,
              },
              {
                'UHostId': 'uhost-b',
                'Name': '训练机 B',
                'State': 'Running',
                'Zone': 'cn-wlcb-01',
                'Region': 'cn-wlcb',
                'GPU': 2,
                'GpuType': '4090',
                'CPU': 32,
                'Memory': 131072,
                'SupportWithoutGpuStart': false,
              },
            ],
          });
        }
        return jsonOk({'RetCode': 0, 'UHostId': payload['UHostId']});
      },
    );
    controller = AppController(api: api, store: store);
    await controller.bootstrap(enableBackgroundTasks: false);
  }

  tearDown(() {
    controller.dispose();
  });

  test('controller bootstrap loads instances from API', () async {
    await buildController();
    expect(controller.errorMessage, isNull, reason: '${controller.errorMessage}');
    expect(controller.instances, hasLength(2));
    expect(controller.credentials.isConfigured, isTrue);
  });

  testWidgets('lists instances and supports select all / start mode',
      (tester) async {
    await buildController();
    expect(controller.instances, hasLength(2));

    await tester.pumpWidget(
      CupertinoApp(home: InstancesPage(controller: controller)),
    );
    await tester.pump();

    expect(find.text('训练机 A'), findsOneWidget);
    expect(find.text('训练机 B'), findsOneWidget);
    expect(find.text('已关机'), findsOneWidget);
    expect(find.text('运行中'), findsOneWidget);

    await tester.tap(find.text('全选'));
    await tester.pump();
    expect(controller.selectedIds.length, 2);

    await tester.tap(find.text('无卡A'));
    await tester.pump();
    expect(controller.startMode, StartMode.noGpuA);

    await tester.tap(find.text('启动'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(controller.statusMessage, isNotNull);
    expect(
      postedBodies.any((e) => e['Action'] == 'StartCompShareInstance'),
      isTrue,
    );
    expect(
      postedBodies.any((e) => e['WithoutGpuSpec'] == 'A'),
      isTrue,
    );
    expect(controller.recentLogs, isNotEmpty);
    expect(controller.recentLogs.first.message, contains('启动'));
  });

  test('batch ops append logs in reverse chronological order', () async {
    await buildController();
    controller.toggleSelect('uhost-a');
    await controller.startSelected();
    controller.clearSelection();
    controller.toggleSelect('uhost-b');
    await controller.stopSelected();

    final logs = controller.recentLogs;
    expect(logs.length, greaterThanOrEqualTo(2));
    expect(logs.first.at.isAfter(logs[1].at) || logs.first.at.isAtSameMomentAs(logs[1].at), isTrue);
    expect(logs.first.message, contains('关闭'));
  });
}
