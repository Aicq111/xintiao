// ============================================================
// 薪跳 · 小组件数据桥
// 主 App 把实时数据经原生通道写入 App Group UserDefaults，
// WidgetKit 扩展读取后渲染小/中/大三尺寸。
// ============================================================
import 'package:flutter/services.dart';
import 'engine.dart';
import 'store.dart';

class WidgetBridge {
  static const _channel = MethodChannel('com.xintiao.widget');

  static const accentHex = [
    '#6DF0A8',
    '#FFE28A',
    '#A8D0FF',
    '#FFACAC',
    '#DDBEFF',
    '#FFD3E4',
    '#7DF5E0',
    '#EDF2FA',
  ];

  static Future<void> push(AppStore store, DateTime now) async {
    try {
      final s = store.state;
      final incomes = store.engineIncomes;
      final mode = store.engineMode;
      final specials = store.engineSpecials;
      final cfg = store.cfg;
      final nowMin = now.hour * 60 + now.minute + now.second / 60;

      int totalOf(Income inc) => accumulateSince(
          start: inc.startDay, now: now, mode: mode, specials: specials,
          income: inc, cfg: cfg);
      int todayOf(Income inc) => accumulate(
          year: now.year, month: now.month, fromDay: now.day, toDay: now.day,
          mode: mode, specials: specials, income: inc, endMinute: nowMin,
          cfg: cfg);

      // 视图目标（全部收入 / 单份）
      var viewIncomes = incomes;
      var viewName = '全部收入';
      if (s.widgetIncome != 'all') {
        viewIncomes = incomes.where((e) => e.name == s.widgetIncome).toList();
        viewName = s.widgetIncome;
      }

      var totalMillis = 0, todayMillis = 0, monthMillis = 0;
      for (final inc in viewIncomes) {
        totalMillis += totalOf(inc);
        todayMillis += todayOf(inc);
        monthMillis += accumulateSince(
            start: DateTime(now.year, now.month, 1), now: now, mode: mode,
            specials: specials, income: inc, cfg: cfg);
      }

      // 状态
      final shift =
          shiftForDay(mode, DateTime(now.year, now.month, now.day), cfg);
      var status = '今日休息';
      var working = false;
      if (shift != null) {
        if (nowMin < shift.startMin) {
          status = '未上班';
        } else if (nowMin >= shift.endMin) {
          status = '已下班';
        } else if (shift.breaks.any((b) => nowMin >= b.startMin && nowMin < b.endMin)) {
          status = '休息中';
        } else {
          status = '上班中';
          working = true;
        }
      }

      // 速率（厘/秒）
      final rate = currentRateMillisPerSec(
          now: now, mode: mode, specials: specials, incomes: incomes,
          cfg: cfg);
      final rateText = '+${(rate / 100).toStringAsFixed(2)}厘/秒';

      // 发薪倒计时
      var paydayText = '—';
      try {
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

        final today = DateTime(now.year, now.month, now.day);
        var t = target(now.year, now.month);
        if (!t.isAfter(today)) t = target(now.year, now.month + 1);
        final days = t.difference(today).inDays;
        paydayText = days == 0 ? '今天发薪' : '距发薪 $days 天';
      } catch (_) {}

      // 今日倍率徽标
      final sp = s.specials['${now.year}-${now.month}-${now.day}'];
      var badge = '1.0×';
      if (sp != null) {
        if (sp.type == 'overtime') {
          badge = '${sp.mult.toStringAsFixed(1)}×';
        } else if (sp.type == 'leave') {
          badge = '假';
        } else {
          badge = '休';
        }
      }

      // 已工作 / 距下班
      var workText = '';
      if (shift != null) {
        if (status == '已下班') {
          workText = '已下班 · 今日计薪 ${shift.billableMinutes ~/ 60}h';
        } else {
          final worked =
              todayWorkSeconds(now: now, mode: mode, specials: specials,
                  cfg: cfg);
          var left = shift.endMin - nowMin;
          if (left < 0) left = 0;
          String dur(double secs) {
            final ss = secs.floor();
            final h = ss ~/ 3600, mm = (ss % 3600) ~/ 60, sc = ss % 60;
            String p(int n) => n.toString().padLeft(2, '0');
            return '$h:${p(mm)}:${p(sc)}';
          }

          workText = '已工作 ${dur(worked)} · 距下班 ${dur(left * 60)}';
        }
      }

      // 收入明细行
      final rows = <String>[];
      for (final inc in viewIncomes) {
        rows.add('${inc.name} ¥${s.formatMoney(totalOf(inc))}');
      }

      await _channel.invokeMethod('update', {
        'total': s.formatMoney(totalMillis),
        'rate': rateText,
        'today': s.formatMoney(todayMillis),
        'month': s.formatMoney(monthMillis),
        'payday': paydayText,
        'status': status,
        'working': working,
        'badge': badge,
        'work': workText,
        'rows': rows,
        'accent': accentHex[s.accentIdx],
        'view': viewName,
      });
    } catch (_) {
      // 非真机环境（如单元测试）时静默忽略
    }
  }
}
