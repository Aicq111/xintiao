// ============================================================
// 薪跳 · 主页（实时增长 + 汇总/单份切换 + 主题跟随 + 系统字体）
// ============================================================
import 'dart:async';
import 'package:flutter/material.dart';
import '../core/engine.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/widget_bridge.dart';

class HomePage extends StatefulWidget {
  final AppStore store;
  const HomePage({super.key, required this.store});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? _timer;
  DateTime _now = DateTime.now();
  int _viewIdx = 0; // 0 = 全部收入汇总，1..n = 单份
  int _tickNum = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _tick();
    });
    // 启动后先推一次小组件数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetBridge.push(widget.store, _now);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    setState(() => _now = DateTime.now());
    // 每 30 秒同步一次小组件数据（系统对小组件刷新有节流）
    _tickNum++;
    if (_tickNum % 30 == 0) {
      WidgetBridge.push(widget.store, _now);
    }
  }

  int _valueOf(Income inc) => accumulateSince(
        start: inc.startDay,
        now: _now,
        mode: widget.store.engineMode,
        specials: widget.store.engineSpecials,
        income: inc,
      );

  int _todayOf(Income inc) => accumulate(
        year: _now.year,
        month: _now.month,
        fromDay: _now.day,
        toDay: _now.day,
        mode: widget.store.engineMode,
        specials: widget.store.engineSpecials,
        income: inc,
        endMinute: _now.hour * 60 + _now.minute + _now.second / 60,
      );

  String get _status {
    final day = DateTime(_now.year, _now.month, _now.day);
    final shift = shiftForDay(widget.store.engineMode, day);
    if (shift == null) return '今日休息';
    final nowMin = _now.hour * 60 + _now.minute + _now.second / 60;
    if (nowMin >= shift.endMin) return '已下班';
    if (nowMin < shift.startMin) return '未上班';
    final inBreak =
        shift.breaks.any((b) => nowMin >= b.startMin && nowMin < b.endMin);
    return inBreak ? '休息中' : '上班中';
  }

  bool get _working => _status == '上班中';

  String _dur(double secs) {
    final s = secs.floor();
    final h = s ~/ 3600, m = (s % 3600) ~/ 60, ss = s % 60;
    String p(int n) => n.toString().padLeft(2, '0');
    return '$h:${p(m)}:${p(ss)}';
  }

  String get _workText {
    final day = DateTime(_now.year, _now.month, _now.day);
    final shift = shiftForDay(widget.store.engineMode, day);
    if (shift == null) return '今日休息';
    if (_status == '已下班') {
      final h = shift.billableMinutes ~/ 60;
      final m = shift.billableMinutes % 60;
      return '已下班 · 今日计薪 $h 小时 ${m.toString().padLeft(2, '0')} 分';
    }
    final worked = todayWorkSeconds(
        now: _now, mode: widget.store.engineMode, specials: widget.store.engineSpecials);
    var left = shift.endMin -
        (_now.hour * 60 + _now.minute + _now.second / 60);
    if (left < 0) left = 0;
    return '已工作 ${_dur(worked)} · 距下班 ${_dur(left * 60)}';
  }

  int _daysToPayday(AppState s) {
    DateTime target(int y, int m) {
      if (s.payRule == 'lastWorkday') {
        var d = DateTime(y, m + 1, 0);
        while (d.weekday >= 6) {
          d = d.subtract(const Duration(days: 1));
        }
        return d;
      }
      return DateTime(y, m, s.payDay.clamp(1, 28).toInt());
    }

    final today = DateTime(_now.year, _now.month, _now.day);
    var t = target(_now.year, _now.month);
    if (!t.isAfter(today)) t = target(_now.year, _now.month + 1);
    return t.difference(today).inDays;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final s = widget.store.state;
        final accent = Theme.of(context).colorScheme.primary;
        final dim = C.dim(context);
        final incomes = widget.store.engineIncomes;
        final total = incomes.fold<int>(0, (a, b) => a + _valueOf(b));
        final today = incomes.fold<int>(0, (a, b) => a + _todayOf(b));
        final monthStart = DateTime(_now.year, _now.month, 1);
        final monthTotal = incomes.fold<int>(
            0, (a, b) => a + _valueOf(b.copyWithStart(monthStart)));

        final viewName =
            _viewIdx == 0 ? '全部收入' : incomes[_viewIdx - 1].name;
        final viewValue = _viewIdx == 0
            ? total
            : _valueOf(incomes[_viewIdx - 1]);

        final rate = currentRateMillisPerSec(
          now: _now,
          mode: widget.store.engineMode,
          specials: widget.store.engineSpecials,
          incomes: incomes,
        );
        final shift = shiftForDay(
            widget.store.engineMode, DateTime(_now.year, _now.month, _now.day));
        final spToday =
            s.specials['${_now.year}-${_now.month}-${_now.day}'];

        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('薪跳',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                    Text('📅   ⚙️',
                        style: TextStyle(fontSize: 16, color: dim)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    const SizedBox(height: 24),
                    Text('当前累计 · $viewName（点数字切换）',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: dim)),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => setState(() {
                        _viewIdx = (_viewIdx + 1) % (incomes.length + 1);
                      }),
                      child: Text(
                        '¥ ${s.formatMoney(viewValue)} 元',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w700,
                          color: accent,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          shadows: [
                            Shadow(
                                color: accent.withAlpha(90), blurRadius: 34),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _working ? accent : dim,
                            boxShadow: _working
                                ? [
                                    BoxShadow(
                                        color: accent.withAlpha(120),
                                        blurRadius: 8),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$_status · +${(rate / 100).toStringAsFixed(2)}厘/秒',
                          style: const TextStyle(
                              fontSize: 14, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _workText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: dim,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _badge(context, '距发薪 ${_daysToPayday(s)} 天',
                            C.gold(context), C.goldDim(context)),
                        if (shift != null) ...[
                          const SizedBox(width: 8),
                          _badge(context, '${shift.name} · 今日计薪 ${shift.billableMinutes ~/ 60}h',
                              accent, C.accentDim(context)),
                        ],
                        if (spToday != null) ...[
                          const SizedBox(width: 8),
                          _badge(context, _specialLabel(spToday), C.red(context),
                              C.redDim(context)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _stat(context, '今日已赚', today),
                        const SizedBox(width: 10),
                        _stat(context, '本月已赚', monthTotal),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text('收入明细',
                        style: TextStyle(fontSize: 12, color: dim)),
                    const SizedBox(height: 8),
                    for (final inc in incomes)
                      _incomeRow(context, inc,
                          follow: inc.followSchedule),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _specialLabel(SpecialDayData sp) {
    switch (sp.type) {
      case 'overtime':
        return '今日 ${sp.mult.toStringAsFixed(1)}×';
      case 'leave':
        return '今日请假';
      default:
        return '今日调休';
    }
  }

  Widget _badge(BuildContext c, String text, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
    );
  }

  Widget _stat(BuildContext c, String label, int millis) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: C.card(c),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: C.line(c)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: C.dim(c))),
            const SizedBox(height: 6),
            Text(
              '¥ ${widget.store.state.formatMoney(millis)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _incomeRow(BuildContext c, Income inc, {required bool follow}) {
    final st = follow ? _status : '全天候';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.card(c),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.line(c)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(inc.name,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              Text(st,
                  style: TextStyle(
                      fontSize: 11, color: follow ? C.blue(c) : C.dim(c))),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                follow ? '跟随排班 · 参与倍率' : '全天候 · 24h 增长',
                style: TextStyle(fontSize: 12, color: C.dim(c)),
              ),
              Text(
                '¥ ${widget.store.state.formatMoney(_valueOf(inc))}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Income 便捷复制（改起点）
extension IncomeCopy on Income {
  Income copyWithStart(DateTime start) => Income(
        name: name,
        amountYuan: amountYuan,
        period: period,
        followSchedule: followSchedule,
        participateMultiplier: participateMultiplier,
        startDay: start,
      );
}
