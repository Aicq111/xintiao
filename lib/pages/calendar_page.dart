// ============================================================
// 薪跳 · 日历页（排班切换 + 特殊日标记：加班/请假/调休）
// ============================================================
import 'package:flutter/material.dart';
import '../core/engine.dart';
import '../core/store.dart';
import '../core/theme.dart';

class CalendarPage extends StatefulWidget {
  final AppStore store;
  const CalendarPage({super.key, required this.store});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  String _key(int day) => '${_month.year}-${_month.month}-$day';

  void _prevMonth() => setState(() => _month = DateTime(_month.year, _month.month - 1, 1));
  void _nextMonth() => setState(() => _month = DateTime(_month.year, _month.month + 1, 1));

  void _openRotationEditor() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _RotationEditorSheet(store: widget.store),
    );
  }

  String _shiftLabel(Shift s) {
    if (s.name == '全天候') return '全天';
    return s.name.substring(0, 1);
  }

  int _defaultShiftIdx() {
    switch (widget.store.engineMode) {
      case ScheduleMode.nightShift:
        return 1;
      case ScheduleMode.threeShift:
        return 2;
      default:
        return 0;
    }
  }

  Future<void> _openDay(int day) async {
    final date = DateTime(_month.year, _month.month, day);
    final shift =
        shiftForDay(widget.store.engineMode, date, widget.store.cfg);
    final key = _key(day);
    final existing = widget.store.state.specials[key];
    final result = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _DaySheet(
        date: date,
        shift: shift,
        existing: existing,
        defaultShiftIdx: _defaultShiftIdx(),
      ),
    );
    if (result == null) return;
    if (result is String && result == 'clear') {
      widget.store.update((st) => st.specials.remove(key));
    } else if (result is SpecialDayData) {
      widget.store.update((st) => st.specials[key] = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final s = widget.store.state;
        final accent = Theme.of(context).colorScheme.primary;
        final dim = C.dim(context);
        final first = DateTime(_month.year, _month.month, 1);
        final offset = first.weekday - 1; // 0=周一
        final days = daysInMonth(_month.year, _month.month);
        final today = DateTime.now();

        // 本月实际计薪小时（含特殊日，不含倍率权重）
        var billableHours = 0.0;
        for (var d = 1; d <= days; d++) {
          final ivs = dayIntervals(
              DateTime(_month.year, _month.month, d),
              widget.store.engineMode,
              widget.store.engineSpecials,
              widget.store.cfg);
          for (final iv in ivs) {
            billableHours += (iv.endMinAbs - iv.startMinAbs) / 60.0;
          }
        }
        final specialCount = s.specials.keys
            .where((k) => k.startsWith('${_month.year}-${_month.month}-'))
            .length;

        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    const Text('日历 · 排班与特殊日',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    if (s.schedule.mode == 6)
                      GestureDetector(
                        onTap: _openRotationEditor,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: Text('编辑轮换',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: accent,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    Text('＋批量标记',
                        style: TextStyle(
                            fontSize: 12,
                            color: accent,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              SizedBox(
                height: 46,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                  itemCount: ScheduleData.modeNames.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final on = s.schedule.mode == i;
                    return GestureDetector(
                      onTap: () => widget.store
                          .update((st) => st.schedule = ScheduleData(mode: i)),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: on ? C.accentDim(context) : C.card(context),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: on ? accent : C.line(context)),
                        ),
                        child: Text(
                          ScheduleData.modeNames[i],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                on ? FontWeight.w700 : FontWeight.w400,
                            color: on ? accent : dim,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${_month.year} 年 ${_month.month} 月',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    Row(
                      children: [
                        GestureDetector(
                            onTap: _prevMonth,
                            child: Icon(Icons.chevron_left, color: dim)),
                        const SizedBox(width: 6),
                        GestureDetector(
                            onTap: _nextMonth,
                            child: Icon(Icons.chevron_right, color: dim)),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    for (final w in const ['一', '二', '三', '四', '五', '六', '日'])
                      Expanded(
                        child: Center(
                          child: Text(w,
                              style:
                                  TextStyle(fontSize: 12, color: dim)),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    for (var row = 0; row < 6; row++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            for (var col = 0; col < 7; col++) ...[
                              Expanded(
                                  child: _cell(context, offset, days,
                                      row * 7 + col, today, s)),
                              if (col != 6) const SizedBox(width: 4),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    _legend(context, '班次', accent),
                    _legend(context, '休', dim),
                    _legend(context, '加班 1.5×', C.gold(context)),
                    _legend(context, '加班 2×+', C.red(context)),
                    _legend(context, '请假', dim),
                    _legend(context, '调休', C.blue(context)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: C.card(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: C.line(context)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '本月计薪 ${billableHours.round()} 小时 · 特殊日 $specialCount 处\n按排班自动汇总 · 加班计入 / 请假调休扣除',
                          style: TextStyle(
                              fontSize: 12, color: dim, height: 1.6),
                        ),
                      ),
                      Text('节假日标注',
                          style: TextStyle(fontSize: 11, color: dim)),
                      const SizedBox(width: 6),
                      Switch(
                        value: s.holidayMark,
                        activeColor: accent,
                        onChanged: (v) =>
                            widget.store.update((st) => st.holidayMark = v),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _legend(BuildContext c, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11, color: C.dim(c))),
      ],
    );
  }

  Widget _cell(BuildContext c, int offset, int days, int idx, DateTime today,
      AppState s) {
    final dayNum = idx - offset + 1;
    if (dayNum < 1 || dayNum > days) return const SizedBox(height: 47);
    final date = DateTime(_month.year, _month.month, dayNum);
    final shift =
        shiftForDay(widget.store.engineMode, date, widget.store.cfg);
    final rest = shift == null;
    final label = rest ? '休' : _shiftLabel(shift!);
    final sp = s.specials[_key(dayNum)];
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final accent = Theme.of(c).colorScheme.primary;
    return GestureDetector(
      onTap: () => _openDay(dayNum),
      child: Container(
        height: 47,
        decoration: BoxDecoration(
          color: rest ? Colors.transparent : C.card(c),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isToday
                ? accent
                : (rest ? Colors.transparent : C.line(c)),
          ),
          boxShadow: isToday
              ? [BoxShadow(color: accent.withAlpha(60), blurRadius: 10)]
              : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$dayNum',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isToday ? FontWeight.w800 : FontWeight.w600,
                      color: rest ? C.dim(c) : null,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: rest ? C.dim(c) : accent,
                    ),
                  ),
                ],
              ),
            ),
            if (sp != null)
              Positioned(top: -5, right: -3, child: _badge(c, sp)),
          ],
        ),
      ),
    );
  }

  Widget _badge(BuildContext c, SpecialDayData sp) {
    Color fg, bg;
    String text;
    switch (sp.type) {
      case 'overtime':
        text = sp.mult <= 1.5
            ? '${sp.mult.toStringAsFixed(1)}×'
            : '${sp.mult.toStringAsFixed(1)}×';
        fg = sp.mult <= 1.5 ? C.gold(c) : C.red(c);
        bg = sp.mult <= 1.5 ? C.goldDim(c) : C.redDim(c);
        break;
      case 'leave':
        text = '假';
        fg = C.dim(c);
        bg = C.card(c);
        break;
      default:
        text = '调';
        fg = C.blue(c);
        bg = C.blueDim(c);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: C.line(c), width: 0.5),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

// ============================================================
// 特殊日编辑弹层
// ============================================================
class _DaySheet extends StatefulWidget {
  final DateTime date;
  final Shift? shift;
  final SpecialDayData? existing;
  final int defaultShiftIdx;
  const _DaySheet({
    required this.date,
    required this.shift,
    required this.existing,
    required this.defaultShiftIdx,
  });

  @override
  State<_DaySheet> createState() => _DaySheetState();
}

class _DaySheetState extends State<_DaySheet> {
  static const _wdNames = ['一', '二', '三', '四', '五', '六', '日'];

  late String _sel;
  late String _sub;
  late double _mult;
  int _hourStart = 14 * 60;
  int _hourEnd = 16 * 60;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _sel = e?.type ?? 'none';
    _mult = e?.mult ?? 1.5;
    _sub = _leaveSubOf(e);
  }

  String _leaveSubOf(SpecialDayData? d) {
    if (d == null) return '整天';
    if (d.leaveStart <= 0 && d.leaveEnd >= 1440) return '整天';
    if (d.leaveStart <= 0) return '上午';
    if (d.leaveEnd >= 1440) return '下午';
    return '小时';
  }

  SpecialDayData _build() {
    switch (_sel) {
      case 'overtime':
        return SpecialDayData(
            type: 'overtime', mult: _mult, shiftIdx: widget.defaultShiftIdx);
      case 'leave':
        int s2, e2;
        switch (_sub) {
          case '整天':
            s2 = 0;
            e2 = 1440;
            break;
          case '上午':
            s2 = 0;
            e2 = 12 * 60;
            break;
          case '下午':
            s2 = 12 * 60;
            e2 = 1440;
            break;
          default:
            s2 = _hourStart;
            e2 = _hourEnd;
        }
        return SpecialDayData(type: 'leave', leaveStart: s2, leaveEnd: e2);
      default:
        return SpecialDayData(type: 'off');
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final init = TimeOfDay(
        hour: (isStart ? _hourStart : _hourEnd) ~/ 60,
        minute: (isStart ? _hourStart : _hourEnd) % 60);
    final picked = await showTimePicker(context: context, initialTime: init);
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _hourStart = picked.hour * 60 + picked.minute;
      } else {
        _hourEnd = picked.hour * 60 + picked.minute;
      }
    });
  }

  String _fmtMin(int m) {
    final h = m ~/ 60, mm = m % 60;
    return '${h.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final dim = C.dim(context);
    final shift = widget.shift;
    final shiftName = shift?.name ?? '休息日';
    final rest = shift == null;

    return Padding(
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          Text(
            '${widget.date.month}月${widget.date.day}日 · 周${_wdNames[widget.date.weekday - 1]} · $shiftName',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.line(context)),
            ),
            child: Row(
              children: [
                _info(context, '班次', shiftName),
                _info(context, '计薪',
                    shift == null ? '0 小时' : '${shift.billableMinutes ~/ 60} 小时'),
                _info(context, '时间',
                    shift == null ? '—' : '${_fmtMin(shift.startMin)}–${_fmtMin(shift.endMin % 1440)}${shift.endMin > 1440 ? '(跨天)' : ''}'),
                _info(context, '休息',
                    shift == null || shift.breaks.isEmpty
                        ? '无'
                        : shift.breaks
                            .map((b) => '${_fmtMin(b.startMin)}–${_fmtMin(b.endMin)}')
                            .join(' ')),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text('标记这一天', style: TextStyle(fontSize: 12, color: dim)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(context, '按排班', 'none', accent),
              _chip(context, '加班 1.0×', 'overtime', C.gold(context),
                  mult: 1.0),
              _chip(context, '加班 1.5×', 'overtime', C.gold(context),
                  mult: 1.5),
              _chip(context, '加班 2.0×', 'overtime', C.red(context),
                  mult: 2.0),
              _chip(context, '自定义倍率', 'overtime', C.red(context),
                  custom: true),
              _chip(context, '请假', 'leave', accent),
              _chip(context, '调休', 'off', C.blue(context)),
            ],
          ),
          if (_sel == 'overtime') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text('倍率 ${_mult.toStringAsFixed(1)}×',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                Expanded(
                  child: Slider(
                    value: _mult,
                    min: 1.0,
                    max: 3.0,
                    divisions: 20,
                    activeColor: accent,
                    onChanged: (v) => setState(() => _mult = v),
                  ),
                ),
              ],
            ),
            if (rest)
              Text(
                '📋 今天是休息日，工作时段将复制「白班」8:00–17:00（含午休）',
                style: TextStyle(fontSize: 11, color: C.gold(context)),
              ),
          ],
          if (_sel == 'leave') ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                _subChip(context, '整天', '整天'),
                _subChip(context, '上午', '上午'),
                _subChip(context, '下午', '下午'),
                _subChip(context, '小时', '小时'),
              ],
            ),
            if (_sub == '小时') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  OutlinedButton(
                      onPressed: () => _pickTime(true),
                      child: Text('开始 ${_fmtMin(_hourStart)}')),
                  const SizedBox(width: 10),
                  OutlinedButton(
                      onPressed: () => _pickTime(false),
                      child: Text('结束 ${_fmtMin(_hourEnd)}')),
                ],
              ),
            ],
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (widget.existing != null) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, 'clear'),
                    child: const Text('清除标记'),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 2,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: const Color(0xFF06231A)),
                  onPressed: () => Navigator.pop(context, _build()),
                  child: const Text('完成',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _info(BuildContext c, String k, String v) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: TextStyle(fontSize: 10, color: C.dim(c))),
          const SizedBox(height: 2),
          Text(v,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _chip(BuildContext c, String label, String value, Color color,
      {double? mult, bool custom = false}) {
    // 1.0/1.5/2.0 对应 mult 匹配；自定义对应非预设值
    final matchMult = mult == null || (_sel == 'overtime' && _mult == mult);
    final onReal = _sel == value && matchMult && !custom;
    final selected = custom
        ? (_sel == 'overtime' && !(_mult == 1.0 || _mult == 1.5 || _mult == 2.0))
        : onReal;
    return GestureDetector(
      onTap: () => setState(() {
        _sel = value;
        if (mult != null) _mult = mult;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(30) : Theme.of(c).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? color : C.line(c)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? color : C.dim(c))),
      ),
    );
  }

  Widget _subChip(BuildContext c, String label, String value) {
    final on = _sub == value;
    final accent = Theme.of(c).colorScheme.primary;
    return GestureDetector(
      onTap: () => setState(() => _sub = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: on ? accent.withAlpha(30) : Theme.of(c).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: on ? accent : C.line(c)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                color: on ? accent : C.dim(c))),
      ),
    );
  }
}

// ============================================================
// 自定义轮换排班编辑器（按月轮换 + 每班固定休息日 = 上六休一）
// ============================================================
class _DraftShift {
  String name;
  int start;
  int end;
  int rest;
  _DraftShift(this.name, this.start, this.end, this.rest);
}

class _RotationEditorSheet extends StatefulWidget {
  final AppStore store;
  const _RotationEditorSheet({required this.store});

  @override
  State<_RotationEditorSheet> createState() => _RotationEditorSheetState();
}

class _RotationEditorSheetState extends State<_RotationEditorSheet> {
  static const _wdNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  late List<_DraftShift> _shifts;
  late int _startIdx;

  @override
  void initState() {
    super.initState();
    final sched = widget.store.state.schedule;
    final src = sched.rotationShifts.isEmpty
        ? ScheduleData.defaultRotationShifts
        : sched.rotationShifts;
    _shifts = src
        .map((e) => _DraftShift(e.name, e.startMin, e.endMin, e.restWeekday))
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
                      .add(_DraftShift('新班次', 8 * 60, 17 * 60, 5))),
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
