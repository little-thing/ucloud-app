import 'package:flutter/cupertino.dart';

import 'models/app_models.dart';
import 'services/compshare_api_client.dart';
import 'services/settings_store.dart';
import 'state/app_controller.dart';
import 'ui/pages/instances_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = SettingsStore();
  await store.init();
  final credentials = await store.loadCredentials();
  final api = CompShareApiClient(credentials: credentials);
  final controller = AppController(api: api, store: store);
  await controller.bootstrap();
  runApp(CompShareApp(controller: controller));
}

class CompShareApp extends StatelessWidget {
  const CompShareApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: '优云智算',
      debugShowCheckedModeBanner: false,
      theme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: CupertinoColors.activeBlue,
        barBackgroundColor: Color(0xF0F9F9F9),
        scaffoldBackgroundColor: CupertinoColors.systemBackground,
        textTheme: CupertinoTextThemeData(
          navTitleTextStyle: TextStyle(
            fontFamily: '.SF Pro Text',
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.label,
          ),
          textStyle: TextStyle(
            fontFamily: '.SF Pro Text',
            fontSize: 16,
            color: CupertinoColors.label,
          ),
        ),
      ),
      home: InstancesPage(controller: controller),
    );
  }
}

/// 测试 / 预览入口：注入已构造好的 controller。
class CompShareAppHarness extends StatelessWidget {
  const CompShareAppHarness({
    super.key,
    required this.controller,
  });

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return CompShareApp(controller: controller);
  }
}

/// 便于测试构造空凭证客户端。
CompShareApiClient createDefaultApi() {
  return CompShareApiClient(
    credentials: const ApiCredentials(publicKey: '', privateKey: ''),
  );
}
