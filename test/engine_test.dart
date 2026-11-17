// ============================================================
// 薪跳 · 引擎测试（与 verify/engine_check.mjs 同 13 项）
// 运行：flutter test
// ============================================================
import 'package:flutter_test/flutter_test.dart';
import 'package:xintiao/core/engine.dart';

void main() {
  const y = 2026, m = 11;
  final incomeZhu = Income(
      name: '主工资', amountYuan: 5000, startDay: DateTime(y, m, 1));
  final incomeFu = Income(
      name: '副业',
      amountYuan: 1000,
      followSchedule: false,
      startDay: DateTime(y, m, 1));
  final specials = <String, SpecialDay>{
    '2026-11-14': const SpecialDay.overtime(1.5, shift: shiftBai),
    '2026-11-18': const SpecialDay.leave(12 * 60, 17 * 60),
    '2026-11-20': const SpecialDay.off(),
  };

  test('T1 2026-11-01 是周日', () {
    expect(weekdayOf(DateTime(y, m, 1)), 6);
  });

  test('T2 长白班月计薪秒数 = 21 天 × 8h', () {
    expect(monthlyBillableSeconds(y, m, ScheduleMode.dayShift), 21 * 8 * 3600);
  });

  test('T3 长白班速率（毫/秒）', () {
    final rate = 5000 * 10000 / monthlyBillableSeconds(y, m, ScheduleMode.dayShift);
    expect(rate, closeTo(5000 * 10000 / 604800, 0.01));
  });

  test('T4 11/14 加班 1.5× 当日收入', () {
    final rate = 5000 * 10000 / monthlyBillableSeconds(y, m, ScheduleMode.dayShift);
    expect(
      accumulate(
          year: y, month: m, fromDay: 14, toDay: 14,
          mode: ScheduleMode.dayShift, specials: specials, income: incomeZhu),
      closeTo(8 * 3600 * 1.5 * rate, 1),
    );
  });

  test('T5 11/18 请假下午当日收入 = 4h', () {
    final rate = 5000 * 10000 / monthlyBillableSeconds(y, m, ScheduleMode.dayShift);
    expect(
      accumulate(
          year: y, month: m, fromDay: 18, toDay: 18,
          mode: ScheduleMode.dayShift, specials: specials, income: incomeZhu),
      closeTo(4 * 3600 * rate, 1),
    );
  });

  test('T6 11/20 调休当日收入 = 0', () {
    expect(
      accumulate(
          year: y, month: m, fromDay: 20, toDay: 20,
          mode: ScheduleMode.dayShift, specials: specials, income: incomeZhu),
      0,
    );
  });

  test('T7 11/1-16 累计', () {
    final rate = 5000 * 10000 / monthlyBillableSeconds(y, m, ScheduleMode.dayShift);
    expect(
      accumulate(
          year: y, month: m, fromDay: 1, toDay: 16,
          mode: ScheduleMode.dayShift, specials: specials, income: incomeZhu),
      closeTo((11 * 8 * 3600 + 8 * 3600 * 1.5) * rate, 1),
    );
  });

  test('T8 长夜班月计薪秒数 = 21 天 × 9h', () {
    expect(monthlyBillableSeconds(y, m, ScheduleMode.nightShift), 21 * 9 * 3600);
  });

  test('T9 夜班跨天当日计薪分钟数 = 540', () {
    final ivs = dayIntervals(DateTime(y, m, 2), ScheduleMode.nightShift, {});
    final mins = ivs.fold<int>(0, (a, b) => a + (b.endMinAbs - b.startMinAbs));
    expect(mins, 9 * 60);
  });

  test('T10 两班倒月计薪秒数 = 178h', () {
    expect(monthlyBillableSeconds(y, m, ScheduleMode.twoShift), 178 * 3600);
  });

  test('T11 副业 11/1-16 累计（全天候）', () {
    final rate = 1000 * 10000 / (30 * 86400);
    expect(
      accumulate(
          year: y, month: m, fromDay: 1, toDay: 16,
          mode: ScheduleMode.aroundClock, specials: {}, income: incomeFu),
      closeTo(16 * 86400 * rate, 1),
    );
  });

  test('T12 副业不受特殊日影响', () {
    final rate = 1000 * 10000 / (30 * 86400);
    expect(
      accumulate(
          year: y, month: m, fromDay: 14, toDay: 14,
          mode: ScheduleMode.aroundClock, specials: specials, income: incomeFu),
      closeTo(86400 * rate, 1),
    );
  });

  test('T13 不参与倍率：14 日按 1.0×', () {
    final incomeNoMult = Income(
        name: 'x', amountYuan: 3000, participateMultiplier: false,
        startDay: DateTime(y, m, 1));
    final rate = 3000 * 10000 / monthlyBillableSeconds(y, m, ScheduleMode.dayShift);
    expect(
      accumulate(
          year: y, month: m, fromDay: 14, toDay: 14,
          mode: ScheduleMode.dayShift, specials: specials, income: incomeNoMult),
      closeTo(8 * 3600 * rate, 1),
    );
  });
}
