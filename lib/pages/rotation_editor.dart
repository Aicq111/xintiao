// ============================================================
// 自定义轮换排班编辑器（按月轮换 + 每班固定休息日 = 上六休一）
// 公共组件：日历页与设置页共用
// ============================================================
import 'package:flutter/material.dart';
import '../core/engine.dart';
import '../core/store.dart';
import '../core/theme.dart';

/// 打开轮换排班编辑器（底部弹层）
Future<void> openRotationEditor(BuildContext context, AppStore store) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: C.card(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => RotationEditorSheet(store: store),
  );
}

// 自定义轮换排班编辑器（按月轮换 + 每班固定休息日 = 上六休一）
// ============================================================
class ShiftDraft {
  String name;
  int start;
  int end;
  int rest;
  ShiftDraft(this.name, this.start, this.end, this.rest);
}

class RotationEditorSheet extends StatefulWidget {
  final AppStore store;
  const RotationEditorSheet({required this.store});

  @override
  State<RotationEditorSheet> createState() => RotationEditorSheetState();
}

class RotationEditorSheetState extends State<RotationEditorSheet> {
  static const _wdNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  late List<ShiftDraft> _shifts;
  late int _startIdx;

  @override
  void initState() {
    super.initState();
    final sched = widget.store.state.schedule;
    final src = sched.rotationShifts.isEmpty
        ? ScheduleData.defaultRotationShifts
        : sched.rotationShifts;
    _shifts = src
        .map((e) => ShiftDraft(e.name, e.startMin, e.endMin, e.restWeekday))
        .toList();
    _startIdx =
        sched.rotationStartIdx.clamp(0, _shifts.length - 1).toInt();
  }

  String _fmt(int m) {
    final h = m ~/ 60, mm = m % 60;
    return '${h.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
  }

  Future<void> _pick(int idx, bool isStart) async {
    final d = _shifts[idx];
    final initMin = isStart ? d.start : d.end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initMin ~/ 60, minute: initMin % 60),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _shifts[idx].start = picked.hour * 60 + picked.minute;
      } else {
        _shifts[idx].end = picked.hour * 60 + picked.minute;
      }
    });
  }

  void _save() {
    final now = DateTime.now();
    widget.store.update((st) {
      st.schedule = ScheduleData(
        mode: 6,
        rotationShifts: _shifts
            .map((x) => ShiftDef(
                  name: x.name,
                  startMin: x.start,
                  endMin: x.end,
                  breaks: x.name == '白班'
                      ? const [BreakRange(12 * 60, 13 * 60)]
                      : const [],
                  restWeekday: x.rest,
                ))
            .toList(),
        rotationAnchorYear: now.year,
        rotationAnchorMonth: now.month,
        rotationStartIdx: _startIdx,
      );
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final dim = C.dim(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: C.line(context), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),
          const Text('自定义轮换排班',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('按月轮换班次，每个班次可设固定休息日（上六休一）',
              style: TextStyle(fontSize: 11, color: dim)),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: [
                for (var i = 0; i < _shifts.length; i++) _shiftCard(i),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _shifts
                      .add(ShiftDraft('新班次', 8 * 60, 17 * 60, 5))),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加班次'),
                ),
                const SizedBox(height: 14),
                Text('本月是哪个班次',
                    style: TextStyle(fontSize: 12, color: dim)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (var i = 0; i < _shifts.length; i++)
                      GestureDetector(
                        onTap: () => setState(() => _startIdx = i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: _startIdx == i
                                ? C.accentDim(context)
                                : Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color:
                                    _startIdx == i ? accent : C.line(context)),
                          ),
                          child: Text(_shifts[i].name,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _startIdx == i
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: _startIdx == i ? accent : dim)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('轮换规则：每月 1 号自动切换到下一个班次（本月设为白班 → 下个月中班 → 再下个月夜班 → 循环）',
                    style: TextStyle(fontSize: 11, color: dim, height: 1.6)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: const Color(0xFF06231A)),
              onPressed: _save,
              child: const Text('保存排班',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shiftCard(int i) {
    final d = _shifts[i];
    final accent = Theme.of(context).colorScheme.primary;
    final dim = C.dim(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.line(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 110,
                child: TextFormField(
                  initialValue: d.name,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                      isDense: true, border: InputBorder.none),
                  onChanged: (v) => setState(() => d.name = v),
                ),
              ),
              const Spacer(),
              if (_shifts.length > 1)
                IconButton(
                  icon: Icon(Icons.delete_outline, color: C.red(context)),
                  onPressed: () => setState(() {
                    _shifts.removeAt(i);
                    if (_startIdx >= _shifts.length) {
                      _startIdx = _shifts.length - 1;
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => _pick(i, true),
                child: Text('上班 ${_fmt(d.start)}',
                    style: const TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _pick(i, false),
                child: Text('下班 ${_fmt(d.end)}',
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('休息日', style: TextStyle(fontSize: 12, color: dim)),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: d.rest,
                underline: const SizedBox(),
                style: TextStyle(fontSize: 13, color: accent),
                items: [
                  for (var w = 0; w < 7; w++)
                    DropdownMenuItem(value: w, child: Text(_wdNames[w])),
                ],
                onChanged: (v) => setState(() => d.rest = v ?? d.rest),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


