import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../../models/schedule_rule.dart';
import '../../state/app_controller.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key, required this.controller});

  final AppController controller;

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: const Text('定时规则'),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _openEditor(context),
              child: const Icon(CupertinoIcons.add),
            ),
          ),
          child: SafeArea(
            child: controller.rules.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        '暂无规则\n可设置每 N 天自动批量重启或关闭',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: CupertinoColors.secondaryLabel,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: controller.rules.length,
                    itemBuilder: (context, index) {
                      final rule = controller.rules[index];
                      return _RuleTile(
                        rule: rule,
                        onTap: () => _openEditor(context, existing: rule),
                        onDelete: () => controller.deleteRule(rule.id),
                        onToggle: (enabled) async {
                          rule.enabled = enabled;
                          await controller.upsertRule(rule);
                        },
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  Future<void> _openEditor(
    BuildContext context, {
    ScheduleRule? existing,
  }) async {
    final result = await Navigator.of(context).push<ScheduleRule>(
      CupertinoPageRoute(
        builder: (_) => ScheduleEditorPage(
          controller: widget.controller,
          existing: existing,
        ),
      ),
    );
    if (result != null) {
      await widget.controller.upsertRule(result);
    }
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.rule,
    required this.onTap,
    required this.onDelete,
    required this.onToggle,
  });

  final ScheduleRule rule;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MM-dd HH:mm');
    final next = rule.nextRunAt;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x143C3C43)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '每 ${rule.intervalDays} 天 · ${rule.action.label} · ${rule.timeLabel}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                CupertinoSwitch(value: rule.enabled, onChanged: onToggle),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '实例 ${rule.instanceIds.length} 台'
              '${next == null ? '' : ' · 下次 ${fmt.format(next)}'}',
              style: const TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onDelete,
                child: const Text(
                  '删除',
                  style: TextStyle(color: CupertinoColors.destructiveRed),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScheduleEditorPage extends StatefulWidget {
  const ScheduleEditorPage({
    super.key,
    required this.controller,
    this.existing,
  });

  final AppController controller;
  final ScheduleRule? existing;

  @override
  State<ScheduleEditorPage> createState() => _ScheduleEditorPageState();
}

class _ScheduleEditorPageState extends State<ScheduleEditorPage> {
  late int _intervalDays;
  late ScheduleAction _action;
  late Set<String> _ids;
  late bool _enabled;
  late final TextEditingController _hourCtrl;
  late final TextEditingController _minuteCtrl;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _intervalDays = e?.intervalDays ?? 1;
    _action = e?.action ?? ScheduleAction.stop;
    _ids = {...?e?.instanceIds};
    _enabled = e?.enabled ?? true;
    _hourCtrl = TextEditingController(text: '${e?.hour ?? 3}');
    _minuteCtrl = TextEditingController(text: '${e?.minute ?? 0}');
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final instances = widget.controller.instances;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.existing == null ? '新建规则' : '编辑规则'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _save,
          child: const Text('保存'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              '启用',
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(child: Text('规则启用')),
                CupertinoSwitch(
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              '动作',
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 8),
            CupertinoSlidingSegmentedControl<ScheduleAction>(
              groupValue: _action,
              children: {
                for (final a in ScheduleAction.values)
                  a: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(a.label),
                  ),
              },
              onValueChanged: (v) {
                if (v != null) setState(() => _action = v);
              },
            ),
            const SizedBox(height: 16),
            const Text(
              '每 N 天',
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            Row(
              children: [
                CupertinoButton(
                  onPressed: () => setState(() {
                    _intervalDays = (_intervalDays - 1).clamp(1, 30);
                  }),
                  child: const Icon(CupertinoIcons.minus_circle),
                ),
                Text(
                  '$_intervalDays 天',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                CupertinoButton(
                  onPressed: () => setState(() {
                    _intervalDays = (_intervalDays + 1).clamp(1, 30);
                  }),
                  child: const Icon(CupertinoIcons.plus_circle),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '执行时刻',
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CupertinoTextField(
                    placeholder: '时',
                    keyboardType: TextInputType.number,
                    controller: _hourCtrl,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(':'),
                ),
                Expanded(
                  child: CupertinoTextField(
                    placeholder: '分',
                    keyboardType: TextInputType.number,
                    controller: _minuteCtrl,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              '选择实例',
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 8),
            if (instances.isEmpty)
              const Text(
                '暂无实例，请先在列表页刷新',
                style: TextStyle(color: CupertinoColors.secondaryLabel),
              )
            else
              ...instances.map((inst) {
                final selected = _ids.contains(inst.uHostId);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) {
                      _ids.remove(inst.uHostId);
                    } else {
                      _ids.add(inst.uHostId);
                    }
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom:
                            BorderSide(color: Color(0x143C3C43), width: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected
                              ? CupertinoIcons.checkmark_alt_circle_fill
                              : CupertinoIcons.circle,
                          color: selected
                              ? CupertinoColors.activeBlue
                              : CupertinoColors.systemGrey3,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            inst.name.isEmpty ? inst.uHostId : inst.name,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (_ids.isEmpty) {
      showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('请选择实例'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('好'),
            ),
          ],
        ),
      );
      return;
    }
    final hour = (int.tryParse(_hourCtrl.text) ?? 3).clamp(0, 23);
    final minute = (int.tryParse(_minuteCtrl.text) ?? 0).clamp(0, 59);
    final rule = ScheduleRule(
      id: widget.existing?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      enabled: _enabled,
      intervalDays: _intervalDays,
      hour: hour,
      minute: minute,
      action: _action,
      instanceIds: _ids.toList(),
      lastRunAt: widget.existing?.lastRunAt,
    );
    Navigator.pop(context, rule);
  }
}
