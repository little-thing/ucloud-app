import 'package:flutter/cupertino.dart';

import '../../models/app_models.dart';

class BatchToolbar extends StatelessWidget {
  const BatchToolbar({
    super.key,
    required this.selectedCount,
    required this.allSelected,
    required this.startMode,
    required this.operating,
    required this.onSelectAll,
    required this.onClear,
    required this.onStartModeChanged,
    required this.onStart,
    required this.onStop,
    required this.onReboot,
  });

  final int selectedCount;
  final bool allSelected;
  final StartMode startMode;
  final bool operating;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final ValueChanged<StartMode> onStartModeChanged;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onReboot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF2F2F7),
        border: Border(
          bottom: BorderSide(color: Color(0x143C3C43), width: 0.5),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                onPressed: operating
                    ? null
                    : (allSelected ? onClear : onSelectAll),
                child: Text(allSelected ? '取消全选' : '全选'),
              ),
              Text(
                '已选 $selectedCount',
                style: const TextStyle(
                  fontSize: 14,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
              const Spacer(),
              const Text(
                '启动模式',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
              const SizedBox(width: 8),
              CupertinoSlidingSegmentedControl<StartMode>(
                groupValue: startMode,
                children: {
                  for (final mode in StartMode.values)
                    mode: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        switch (mode) {
                          StartMode.normal => '正常',
                          StartMode.noGpuA => '无卡A',
                          StartMode.noGpuB => '无卡B',
                        },
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                },
                onValueChanged: (value) {
                  if (value != null) onStartModeChanged(value);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: CupertinoButton.filled(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  onPressed: operating || selectedCount == 0 ? null : onStart,
                  child: const Text('启动'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  color: CupertinoColors.systemOrange,
                  onPressed: operating || selectedCount == 0 ? null : onStop,
                  child: const Text(
                    '关闭',
                    style: TextStyle(color: CupertinoColors.white),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  color: CupertinoColors.systemGrey,
                  onPressed: operating || selectedCount == 0 ? null : onReboot,
                  child: const Text(
                    '重启',
                    style: TextStyle(color: CupertinoColors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
