import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../../models/app_log.dart';
import '../../state/app_controller.dart';

class LogsPage extends StatelessWidget {
  const LogsPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final logs = controller.recentLogs;
        final fmt = DateFormat('MM-dd HH:mm:ss');
        return CupertinoPageScaffold(
          navigationBar: const CupertinoNavigationBar(
            middle: Text('运行日志'),
          ),
          child: SafeArea(
            child: logs.isEmpty
                ? const Center(
                    child: Text(
                      '近 7 天暂无日志',
                      style: TextStyle(color: CupertinoColors.secondaryLabel),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => Container(
                      height: 0.5,
                      margin: const EdgeInsets.only(left: 16),
                      color: CupertinoColors.separator,
                    ),
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      final isError = log.level == AppLogLevel.error;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fmt.format(log.at),
                              style: const TextStyle(
                                fontSize: 12,
                                color: CupertinoColors.secondaryLabel,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              log.message,
                              style: TextStyle(
                                fontSize: 15,
                                color: isError
                                    ? CupertinoColors.destructiveRed
                                    : CupertinoColors.label,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}
