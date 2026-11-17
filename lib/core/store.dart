// ============================================================
// 薪跳 · 数据模型与本地存储（shared_preferences 持久化 JSON）
// ============================================================
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'engine.dart';

/// 收入（可序列化）
class IncomeData {
  String name;
  double amountYuan;
  String period; // 'monthly' | 'weekly'
  bool followSchedule;
  bool participateMultiplier;
  bool enabled;
  DateTime startDay;

  IncomeData({
    required this.name,
    required this.amountYuan,
    this.period = 'monthly',
    this.followSchedule = true,
    this.participateMultiplier = true,
    this.enabled = true,
    DateTime? startDay,
  }) : startDay = startDay ??
            DateTime(DateTime.now().year, DateTime.now().month, 1);

  Income toEngine() => Income(
        name: name,
        amountYuan: amountYuan,
        period: period,
        followSchedule: followSchedule,
        participateMultiplier: participateMultiplier,
        startDay: startDay,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'amount': amountYuan,
        'period': period,
        'follow': followSchedule,
        'participate': participateMultiplier,
        'enabled': enabled,
        'startDay': startDay.toIso8601String(),
      };

  factory IncomeData.fromJson(Map<String, dynamic> j) => IncomeData(
        name: j['name'] as String,
        amountYuan: (j['amount'] as num).toDouble(),
        period: j['period'] as String? ?? 'monthly',
        followSchedule: j['follow'] as bool? ?? true,
        participateMultiplier: j['participate'] as bool? ?? true,
        enabled: j['enabled'] as bool? ?? true,
        startDay: DateTime.parse(j['startDay'] as String),
      );
}

/// 排班模式
class ScheduleData {
  int mode; // 0 全天候 1 长白班 2 长夜班 3 两班倒 4 三班倒 5 自定义

  ScheduleData({this.mode = 1});

  static const modeNames = ['全天候', '长白班', '长夜班', '两班倒', '三班倒', '自定义'];

  ScheduleMode get engineMode => ScheduleMode.values[mode];

  Map<String, dynamic> toJson() => {'mode': mode};

  factory ScheduleData.fromJson(Map<String, dynamic> j) =>
      ScheduleData(mode: j['mode'] as int? ?? 1);
}

/// 特殊日（加班 / 请假 / 调休）
class SpecialDayData {
  String type; // 'overtime' | 'leave' | 'off'
  double mult;
  int shiftIdx; // 加班复制的班次（presetShifts 索引）
  int leaveStart; // 分钟
  int leaveEnd;

  SpecialDayData({
    required this.type,
    this.mult = 1.0,
    this.shiftIdx = 0,
    this.leaveStart = 0,
    this.leaveEnd = 0,
  });

  static const presetShifts = [shiftBai, shiftYe, shiftZao, shiftZhong, shiftWan];

  SpecialDay toEngine() {
    switch (type) {
      case 'overtime':
        return SpecialDay.overtime(mult, shift: presetShifts[shiftIdx]);
      case 'leave':
        return SpecialDay.leave(leaveStart, leaveEnd);
      default:
        return const SpecialDay.off();
    }
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'mult': mult,
        'shiftIdx': shiftIdx,
        'leaveStart': leaveStart,
        'leaveEnd': leaveEnd,
      };

  factory SpecialDayData.fromJson(Map<String, dynamic> j) => SpecialDayData(
        type: j['type'] as String,
        mult: (j['mult'] as num?)?.toDouble() ?? 1.0,
        shiftIdx: j['shiftIdx'] as int? ?? 0,
        leaveStart: j['leaveStart'] as int? ?? 0,
        leaveEnd: j['leaveEnd'] as int? ?? 0,
      );
}

/// 全局状态
class AppState {
  List<IncomeData> incomes;
  ScheduleData schedule;
  Map<String, SpecialDayData> specials; // 'y-m-d'
  int minUnitIdx; // 0元 1角 2分 3厘 4毫
  int decimals; // 0..4
  int accentIdx; // 0..3
  int themeMode; // 0 跟随系统 1 深色 2 浅色
  int payDay; // 发薪日（1..28）
  String payRule; // 'day' | 'lastWorkday'
  bool holidayMark;
  int frameRateMode; // 0 跟随系统 1 锁定60Hz
  Map<String, bool> widgetFlags; // 小组件显示项开关
  String widgetIncome; // 小组件目标收入：'all' 或收入名

  AppState({
    List<IncomeData>? incomes,
    this.schedule = const ScheduleData(),
    Map<String, SpecialDayData>? specials,
    this.minUnitIdx = 3,
    this.decimals = 3,
    this.accentIdx = 0,
    this.themeMode = 0,
    this.payDay = 15,
    this.payRule = 'day',
    this.holidayMark = true,
    this.frameRateMode = 0,
    Map<String, bool>? widgetFlags,
    this.widgetIncome = 'all',
  })  : incomes = incomes ?? [IncomeData(name: '主工资', amountYuan: 5000)],
        specials = specials ?? {},
        widgetFlags = widgetFlags ??
            {
              'rate': true,
              'today': true,
              'month': true,
              'payday': true,
              'status': true,
              'badge': true,
              'work': true,
              'list': true,
              'curve': false,
            };

  static const minUnitNames = ['元', '角', '分', '厘', '毫'];
  static const minUnitMillis = [10000, 1000, 100, 10, 1];

  int get displayDigits => decimals < minUnitIdx ? minUnitIdx : decimals;

  /// 金额格式化：按最小单位取整，显示位数取「更细的为准」
  String formatMoney(int millis) {
    final unit = minUnitMillis[minUnitIdx];
    final r = ((millis / unit).round()) * unit;
    final sign = r < 0 ? '-' : '';
    final abs = r.abs();
    final intPart = (abs ~/ 10000)
        .toString()
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    final digits = displayDigits;
    if (digits == 0) return '$sign$intPart';
    final frac = (abs % 10000).toString().padLeft(4, '0').substring(0, digits);
    return '$sign$intPart.$frac';
  }

  Map<String, dynamic> toJson() => {
        'incomes': incomes.map((e) => e.toJson()).toList(),
        'schedule': schedule.toJson(),
        'specials': specials.map((k, v) => MapEntry(k, v.toJson())),
        'minUnit': minUnitIdx,
        'decimals': decimals,
        'accent': accentIdx,
        'themeMode': themeMode,
        'payDay': payDay,
        'payRule': payRule,
        'holidayMark': holidayMark,
        'frame': frameRateMode,
        'widgetFlags': widgetFlags,
        'widgetIncome': widgetIncome,
      };

  factory AppState.fromJson(Map<String, dynamic> j) => AppState(
        incomes: (j['incomes'] as List? ?? [])
            .map((e) => IncomeData.fromJson(e as Map<String, dynamic>))
            .toList(),
        schedule: j['schedule'] == null
            ? ScheduleData()
            : ScheduleData.fromJson(j['schedule'] as Map<String, dynamic>),
        specials: (j['specials'] as Map? ?? {}).map((k, v) => MapEntry(
            k as String, SpecialDayData.fromJson(v as Map<String, dynamic>))),
        minUnitIdx: j['minUnit'] as int? ?? 3,
        decimals: j['decimals'] as int? ?? 3,
        accentIdx: j['accent'] as int? ?? 0,
        themeMode: j['themeMode'] as int? ?? 0,
        payDay: j['payDay'] as int? ?? 15,
        payRule: j['payRule'] as String? ?? 'day',
        holidayMark: j['holidayMark'] as bool? ?? true,
        frameRateMode: j['frame'] as int? ?? 0,
        widgetFlags: (j['widgetFlags'] as Map? ?? {})
            .map((k, v) => MapEntry(k as String, v as bool)),
        widgetIncome: j['widgetIncome'] as String? ?? 'all',
      );
}

/// 全局存储（ChangeNotifier）
class AppStore extends ChangeNotifier {
  AppState state;
  AppStore([AppState? s]) : state = s ?? AppState();

  static const _key = 'xintiao_state_v1';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        state = AppState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }

  void update(void Function(AppState s) fn) {
    fn(state);
    save();
    notifyListeners();
  }

  ScheduleMode get engineMode => state.schedule.engineMode;

  Map<String, SpecialDay> get engineSpecials =>
      state.specials.map((k, v) => MapEntry(k, v.toEngine()));

  List<Income> get engineIncomes => state.incomes
      .where((e) => e.enabled)
      .map((e) => e.toEngine())
      .toList();
}
