import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../../state/app_controller.dart';
import '../widgets/batch_toolbar.dart';
import '../widgets/instance_row.dart';
import 'schedule_page.dart';
import 'settings_page.dart';

class InstancesPage extends StatelessWidget {
  const InstancesPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final fmt = DateFormat('HH:mm:ss');
        final refreshed = controller.lastRefreshedAt;
        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: const Text('优云智算'),
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => SchedulePage(controller: controller),
                  ),
                );
              },
              child: const Icon(CupertinoIcons.clock),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: controller.loading
                      ? null
                      : () => controller.refreshInstances(),
                  child: controller.loading
                      ? const CupertinoActivityIndicator()
                      : const Icon(CupertinoIcons.refresh),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => SettingsPage(controller: controller),
                      ),
                    );
                  },
                  child: const Icon(CupertinoIcons.settings),
                ),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                BatchToolbar(
                  selectedCount: controller.selectedIds.length,
                  allSelected: controller.allSelected,
                  startMode: controller.startMode,
                  operating: controller.operating,
                  onSelectAll: controller.selectAll,
                  onClear: controller.clearSelection,
                  onStartModeChanged: controller.setStartMode,
                  onStart: () => controller.startSelected(),
                  onStop: () => controller.stopSelected(),
                  onReboot: () => controller.rebootSelected(),
                ),
                if (controller.statusMessage != null ||
                    controller.errorMessage != null ||
                    refreshed != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: const Color(0xFFF2F2F7),
                    child: Text(
                      [
                        if (controller.errorMessage != null)
                          controller.errorMessage!,
                        if (controller.statusMessage != null)
                          controller.statusMessage!,
                        if (refreshed != null)
                          '状态更新 ${fmt.format(refreshed)} · 每 ${controller.pollSeconds}s',
                      ].join('\n'),
                      style: TextStyle(
                        fontSize: 12,
                        color: controller.errorMessage != null
                            ? CupertinoColors.destructiveRed
                            : CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ),
                Expanded(child: _buildBody(context)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    if (!controller.credentials.isConfigured) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.lock_shield,
                size: 48,
                color: CupertinoColors.systemGrey,
              ),
              const SizedBox(height: 12),
              const Text(
                '先配置 CompShare API 密钥',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                '控制台 → 账户中心 → API 密钥',
                style: TextStyle(color: CupertinoColors.secondaryLabel),
              ),
              const SizedBox(height: 16),
              CupertinoButton.filled(
                onPressed: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => SettingsPage(controller: controller),
                    ),
                  );
                },
                child: const Text('去设置'),
              ),
            ],
          ),
        ),
      );
    }

    if (controller.loading && controller.instances.isEmpty) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (controller.instances.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '暂无实例',
              style: TextStyle(color: CupertinoColors.secondaryLabel),
            ),
            CupertinoButton(
              onPressed: () => controller.refreshInstances(),
              child: const Text('重新加载'),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: () => controller.refreshInstances(),
        ),
        SliverList.builder(
          itemCount: controller.instances.length,
          itemBuilder: (context, index) {
            final inst = controller.instances[index];
            return InstanceRow(
              instance: inst,
              selected: controller.selectedIds.contains(inst.uHostId),
              onToggle: () => controller.toggleSelect(inst.uHostId),
            );
          },
        ),
      ],
    );
  }
}
