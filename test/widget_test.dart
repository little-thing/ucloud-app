import 'dart:convert';

import 'package:compshare_manager/models/app_models.dart';
import 'package:compshare_manager/models/schedule_rule.dart';
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

    await tester.tap(find.text('无卡'));
    await tester.pump();
    expect(controller.startMode, StartMode.noGpu);

    await tester.tap(find.text('启动'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(controller.statusMessage, isNotNull);
    expect(
      postedBodies.any((e) => e['Action'] == 'StartCompShareInstance'),
      isTrue,
    );
  });

  test('schedule rule due triggers stop', () async {
    await buildController();
    expect(controller.instances, isNotEmpty);
    controller.rules = [
      ScheduleRule(
        id: 'rule-1',
        enabled: true,
        intervalDays: 1,
        hour: 0,
        minute: 0,
        action: ScheduleAction.stop,
        instanceIds: const ['uhost-b'],
        nextRunAt: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
    ];
    await controller.tickSchedulesNow();
    expect(controller.statusMessage, contains('定时关闭'));
    expect(
      postedBodies.any((e) => e['Action'] == 'StopCompShareInstance'),
      isTrue,
    );
  });
}
