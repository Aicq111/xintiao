// ============================================================
// 薪跳 · 核心计薪引擎（Dart 版）
// 金额以「毫」为最小单位（1 元 = 10000 毫）；时间以「分钟」为最小单位。
// 与 verify/engine_check.mjs 同一算法（已通过 13 项数学验证）。
// ============================================================

/// 排班模式
enum ScheduleMode {
  aroundClock,
  dayShift,
  nightShift,
  twoShift,
  threeShift,
  custom,
  customRotation,
}

/// 休息时段（分钟，班次时间线内）
class BreakRange {
  final int startMin;
  final int endMin;
  const BreakRange(this.startMin, this.endMin);
}

/// 班次。跨天班次（如夜班 20:00 → 次日 6:00）用 endMin > 1440 表示。
class Shift {
  final String name;
  final int startMin;
  final int endMin;
  final List<BreakRange> breaks;
  const Shift(this.name, this.startMin, this.endMin, [this.breaks = const []]);

  int get billableMinutes {
    final rest = breaks.fold<int>(0, (a, b) => a + (b.endMin - b.startMin));
    return (endMin - startMin) - rest;
  }

  int get billableSeconds => billableMinutes * 60;
}

const Shift shiftBai = Shift('白班', 8 * 60, 17 * 60, [BreakRange(12 * 60, 13 * 60)]);
const Shift shiftYe = Shift('夜班', 20 * 60, 30 * 60, [BreakRange(24 * 60, 25 * 60)]);
const Shift shiftZao = Shift('早班', 0, 8 * 60);
const Shift shiftZhong = Shift('中班', 8 * 60, 16 * 60);
const Shift shiftWan = Shift('晚班', 16 * 60, 24 * 60);
const Shift shiftFull = Shift('全天候', 0, 24 * 60);

/// 自定义轮换班次定义：班次时间 + 该班次的固定休息日（0=周一 … 6=周日）
class ShiftDef {
  final String name;
  final int startMin;
  final int endMin;
  final List<BreakRange> breaks;
  final int restWeekday;

  const ShiftDef({
    required this.name,
    required this.startMin,
    required this.endMin,
    this.breaks = const [],
    required this.restWeekday,
  });

  Shift get shift => Shift(name, startMin, endMin, breaks);

  Map<String, dynamic> toJson() => {
        'n': name,
        's': startMin,
        'e': endMin,
        'b': breaks.map((x) => [x.startMin, x.endMin]).toList(),
        'r': restWeekday,
      };

  factory ShiftDef.fromJson(Map<String, dynamic> j) => ShiftDef(
        name: j['n'] as String,
        startMin: j['s'] as int,
        endMin: j['e'] as int,
        breaks: (j['b'] as List? ?? [])
            .map((x) => BreakRange((x as List)[0] as int, x[1] as int))
            .toList(),
        restWeekday: j['r'] as int,
      );
}

/// 自定义轮换配置：按月轮换班次，每个班次有自己的固定休息日（上六休一）
class ScheduleCfg {
  final ScheduleMode mode;
  final List<ShiftDef> rotationShifts;
  final int rotationAnchorYear;
  final int rotationAnchorMonth;
  final int rotationStartIdx; // 锚定月所在班次下标

  const ScheduleCfg(
    this.mode, {
    this.rotationShifts = const [],
    this.rotationAnchorYear = 2026,
    this.rotationAnchorMonth = 1,
    this.rotationStartIdx = 0,
  });

  /// 按月轮换：本月班次 = (绝对月数 + 起始下标) mod 班次数
  ShiftDef? rotationShiftFor(DateTime d) {
    if (rotationShifts.isEmpty) return null;
    final mIdx = (d.year - rotationAnchorYear) * 12 +
        (d.month - rotationAnchorMonth);
    final n = rotationShifts.length;
    final idx = ((mIdx % n) + n + rotationStartIdx) % n;
    return rotationShifts[idx];
  }
}

/// 特殊日类型：加班（倍率）/ 请假（时段计薪 0）/ 调休（整天计薪 0）
enum SpecialType { overtime, leave, off }

class SpecialDay {
  final SpecialType type;
  final double mult; // 加班倍率（0.1 步进）
  final Shift? shift; // 休息日加班的工作时段（复制班次）
  final int? leaveStartMin;
  final int? leaveEndMin;

  const SpecialDay.overtime(this.mult, {this.shift})
      : type = SpecialType.overtime,
        leaveStartMin = null,
        leaveEndMin = null;

  const SpecialDay.leave(int this.leaveStartMin, int this.leaveEndMin)
      : type = SpecialType.leave,
        mult = 1,
        shift = null;

  const SpecialDay.off()
      : type = SpecialType.off,
        mult = 1,
        shift = null,
        leaveStartMin = null,
        leaveEndMin = null;
}

/// 收入（一份）
class Income {
  final String name;
  final double amountYuan;
  final String period; // 'monthly' | 'weekly'
  final bool followSchedule; // 跟随排班（仅每月周期可选）
  final bool participateMultiplier; // 参与加班倍率
  final DateTime startDay; // 累计起点

  const Income({
    required this.name,
    required this.amountYuan,
    this.period = 'monthly',
    this.followSchedule = true,
    this.participateMultiplier = true,
    required this.startDay,
  });
}

/// 计薪区间（绝对分钟，含当日倍率）
class DayInterval {
  final int startMinAbs;
  final int endMinAbs;
  final double mult;
  const DayInterval(this.startMinAbs, this.endMinAbs, this.mult);
}

// ---------- 日期工具 ----------

int dayIndex(DateTime d) => d.difference(DateTime.utc(1970)).inDays;

/// 星期：0 = 周一
int weekdayOf(DateTime d) => d.weekday - 1;

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// 当月第一天所在周的周一为第 0 周起点
int weekIndexOf(DateTime d) {
  final first = DateTime(d.year, d.month, 1);
  final firstMon = dayIndex(first) - weekdayOf(first);
  return (dayIndex(d) - firstMon) ~/ 7;
}

// ---------- 排班 → 当日班次 ----------

Shift? shiftForDay(ScheduleMode mode, DateTime d, [ScheduleCfg? cfg]) {
  final w = weekdayOf(d);
  final idx = dayIndex(d);
  switch (mode) {
    case ScheduleMode.aroundClock:
      return shiftFull;
    case ScheduleMode.dayShift:
    case ScheduleMode.custom:
      return w >= 5 ? null : shiftBai;
    case ScheduleMode.nightShift:
      return w >= 5 ? null : shiftYe;
    case ScheduleMode.twoShift:
      return w >= 5 ? null : (weekIndexOf(d).isOdd ? shiftBai : shiftYe);
    case ScheduleMode.threeShift:
      return w >= 5 ? null : [shiftZao, shiftZhong, shiftWan][idx % 3];
    case ScheduleMode.customRotation:
      final def = cfg?.rotationShiftFor(d);
      if (def == null) return null;
      if (w == def.restWeekday) return null; // 该班次的固定休息日（上六休一）
      return def.shift;
  }
}

/// 当月「纯排班」计薪秒数（不含特殊日）——基准速率的除数。
/// 口径：加班费 / 请假扣款按固定日薪基数核算，与真实工资一致。
int monthlyBillableSeconds(int year, int month, ScheduleMode mode,
    [ScheduleCfg? cfg]) {
  var total = 0;
  for (var d = 1; d <= daysInMonth(year, month); d++) {
    final s = shiftForDay(mode, DateTime(year, month, d), cfg);
    if (s != null) total += s.billableSeconds;
  }
  return total;
}

String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';

/// 当日计薪区间（绝对分钟 + 倍率）。特殊日键：'yyyy-M-d'。
List<DayInterval> dayIntervals(DateTime day, ScheduleMode mode,
    Map<String, SpecialDay> specials, [ScheduleCfg? cfg]) {
  final sp = specials[_key(day)];
  if (sp != null && sp.type == SpecialType.off) return const [];
  var shift = shiftForDay(mode, day, cfg);
  if (sp != null && sp.type == SpecialType.overtime && shift == null) {
    shift = sp.shift; // 休息日加班：用加班时段
  }
  if (shift == null) return const [];
  final dayStart = dayIndex(day) * 1440;

  final raw = <List<int>>[];
  var s = shift.startMin;
  for (final b in shift.breaks) {
    raw.add([s, b.startMin]);
    s = b.endMin;
  }
  raw.add([s, shift.endMin]);

  final mult = (sp != null && sp.type == SpecialType.overtime) ? sp.mult : 1.0;
  final out = <DayInterval>[];

  if (sp != null && sp.type == SpecialType.leave) {
    final ls = dayStart + sp.leaveStartMin!;
    final le = dayStart + sp.leaveEndMin!;
    for (final r in raw) {
      final a = dayStart + r[0], b = dayStart + r[1];
      if (le <= a || ls >= b) {
        out.add(DayInterval(a, b, mult));
      } else {
        if (a < ls) out.add(DayInterval(a, ls, mult));
        if (le < b) out.add(DayInterval(le, b, mult));
      }
    }
  } else {
    for (final r in raw) {
      out.add(DayInterval(dayStart + r[0], dayStart + r[1], mult));
    }
  }
  return out;
}

/// 累计收入（毫）。fromDay/toDay 为当月日期（含两端）。
/// endMinute：toDay 当天的截止分钟（可为小数，用于实时跳动）。
int accumulate({
  required int year,
  required int month,
  required int fromDay,
  required int toDay,
  required ScheduleMode mode,
  required Map<String, SpecialDay> specials,
  required Income income,
  double? endMinute,
  ScheduleCfg? cfg,
}) {
  final days = daysInMonth(year, month);
  double rate; // 毫/秒
  if (income.followSchedule) {
    rate = income.amountYuan * 10000 /
        monthlyBillableSeconds(year, month, mode, cfg);
  } else {
    final periodSec = switch (income.period) {
      'monthly' => days * 86400,
      'weekly' => 7 * 86400,
      'daily' => 86400,
      _ => 0,
    };
    if (periodSec == 0) return 0; // 一次性：不持续增长
    rate = income.amountYuan * 10000 / periodSec;
  }
  var millis = 0.0;
  for (var d = fromDay; d <= toDay; d++) {
    final ivs = dayIntervals(DateTime(year, month, d), mode, specials, cfg);
    for (final iv in ivs) {
      var e = iv.endMinAbs.toDouble();
      if (d == toDay && endMinute != null) {
        final cap = (dayIndex(DateTime(year, month, d)) * 1440) + endMinute;
        if (cap < e) e = cap;
      }
      if (e <= iv.startMinAbs) continue;
      final secs = (e - iv.startMinAbs) * 60;
      final m = (income.followSchedule && income.participateMultiplier)
          ? iv.mult
          : 1.0;
      millis += secs * m * rate;
    }
  }
  return millis.round();
}

/// 今日已计薪秒数（自动扣除休息与请假，截至 now）
double todayWorkSeconds({
  required DateTime now,
  required ScheduleMode mode,
  required Map<String, SpecialDay> specials,
  ScheduleCfg? cfg,
}) {
  final day = DateTime(now.year, now.month, now.day);
  final ivs = dayIntervals(day, mode, specials, cfg);
  final cap = (dayIndex(day) * 1440) +
      now.hour * 60 +
      now.minute +
      now.second / 60;
  var secs = 0.0;
  for (final iv in ivs) {
    final e = iv.endMinAbs > cap ? cap : iv.endMinAbs;
    if (e > iv.startMinAbs) secs += (e - iv.startMinAbs) * 60;
  }
  return secs;
}

/// 当前实时速率（毫/秒）：跟随排班的收入按「当前所处区间的倍率」计，
/// 处于休息 / 请假 / 下班时段时该收入速率为 0；全天候收入恒定。
double currentRateMillisPerSec({
  required DateTime now,
  required ScheduleMode mode,
  required Map<String, SpecialDay> specials,
  required List<Income> incomes,
  ScheduleCfg? cfg,
}) {
  final day = DateTime(now.year, now.month, now.day);
  final ivs = dayIntervals(day, mode, specials, cfg);
  final nowMin = now.hour * 60 + now.minute + now.second / 60;
  final dayStart = dayIndex(day) * 1440;
  final nowAbs = dayStart + nowMin;
  var rate = 0.0;
  for (final inc in incomes) {
    if (!inc.followSchedule) {
      final days = daysInMonth(now.year, now.month);
      final periodSec = switch (inc.period) {
        'monthly' => days * 86400,
        'weekly' => 7 * 86400,
        'daily' => 86400,
        _ => 0,
      };
      if (periodSec > 0) rate += inc.amountYuan * 10000 / periodSec;
      continue;
    }
    final base = inc.amountYuan * 10000 /
        monthlyBillableSeconds(now.year, now.month, mode, cfg);
    final iv = ivs.where((x) => nowAbs >= x.startMinAbs && nowAbs < x.endMinAbs);
    if (iv.isEmpty) continue; // 班外 / 休息 / 请假：不涨
    final m = inc.participateMultiplier ? iv.first.mult : 1.0;
    rate += base * m;
  }
  return rate;
}

/// 从起点到 now 的累计（毫），可跨月；最后一天按 endMinute（含小数）截断。
int accumulateSince({
  required DateTime start,
  required DateTime now,
  required ScheduleMode mode,
  required Map<String, SpecialDay> specials,
  required Income income,
  ScheduleCfg? cfg,
}) {
  var total = 0;
  var cur = DateTime(start.year, start.month);
  while (true) {
    final isLast = cur.year == now.year && cur.month == now.month;
    final isFirst = cur.year == start.year && cur.month == start.month;
    final fromDay = isFirst ? start.day : 1;
    final toDay = isLast ? now.day : daysInMonth(cur.year, cur.month);
    if (toDay < fromDay && isFirst && cur.isAfter(now)) break;
    total += accumulate(
      year: cur.year,
      month: cur.month,
      fromDay: fromDay,
      toDay: toDay,
      mode: mode,
      specials: specials,
      income: income,
      endMinute: isLast
          ? now.hour * 60 + now.minute + now.second / 60
          : null,
      cfg: cfg,
    );
    if (isLast) break;
    cur = DateTime(cur.year, cur.month + 1, 1);
  }
  return total;
}
