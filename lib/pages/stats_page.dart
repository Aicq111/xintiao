// ============================================================
// 薪跳 · 统计页（本月堆叠曲线 + 近 6 个月柱状对比 + 汇总）
// ============================================================
import 'package:flutter/material.dart';
import '../core/engine.dart';
import '../core/store.dart';
import '../core/theme.dart';

class StatsPage extends StatefulWidget {
  final AppStore store;
  const StatsPage({super.key, required this.store});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final s = widget.store.state;
        final now = DateTime.now();
        final incomes = widget.store.engineIncomes;
        final mode = widget.store.engineMode;
        final specials = widget.store.engineSpecials;
        final cfg = widget.store.cfg;
        final accent = Theme.of(context).colorScheme.primary;
        final dim = C.dim(context);

        final days = now.day;
        final nowMin = now.hour * 60 + now.minute + now.second / 60;

        // 每日累计序列（元）
        final series = <List<double>>[];
        for (final inc in incomes) {
          final arr = <double>[];
          for (var d = 1; d <= days; d++) {
            var v = 0.0;
            final beforeStart = inc.startDay.year == now.year &&
                inc.startDay.month == now.month &&
                d < inc.startDay.day;
            if (!beforeStart) {
              v = accumulate(
                    year: now.year,
                    month: now.month,
                    fromDay: d,
                    toDay: d,
                    mode: mode,
                    specials: specials,
                    income: inc,
                    endMinute: d == days ? nowMin : null,
                    cfg: cfg,
                  ) /
                  10000.0;
            }
            arr.add(v);
          }
          series.add(arr);
        }
        final totals = List<double>.filled(days, 0);
        for (final arr in series) {
          for (var i = 0; i < days; i++) {
            totals[i] += arr[i];
          }
        }
        final maxY = totals.fold<double>(1, (a, b) => a > b ? a : b);

        // 特殊日集合
        final otDays = <int>{}, lvDays = <int>{}, ofDays = <int>{};
        for (final e in s.specials.entries) {
          final p = e.key.split('-');
          if (p.length != 3) continue;
          final y = int.tryParse(p[0]);
          final m = int.tryParse(p[1]);
          final d = int.tryParse(p[2]);
          if (y == now.year && m == now.month && d != null && d <= now.day) {
            if (e.value.type == 'overtime') {
              otDays.add(d);
            } else if (e.value.type == 'leave') {
              lvDays.add(d);
            } else {
              ofDays.add(d);
            }
          }
        }

        // 加班额外收入（元）
        var overtimeExtra = 0.0;
        for (final e in s.specials.entries) {
          final spd = e.value;
          if (spd.type != 'overtime') continue;
          final p = e.key.split('-');
          if (p.length != 3) continue;
          final y = int.tryParse(p[0]);
          final m = int.tryParse(p[1]);
          final d = int.tryParse(p[2]);
          if (y != now.year || m != now.month || d == null || d > now.day) {
            continue;
          }
          for (final inc in incomes) {
            if (!inc.followSchedule || !inc.participateMultiplier) continue;
            final rate = inc.amountYuan * 10000 /
                monthlyBillableSeconds(now.year, now.month, mode, cfg);
            final ivs =
                dayIntervals(DateTime(now.year, now.month, d), mode, specials, cfg);
            for (final iv in ivs) {
              if (iv.mult > 1.0) {
                overtimeExtra += (iv.mult - 1.0) *
                    (iv.endMinAbs - iv.startMinAbs) *
                    60 *
                    rate /
                    10000.0;
              }
            }
          }
        }

        // 近 6 个月
        final monthVals = <double>[];
        final monthLabels = <String>[];
        for (var i = 5; i >= 0; i--) {
          final mt = DateTime(now.year, now.month - i, 1);
          final md = daysInMonth(mt.year, mt.month);
          final isCur = i == 0;
          var total = 0.0;
          for (final inc in incomes) {
            if (inc.startDay.isAfter(DateTime(mt.year, mt.month + 1, 0))) {
              continue;
            }
            var fromD = 1;
            if (inc.startDay.year == mt.year &&
                inc.startDay.month == mt.month) {
              fromD = inc.startDay.day;
            }
            total += accumulate(
                  year: mt.year,
                  month: mt.month,
                  fromDay: fromD,
                  toDay: isCur ? now.day : md,
                  mode: mode,
                  specials: specials,
                  income: inc,
                  endMinute: isCur ? nowMin : null,
                  cfg: cfg,
                ) /
                10000.0;
          }
          monthVals.add(total);
          monthLabels.add('${mt.month}月');
        }

        final monthTotal = totals.isEmpty ? 0.0 : totals.last;

        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Text('统计',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: C.card(context),
                    border: Border.all(color: C.line(context)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _tabBtn(context, '本月曲线', 0),
                      _tabBtn(context, '近 6 个月', 1),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: C.card(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: C.line(context)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _tab == 0 ? '本月累计增长（按天）' : '近 6 个月累计（元）',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700),
                              ),
                              if (_tab == 0)
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    for (var i = 0;
                                        i < incomes.length &&
                                            i < 3;
                                        i++)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: _seriesColor(context, i),
                                            ),
                                          ),
                                          const SizedBox(width: 3),
                                          Text(incomes[i].name,
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: dim)),
                                        ],
                                      ),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 180,
                            child: CustomPaint(
                              size: Size.infinite,
                              painter: _tab == 0
                                  ? _CurvePainter(
                                      series: series,
                                      totals: totals,
                                      colors: [
                                        for (var i = 0;
                                            i < incomes.length;
                                            i++)
                                          _seriesColor(context, i)
                                      ],
                                      maxY: maxY,
                                      overtimeDays: otDays,
                                      leaveDays: lvDays,
                                      offDays: ofDays,
                                      accent: accent,
                                      lineColor: C.line(context),
                                      dimColor: dim,
                                      goldColor: C.gold(context),
                                      blueColor: C.blue(context),
                                    )
                                  : _BarsPainter(
                                      values: monthVals,
                                      labels: monthLabels,
                                      accent: accent,
                                      lineColor: C.line(context),
                                      dimColor: dim,
                                    ),
                            ),
                          ),
                          if (_tab == 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              '● 金色 = 加班日 ｜ ● 灰 = 请假 ｜ ● 蓝 = 调休 ｜ 虚线 = 今天',
                              style: TextStyle(fontSize: 10, color: dim),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _stat(context, '本月累计',
                            '¥${s.formatMoney((monthTotal * 10000).round())}'),
                        const SizedBox(width: 10),
                        _stat(context, '日均增长',
                            '¥${(monthTotal / days).toStringAsFixed(2)}'),
                        const SizedBox(width: 10),
                        _stat(context, '加班收入',
                            '¥${overtimeExtra.toStringAsFixed(2)}',
                            color: C.gold(context)),
                      ],
                    ),
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

  Color _seriesColor(BuildContext c, int i) {
    switch (i % 3) {
      case 0:
        return Theme.of(c).colorScheme.primary;
      case 1:
        return C.blue(c);
      default:
        return C.gold(c);
    }
  }

  Widget _tabBtn(BuildContext c, String label, int idx) {
    final on = _tab == idx;
    final accent = Theme.of(c).colorScheme.primary;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = idx),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? C.accentDim(c) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: on ? FontWeight.w700 : FontWeight.w400,
              color: on ? accent : C.dim(c),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(BuildContext c, String label, String value, {Color? color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: C.card(c),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.line(c)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: C.dim(c))),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 曲线画笔
// ============================================================
class _CurvePainter extends CustomPainter {
  final List<List<double>> series;
  final List<double> totals;
  final List<Color> colors;
  final double maxY;
  final Set<int> overtimeDays;
  final Set<int> leaveDays;
  final Set<int> offDays;
  final Color accent;
  final Color lineColor;
  final Color dimColor;
  final Color goldColor;
  final Color blueColor;

  _CurvePainter({
    required this.series,
    required this.totals,
    required this.colors,
    required this.maxY,
    required this.overtimeDays,
    required this.leaveDays,
    required this.offDays,
    required this.accent,
    required this.lineColor,
    required this.dimColor,
    required this.goldColor,
    required this.blueColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    const padL = 30.0, padR = 6.0, padT = 12.0, padB = 20.0;
    final plotW = w - padL - padR;
    final plotH = h - padT - padB;
    final n = totals.length;
    if (n < 2) return;

    final grid = Paint()
      ..color = lineColor
      ..strokeWidth = 0.6;
    for (var i = 0; i <= 3; i++) {
      final y = padT + plotH * i / 3;
      canvas.drawLine(Offset(padL, y), Offset(w - padR, y), grid);
    }

    double xAt(int i) => padL + plotW * i / (n - 1);
    double yAt(double v) => padT + plotH * (1 - v / maxY);

    // 各收入细线
    for (var si = 0; si < series.length; si++) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        final x = xAt(i), y = yAt(series[si][i]);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = colors[si % colors.length].withAlpha(200)
          ..strokeWidth = 1.4
          ..style = PaintingStyle.stroke,
      );
    }

    // 汇总粗线
    final totalPath = Path();
    for (var i = 0; i < n; i++) {
      final x = xAt(i), y = yAt(totals[i]);
      if (i == 0) {
        totalPath.moveTo(x, y);
      } else {
        totalPath.lineTo(x, y);
      }
    }
    canvas.drawPath(
      totalPath,
      Paint()
        ..color = accent
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // 特殊日标记
    for (final d in overtimeDays) {
      if (d < 1 || d > n) continue;
      final o = Offset(xAt(d - 1), yAt(totals[d - 1]));
      canvas.drawCircle(o, 4, Paint()..color = goldColor);
      canvas.drawCircle(
        o,
        4,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    for (final d in leaveDays) {
      if (d < 1 || d > n) continue;
      canvas.drawCircle(Offset(xAt(d - 1), yAt(totals[d - 1])), 3,
          Paint()..color = dimColor);
    }
    for (final d in offDays) {
      if (d < 1 || d > n) continue;
      canvas.drawCircle(Offset(xAt(d - 1), yAt(totals[d - 1])), 3,
          Paint()..color = blueColor);
    }

    // 今天虚线
    canvas.drawLine(
      Offset(xAt(n - 1), padT - 6),
      Offset(xAt(n - 1), padT + plotH + 4),
      Paint()
        ..color = dimColor
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );

    // 刻度文字
    final tp = TextPainter(
      text: TextSpan(
          text: maxY.toStringAsFixed(0),
          style: TextStyle(fontSize: 9, color: dimColor)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(padL - tp.width - 4, padT - 6));
    final tp2 = TextPainter(
      text: TextSpan(
          text: '今天', style: TextStyle(fontSize: 9, color: dimColor)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp2.paint(canvas, Offset(w - padR - tp2.width, padT + plotH + 6));
  }

  @override
  bool shouldRepaint(covariant _CurvePainter old) => true;
}

// ============================================================
// 柱状图画笔
// ============================================================
class _BarsPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color accent;
  final Color lineColor;
  final Color dimColor;

  _BarsPainter({
    required this.values,
    required this.labels,
    required this.accent,
    required this.lineColor,
    required this.dimColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    const padT = 18.0, padB = 22.0, padL = 8.0, padR = 8.0;
    final plotW = w - padL - padR, plotH = h - padT - padB;
    final maxV = values.fold<double>(1, (a, b) => a > b ? a : b);
    final slot = plotW / 6;
    final barW = slot * 0.55;
    final base = padT + plotH;
    canvas.drawLine(Offset(padL, base), Offset(w - padR, base),
        Paint()
          ..color = lineColor
          ..strokeWidth = 0.8);
    for (var i = 0; i < 6 && i < values.length; i++) {
      final v = values[i];
      final bh = plotH * v / maxV;
      final x = padL + slot * i + (slot - barW) / 2;
      final isLast = i == 5;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, base - bh, barW, bh), const Radius.circular(5)),
        Paint()..color = isLast ? accent : lineColor.withAlpha(160),
      );
      final tp = TextPainter(
        text: TextSpan(
            text: v.toStringAsFixed(0),
            style: TextStyle(
                fontSize: 8, color: isLast ? accent : dimColor)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
          canvas, Offset(padL + slot * i + (slot - tp.width) / 2, base - bh - tp.height - 2));
      final tp2 = TextPainter(
        text: TextSpan(
            text: labels[i],
            style: TextStyle(
                fontSize: 9,
                color: dimColor,
                fontWeight:
                    isLast ? FontWeight.w700 : FontWeight.w400)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp2.paint(
          canvas, Offset(padL + slot * i + (slot - tp2.width) / 2, base + 5));
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) => true;
}
