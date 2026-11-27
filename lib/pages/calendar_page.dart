// ============================================================
// 薪跳 · 日历页（排班切换 + 特殊日标记：加班/请假/调休）
// ============================================================
import 'package:flutter/material.dart';
import '../core/engine.dart';
import '../core/holidays.dart';
import '../core/ocr_service.dart';
import 'rotation_editor.dart';
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

  // 汇总缓存：月度计薪小时数只在月/模式/特殊日变化时重算
  String _sumKey = '';
  double _billableHours = 0;
  int _specialCount = 0;
  bool _ocrBusy = false;

  void _recalcSummary(AppState s) {
    final buf = StringBuffer(
        '${_month.year}-${_month.month}-${s.schedule.mode}-');
    final keys = s.specials.keys.toList()..sort();
    for (final k in keys) {
      final v = s.specials[k]!;
      buf.write('$k:${v.type}:${v.mult}:${v.leaveStart}-${v.leaveEnd};');
    }
    final key = buf.toString();
    if (key == _sumKey) return;
    _sumKey = key;
    var hours = 0.0;
    final days = daysInMonth(_month.year, _month.month);
    for (var d = 1; d <= days; d++) {
      final ivs = dayIntervals(DateTime(_month.year, _month.month, d),
          widget.store.engineMode, widget.store.engineSpecials,
          widget.store.cfg);
      for (final iv in ivs) {
        hours += (iv.endMinAbs - iv.startMinAbs) / 60.0;
      }
    }
    _billableHours = hours;
    _specialCount = s.specials.keys
        .where((k) => k.startsWith('${_month.year}-${_month.month}-'))
        .length;
  }

  String _key(int day) => '${_month.year}-${_month.month}-$day';

  static String _modeHint(int mode) {
    switch (mode) {
      case 0:
        return '全天候：每天 24 小时计薪，适合副业/理财';
      case 1:
        return '长白班：周一至周五 8:00–17:00（午休 1 小时），周末休息';
      case 2:
        return '长夜班：周一至周五 20:00–次日 6:00（宵夜 1 小时），周末休息';
      case 3:
        return '两班倒：按周轮换白班/夜班，周末休息';
      case 4:
        return '三班倒：早/中/晚按天循环，周末休息';
      case 5:
        return '自定义：同长白班（后续可改班次时间）';
      case 6:
        return '自定义轮换：按月轮换班次，每个班次有固定休息日（上六休一）→ 点右上角「编辑轮换」设置';
      default:
        return '';
    }
  }

  void _prevMonth() => setState(() => _month = DateTime(_month.year, _month.month - 1, 1));
  void _nextMonth() => setState(() => _month = DateTime(_month.year, _month.month + 1, 1));

  void _openRotationEditor() => openRotationEditor(context, widget.store);

  Future<void> _openOcrFlow() async {
    if (_ocrBusy) return;
    _ocrBusy = true;
    setState(() {});
    try {
      final lines = await OcrService.pickAndRecognize();
      if (!mounted) return;
      if (lines.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('未识别到文字，请换一张更清晰的截图')));
        return;
      }
      final pairs = OcrService.parse(lines);
      if (!mounted) return;
      if (pairs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('未能解析出排班，请尝试更清晰的截图（或手动标记）')));
        return;
      }
      final applied = await showModalBottomSheet<Map<int, String>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: C.card(context),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => _OcrPreviewSheet(pairs: pairs, month: _month),
      );
      if (applied == null || applied.isEmpty) return;
      widget.store.update((st) {
        for (final e in applied.entries) {
          final k = '${_month.year}-${_month.month}-${e.key}';
          if (e.value == '休') {
            st.specials[k] = SpecialDayData(type: 'rest');
          } else {
            st.specials[k] = SpecialDayData(
                type: 'shift', shiftIdx: OcrService.labelToShiftIdx(e.value));
          }
        }
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('已应用 ${applied.length} 天排班，可点日期查看/修改')));
    } finally {
      _ocrBusy = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _openBatchSheet() async {
    final result = await showModalBottomSheet<_BatchResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _BatchSheet(month: _month),
    );
    if (result == null) return;
    widget.store.update((st) {
      for (var d = result.from; d <= result.to; d++) {
        final k = '${_month.year}-${_month.month}-$d';
        switch (result.type) {
          case 'clear':
            st.specials.remove(k);
            break;
          case 'off':
            st.specials[k] = SpecialDayData(type: 'off');
            break;
          case 'rest':
            st.specials[k] = SpecialDayData(type: 'rest');
            break;
          case 'overtime':
            st.specials[k] = SpecialDayData(
                type: 'overtime', mult: result.mult, shiftIdx: _defaultShiftIdx());
            break;
          case 'leave':
            st.specials[k] =
                SpecialDayData(type: 'leave', leaveStart: 0, leaveEnd: 1440);
            break;
        }
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('已批量标记 ${result.from}–${result.to} 日')));
    }
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
    final dayMillis = widget.store.engineIncomes.fold<int>(
        0,
        (a, b) =>
            a +
            accumulate(
                year: date.year,
                month: date.month,
                fromDay: date.day,
                toDay: date.day,
                mode: widget.store.engineMode,
                specials: widget.store.engineSpecials,
                income: b,
                cfg: widget.store.cfg));
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
        dayMillis: dayMillis,
        isHoliday: widget.store.state.holidayMark && Holidays.isHoliday(date),
        isMakeup: widget.store.state.holidayMark && Holidays.isMakeup(date),
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

        // 本月实际计薪小时（缓存重算，避免每次构建全月区间计算）
        _recalcSummary(s);

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).scaffoldBackgroundColor,
                C.card(context).withAlpha(70),
              ],
            ),
          ),
          child: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (details) {
              final v = details.primaryVelocity ?? 0;
              if (v < -200) {
                _nextMonth();
              } else if (v > 200) {
                _prevMonth();
              }
            },
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
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    _actionChip(context, accent,
                        Icons.document_scanner_outlined,
                        _ocrBusy ? '识别中…' : '识别排班',
                        _ocrBusy ? null : _openOcrFlow),
                    if (s.schedule.mode == 6) ...[
                      const SizedBox(width: 8),
                      _actionChip(context, accent, Icons.tune, '编辑轮换',
                          _openRotationEditor),
                    ],
                    const SizedBox(width: 8),
                    _actionChip(context, accent, Icons.event_repeat,
                        '批量标记', _openBatchSheet),
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
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                child: Text(
                  _modeHint(s.schedule.mode),
                  style: TextStyle(fontSize: 11, color: dim, height: 1.5),
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
                          '本月计薪 ${_billableHours.round()} 小时 · 特殊日 $_specialCount 处\n按排班自动汇总 · 加班计入 / 请假调休扣除',
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
          ),
        ),
        );
      },
    );
  }

  Widget _actionChip(BuildContext c, Color accent, IconData icon, String label,
      VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: C.accentDim(c),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withAlpha(140)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: accent),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: accent,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
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
    if (dayNum < 1 || dayNum > days) return const SizedBox(height: 49);
    final date = DateTime(_month.year, _month.month, dayNum);
    final sp = s.specials[_key(dayNum)];
    var effShift =
        shiftForDay(widget.store.engineMode, date, widget.store.cfg);
    if (sp != null && sp.type == 'shift') {
      effShift = SpecialDayData.presetShifts[sp.shiftIdx]; // 排班覆盖
    }
    final rest = effShift == null;
    final label = rest ? '休' : _shiftLabel(effShift!);
    // 节假日标注：法定假日显示「节」（金色），调休上班日蓝底
    final isHoliday = s.holidayMark && Holidays.isHoliday(date);
    final isMakeup = s.holidayMark && Holidays.isMakeup(date);
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final accent = Theme.of(c).colorScheme.primary;
    // 特殊日整格填色：一眼分辨 加班(金) / 请假(灰) / 调休(蓝) / 排班覆盖(蓝)
    Color? spColor;
    Color? spBg;
    String? spLabel;
    if (sp != null) {
      switch (sp.type) {
        case 'overtime':
          spColor = C.gold(c);
          spBg = C.goldDim(c);
          spLabel = '${sp.mult.toStringAsFixed(1)}×';
          break;
        case 'leave':
          spColor = C.dim(c);
          spBg = C.card(c);
          spLabel = '假';
          break;
        case 'off':
          spColor = C.blue(c);
          spBg = C.blueDim(c);
          spLabel = '调';
          break;
        case 'shift':
          spColor = C.blue(c);
          spBg = C.blueDim(c);
          spLabel =
              SpecialDayData.presetShifts[sp.shiftIdx].name.substring(0, 1);
          break;
        default:
          break; // rest：与普通休息日一致
      }
    }
    final cellBorder = isToday
        ? accent
        : (spColor ?? (rest ? Colors.transparent : C.line(c)));
    var cellBg = spBg ?? (rest ? C.card(c).withAlpha(46) : C.card(c));
    var showLabel = spLabel ?? label;
    var labelColor = spColor ?? (rest ? C.dim(c) : accent);
    // 节假日/调休上班日视觉
    if (sp == null && isHoliday) {
      cellBg = C.goldDim(c);
      showLabel = '节';
      labelColor = C.gold(c);
    } else if (sp == null && isMakeup) {
      cellBg = C.blueDim(c);
      labelColor = C.blue(c);
    }
    final dayColor = rest ? C.dim(c) : null;
    return GestureDetector(
      onTap: () => _openDay(dayNum),
      child: Container(
        height: 49,
        decoration: BoxDecoration(
          color: cellBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: cellBorder,
            width: (isToday || spColor != null) ? 1.4 : 0.8,
          ),
          boxShadow: isToday
              ? [BoxShadow(color: accent.withAlpha(50), blurRadius: 10)]
              : null,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$dayNum',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      isToday ? FontWeight.w800 : FontWeight.w600,
                  color: dayColor,
                ),
              ),
              Text(
                showLabel,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: labelColor,
                ),
              ),
            ],
          ),
        ),
      ),
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
  final int dayMillis;
  final bool isHoliday;
  final bool isMakeup;
  const _DaySheet({
    required this.date,
    required this.shift,
    required this.existing,
    required this.defaultShiftIdx,
    required this.dayMillis,
    required this.isHoliday,
    required this.isMakeup,
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
    // 休息日加班默认倍率：法定假日 3×、周末 2×、工作日 1.5×
    _mult = e?.mult ??
        (widget.shift == null
            ? (widget.isHoliday ? 3.0 : 2.0)
            : 1.5);
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
              color: C.accentDim(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withAlpha(120)),
            ),
            child: Row(
              children: [
                Icon(Icons.payments_outlined, size: 16, color: accent),
                const SizedBox(width: 6),
                Text('当日预计收入',
                    style: TextStyle(fontSize: 12, color: C.dim(context))),
                const Spacer(),
                Text(
                  '¥ ${(widget.dayMillis / 10000).toStringAsFixed(2)} 元',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: accent,
                      fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ],
            ),
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
              _chip(context, '加班 3.0×', 'overtime', C.red(context),
                  mult: 3.0),
              _chip(context, '自定义倍率', 'overtime', C.red(context),
                  custom: true),
              _chip(context, '请假', 'leave', accent),
              _chip(context, '调休', 'off', C.blue(context)),
            ],
          ),
          if (_sel == 'overtime' && (widget.isHoliday || widget.isMakeup)) ...[
            const SizedBox(height: 6),
            Text(
              widget.isHoliday
                  ? '🏮 今日是法定节假日：按 3 倍工资计'
                  : '📅 今日是调休上班日：按公司规定计',
              style: TextStyle(
                  fontSize: 11,
                  color: C.gold(context),
                  fontWeight: FontWeight.w600),
            ),
          ],
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
// ============================================================
// OCR 识别结果预览（逐条修正后应用）
// ============================================================
class _OcrPreviewSheet extends StatefulWidget {
  final Map<int, String> pairs;
  final DateTime month;
  const _OcrPreviewSheet({required this.pairs, required this.month});

  @override
  State<_OcrPreviewSheet> createState() => _OcrPreviewSheetState();
}

class _OcrPreviewSheetState extends State<_OcrPreviewSheet> {
  static const _labels = ['白班', '中班', '晚班', '夜班', '早班', '休'];
  late Map<int, String> _sel;

  @override
  void initState() {
    super.initState();
    _sel = Map.of(widget.pairs);
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final days = _sel.keys.toList()..sort();
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
          const Text('识别结果预览',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('共识别 ' + days.length.toString() + ' 天，可逐条修正后应用（识别可能有误，请核对）',
              style: TextStyle(fontSize: 11, color: C.dim(context))),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: [
                for (final d in days)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: C.line(context)),
                    ),
                    child: Row(
                      children: [
                        Text(widget.month.month.toString() + '月' + d.toString() + '日',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        DropdownButton<String>(
                          value: _labels.contains(_sel[d]) ? _sel[d] : '休',
                          underline: const SizedBox(),
                          style: TextStyle(fontSize: 13, color: accent),
                          items: [
                            for (final l in _labels)
                              DropdownMenuItem(value: l, child: Text(l)),
                            const DropdownMenuItem(
                                value: '_remove',
                                child: Text('移除',
                                    style: TextStyle(
                                        color: Color(0xFFF87171)))),
                          ],
                          onChanged: (v) => setState(() {
                            if (v == '_remove') {
                              _sel.remove(d);
                            } else if (v != null) {
                              _sel[d] = v;
                            }
                          }),
                        ),
                      ],
                    ),
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
              onPressed: () =>
                  Navigator.pop(context, Map<int, String>.of(_sel)),
              child: Text('应用 ' + _sel.length.toString() + ' 天排班',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}


// ============================================================
// 批量标记弹层
// ============================================================
class _BatchResult {
  final String type;
  final double mult;
  final int from;
  final int to;
  _BatchResult(this.type, this.mult, this.from, this.to);
}

class _BatchSheet extends StatefulWidget {
  final DateTime month;
  const _BatchSheet({required this.month});

  @override
  State<_BatchSheet> createState() => _BatchSheetState();
}

class _BatchSheetState extends State<_BatchSheet> {
  String _type = 'overtime';
  double _mult = 1.5;
  int _from = 1;
  int _to = 1;

  Future<void> _pick(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(widget.month.year, widget.month.month,
          (isFrom ? _from : _to).clamp(1, 28).toInt()),
      firstDate: DateTime(widget.month.year, widget.month.month, 1),
      lastDate: DateTime(widget.month.year, widget.month.month, 28),
      helpText: isFrom ? '选择起始日' : '选择结束日',
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked.day;
        if (_to < _from) _to = _from;
      } else {
        _to = picked.day;
        if (_from > _to) _from = _to;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final dim = C.dim(context);
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
          const Text('批量标记',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(' 年  月 · 选择类型和日期范围，一次应用到多天',
              style: TextStyle(fontSize: 11, color: dim)),
          const SizedBox(height: 14),
          Text('标记类型', style: TextStyle(fontSize: 12, color: dim)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _bChip('加班 1.5×', 'overtime', 1.5),
              _bChip('加班 2.0×', 'overtime', 2.0),
              _bChip('加班 3.0×', 'overtime', 3.0),
              _bChip('请假（整天）', 'leave', 1.0),
              _bChip('调休', 'off', 1.0),
              _bChip('清除标记', 'clear', 1.0),
            ],
          ),
          const SizedBox(height: 16),
          Text('日期范围', style: TextStyle(fontSize: 12, color: dim)),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton(
                  onPressed: () => _pick(true),
                  child: Text('起始  日')),
              const SizedBox(width: 8),
              OutlinedButton(
                  onPressed: () => _pick(false),
                  child: Text('结束  日')),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: const Color(0xFF06231A)),
              onPressed: () => Navigator.pop(
                  context, _BatchResult(_type, _mult, _from, _to)),
              child: Text('应用  天',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bChip(String label, String type, double mult) {
    final on = _type == type && (type != 'overtime' || _mult == mult);
    final accent = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: () => setState(() {
        _type = type;
        _mult = mult;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: on ? C.accentDim(context) : Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: on ? accent : C.line(context)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                color: on ? accent : C.dim(context))),
      ),
    );
  }
}
