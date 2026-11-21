// ============================================================
// 标准排班模式的工作时间编辑器（长白班/长夜班/两班倒/三班倒/自定义）
// ============================================================
import 'package:flutter/material.dart';
import '../core/engine.dart';
import '../core/store.dart';
import '../core/theme.dart';

/// 打开某模式的工作时间编辑器（底部弹层）
Future<void> openModeShiftEditor(BuildContext context, AppStore store, int mode) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: C.card(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => ModeShiftEditorSheet(store: store, mode: mode),
  );
}

class _ModeDraft {
  String name;
  int start;
  int end;
  bool hasBreak;
  int bStart;
  int bEnd;
  _ModeDraft(this.name, this.start, this.end, this.hasBreak, this.bStart, this.bEnd);
}

class ModeShiftEditorSheet extends StatefulWidget {
  final AppStore store;
  final int mode;
  const ModeShiftEditorSheet({super.key, required this.store, required this.mode});

  @override
  State<ModeShiftEditorSheet> createState() => _ModeShiftEditorSheetState();
}

class _ModeShiftEditorSheetState extends State<ModeShiftEditorSheet> {
  late List<_ModeDraft> _shifts;

  static const _modeShiftNames = {
    1: ['白班'],
    2: ['夜班'],
    3: ['白班', '夜班'],
    4: ['早班', '中班', '晚班'],
    5: ['白班'],
  };

  static _ModeDraft _seed(String name) {
    switch (name) {
      case '白班':
        return _ModeDraft('白班', 8 * 60, 17 * 60, true, 12 * 60, 13 * 60);
      case '夜班':
        return _ModeDraft('夜班', 20 * 60, 30 * 60, true, 24 * 60, 25 * 60);
      case '早班':
        return _ModeDraft('早班', 0, 8 * 60, false, 0, 0);
      case '中班':
        return _ModeDraft('中班', 8 * 60, 16 * 60, false, 0, 0);
      case '晚班':
        return _ModeDraft('晚班', 16 * 60, 24 * 60, false, 0, 0);
      default:
        return _ModeDraft('白班', 8 * 60, 17 * 60, true, 12 * 60, 13 * 60);
    }
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.store.state.schedule.modeShifts[widget.mode];
    if (existing != null && existing.isNotEmpty) {
      _shifts = existing
          .map((e) => _ModeDraft(
                e.name,
                e.startMin,
                e.endMin,
                e.breaks.isNotEmpty,
                e.breaks.isNotEmpty ? e.breaks.first.startMin : 0,
                e.breaks.isNotEmpty ? e.breaks.first.endMin : 0,
              ))
          .toList();
    } else {
      _shifts = _modeShiftNames[widget.mode]!
          .map((n) => _seed(n))
          .toList();
    }
  }

  String _fmt(int m) {
    final h = m ~/ 60, mm = m % 60;
    return '${h.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
  }

  Future<void> _pick(int idx, int which) async {
    final d = _shifts[idx];
    final initMin = which == 0
        ? d.start
        : (which == 1
            ? d.end
            : (which == 2 ? d.bStart : d.bEnd));
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initMin ~/ 60, minute: initMin % 60),
    );
    if (picked == null) return;
    final v = picked.hour * 60 + picked.minute;
    setState(() {
      switch (which) {
        case 0:
          d.start = v;
          break;
        case 1:
          d.end = v;
          break;
        case 2:
          d.bStart = v;
          break;
        case 3:
          d.bEnd = v;
          break;
      }
    });
  }

  void _save() {
    widget.store.update((st) {
      final map = Map<int, List<ShiftDef>>.from(st.schedule.modeShifts);
      map[widget.mode] = _shifts
          .map((x) => ShiftDef(
                name: x.name,
                startMin: x.start,
                endMin: x.end,
                breaks: x.hasBreak
                    ? [BreakRange(x.bStart, x.bEnd)]
                    : const [],
                restWeekday: -1,
              ))
          .toList();
      final sch = st.schedule;
      st.schedule = ScheduleData(
        mode: sch.mode,
        rotationShifts: sch.rotationShifts,
        rotationAnchorYear: sch.rotationAnchorYear,
        rotationAnchorMonth: sch.rotationAnchorMonth,
        rotationStartIdx: sch.rotationStartIdx,
        modeShifts: map,
      );
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final dim = C.dim(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
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
          Text('编辑工作时间 · ${ScheduleData.modeNames[widget.mode]}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('工厂时长不固定？按实际上下班时间修改，工资按真实时长计算',
              style: TextStyle(fontSize: 11, color: dim)),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: [
                for (var i = 0; i < _shifts.length; i++) _shiftCard(i),
                const SizedBox(height: 6),
                Text(
                  widget.mode == 3
                      ? '两班倒：白班/夜班按周轮换'
                      : (widget.mode == 4
                          ? '三班倒：早/中/晚按天循环'
                          : ''),
                  style: TextStyle(fontSize: 11, color: dim),
                ),
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
              child: const Text('保存工作时间',
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
          Text(d.name,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => _pick(i, 0),
                child: Text('上班 ${_fmt(d.start)}',
                    style: const TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _pick(i, 1),
                child: Text('下班 ${_fmt(d.end)}',
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Switch(
                value: d.hasBreak,
                activeColor: accent,
                onChanged: (v) => setState(() => d.hasBreak = v),
              ),
              Text('中间休息', style: TextStyle(fontSize: 12, color: dim)),
              if (d.hasBreak) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _pick(i, 2),
                  child: Text('休起 ${_fmt(d.bStart)}',
                      style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _pick(i, 3),
                  child: Text('休止 ${_fmt(d.bEnd)}',
                      style: const TextStyle(fontSize: 12)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
