import 'package:flutter/cupertino.dart';

import '../../models/comp_share_instance.dart';

Color stateColor(String state) {
  switch (state) {
    case 'Running':
      return const Color(0xFF34C759);
    case 'Stopped':
      return const Color(0xFF8E8E93);
    case 'Starting':
    case 'Rebooting':
      return const Color(0xFF007AFF);
    case 'Stopping':
      return const Color(0xFFFF9500);
    default:
      return const Color(0xFFAF52DE);
  }
}

String stateLabel(String state) {
  switch (state) {
    case 'Running':
      return '运行中';
    case 'Stopped':
      return '已关机';
    case 'Starting':
      return '启动中';
    case 'Stopping':
      return '关机中';
    case 'Rebooting':
      return '重启中';
    case 'Install':
      return '安装中';
    default:
      return state;
  }
}

class InstanceRow extends StatelessWidget {
  const InstanceRow({
    super.key,
    required this.instance,
    required this.selected,
    required this.onToggle,
  });

  final CompShareInstance instance;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final color = stateColor(instance.state);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0x143C3C43), width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                selected
                    ? CupertinoIcons.checkmark_alt_circle_fill
                    : CupertinoIcons.circle,
                color: selected
                    ? CupertinoColors.activeBlue
                    : CupertinoColors.systemGrey3,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          instance.name.isEmpty ? instance.uHostId : instance.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          stateLabel(instance.state),
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    instance.uHostId,
                    style: const TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${instance.displayGpu} · CPU ${instance.cpu} · ${instance.memoryGb} · ${instance.zone}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                  if (instance.supportWithoutGpuStart) ...[
                    const SizedBox(height: 4),
                    const Text(
                      '支持无卡启动',
                      style: TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.activeBlue,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
