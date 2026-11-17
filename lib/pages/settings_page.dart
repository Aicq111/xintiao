// ============================================================
// 薪跳 · 设置页（含：显示设置 / 主题 / 发薪日 / 帧率 / 小组件设置）
// ============================================================
import 'package:flutter/material.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'calendar_page.dart';
import 'income_page.dart';

class SettingsPage extends StatelessWidget {
  final AppStore store;
  const SettingsPage({super.key, required this.store});

  static String _themeModeName(int m) =>
      m == 0 ? '跟随系统' : (m == 1 ? '深色' : '浅色');

  static String _frameName(int m) =>
      m == 0 ? '跟随系统（120Hz）' : '锁定 60Hz 省电';

  String _payDesc(AppState s) =>
      s.payRule == 'lastWorkday' ? '每月最后一个工作日' : '每月 ${s.payDay} 号';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final s = store.state;
        final total = s.incomes
            .where((e) => e.enabled)
            .fold<double>(0, (a, b) => a + b.amountYuan);
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal:20),
            children: [
              const SizedBox(height: 12),
              const Text('设置',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              _label(context, '收入与发薪'),
              _card(context, [
                _row(context, '💼', '收入管理',
                    '${s.incomes.length} 份收入 · 月总额 ¥${total.toStringAsFixed(0)}',
                    () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => IncomePage(store: store)))),
                _row(context, '🎉', '发薪日与提醒', _payDesc(s),
                    () => _paySheet(context)),
              ]),
              _label(context, '排班'),
              _card(context, [
                _row(context, '📅', '排班与特殊日',
                    ScheduleData.modeNames[s.schedule.mode],
                    () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => CalendarPage(store: store)))),
                _switchRow(context, '🏮', '中国法定节假日日历',
                    '自动标注节假日与调休上班日', s.holidayMark,
                    (v) => store.update((st) => st.holidayMark = v)),
              ]),
              _label(context, '显示与主题'),
              _card(context, [
                _row(context, '🔢', '单位与精度',
                    '${AppState.minUnitNames[s.minUnitIdx]} · ${s.displayDigits} 位小数',
                    () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => DisplaySettingsPage(store: store)))),
                _row(context, '🎨', '主题',
                    '${AppTheme.accentNames[s.accentIdx]} · ${_themeModeName(s.themeMode)}',
                    () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => ThemeSettingsPage(store: store)))),
                _row(context, '⚡', '帧率', _frameName(s.frameRateMode),
                    () => _frameSheet(context)),
              ]),
              _label(context, '小组件'),
              _card(context, [
                _row(context, '🧩', '小组件设置',
                    '小 / 中 / 大三尺寸 · 显示项开关',
                    () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => WidgetSettingsPage(store: store)))),
              ]),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  '薪跳 · 版本 0.1.0\n数据仅保存在本机 · 累计起点默认每月 1 号',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11, color: C.dim(context), height: 1.8),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  // ---------- 发薪日弹层 ----------
  void _paySheet(BuildContext c) {
    var day = store.state.payDay;
    var rule = store.state.payRule;
    final accent = Theme.of(c).colorScheme.primary;
    showModalBottomSheet(
      context: c,
      backgroundColor: C.card(c),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: C.line(c), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              const Text('发薪日设置',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text('发薪规则', style: TextStyle(fontSize: 12, color: C.dim(c))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _chip(c, '每月 X 号', rule == 'day', accent,
                      () => setSt(() => rule = 'day')),
                  _chip(c, '每月最后一个工作日', rule == 'lastWorkday', accent,
                      () => setSt(() => rule = 'lastWorkday')),
                ],
              ),
              if (rule == 'day') ...[
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () =>
                          setSt(() => day = (day - 1).clamp(1, 28).toInt()),
                      icon: Icon(Icons.remove_circle_outline, color: accent),
                    ),
                    Text('每月 $day 号',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    IconButton(
                      onPressed: () =>
                          setSt(() => day = (day + 1).clamp(1, 28).toInt()),
                      icon: Icon(Icons.add_circle_outline, color: accent),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              Text('遇周末/节假日自动顺延到下一个工作日（默认开启）',
                  style: TextStyle(fontSize: 11, color: C.dim(c))),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: const Color(0xFF06231A)),
                  onPressed: () {
                    store.update((st) {
                      st.payDay = day;
                      st.payRule = rule;
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('完成',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- 帧率弹层 ----------
  void _frameSheet(BuildContext c) {
    final accent = Theme.of(c).colorScheme.primary;
    showModalBottomSheet(
      context: c,
      backgroundColor: C.card(c),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: C.line(c), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            const Text('帧率设置',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('数字数据每秒更新一次；帧率影响动画流畅度',
                style: TextStyle(fontSize: 11, color: C.dim(c))),
            const SizedBox(height: 12),
            _choice(c, '跟随系统（iPhone 13 Pro+ 自动 120Hz）', 0),
            _choice(c, '锁定 60Hz 省电', 1),
          ],
        ),
      ),
    );
  }

  Widget _choice(BuildContext c, String label, int value) {
    final on = store.state.frameRateMode == value;
    final accent = Theme.of(c).colorScheme.primary;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: on
          ? Icon(Icons.check_circle, color: accent, size: 20)
          : Icon(Icons.circle_outlined, color: C.line(c), size: 20),
      onTap: () {
        store.update((st) => st.frameRateMode = value);
        Navigator.pop(c);
      },
    );
  }

  // ---------- 通用组件 ----------
  Widget _label(BuildContext c, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: TextStyle(
                fontSize: 12, color: C.dim(c), fontWeight: FontWeight.w600)),
      );

  Widget _card(BuildContext c, List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: C.card(c),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: C.line(c)),
        ),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i != children.length - 1)
                Divider(height: 1, color: C.line(c), indent: 16, endIndent: 16),
            ],
          ],
        ),
      );

  Widget _row(BuildContext c, String icon, String name, String desc,
      VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: C.accentDim(c),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Center(child: Text(icon, style: const TextStyle(fontSize: 14))),
      ),
      title: Text(name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(desc, style: TextStyle(fontSize: 11, color: C.dim(c))),
      trailing:
          Icon(Icons.chevron_right, color: C.dim(c), size: 20),
    );
  }

  Widget _switchRow(BuildContext c, String icon, String name, String desc,
      bool value, ValueChanged<bool> onChanged) {
    final accent = Theme.of(c).colorScheme.primary;
    return ListTile(
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: C.goldDim(c),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Center(child: Text(icon, style: const TextStyle(fontSize: 14))),
      ),
      title: Text(name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(desc, style: TextStyle(fontSize: 11, color: C.dim(c))),
      trailing: Switch(value: value, activeColor: accent, onChanged: onChanged),
    );
  }

  Widget _chip(BuildContext c, String label, bool on, Color accent,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
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
// 显示设置（最小单位 + 小数位数）
// ============================================================
class DisplaySettingsPage extends StatelessWidget {
  final AppStore store;
  const DisplaySettingsPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final s = store.state;
        final accent = Theme.of(context).colorScheme.primary;
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: Icon(Icons.chevron_left, color: accent, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('单位与精度',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              Text('最小单位（数值粒度）',
                  style: TextStyle(fontSize: 12, color: C.dim(context))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (var i = 0; i < AppState.minUnitNames.length; i++)
                    _opt(context, AppState.minUnitNames[i], s.minUnitIdx == i,
                        () => store.update((st) => st.minUnitIdx = i)),
                ],
              ),
              const SizedBox(height: 18),
              Text('小数位数（0–4 位）',
                  style: TextStyle(fontSize: 12, color: C.dim(context))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (var i = 0; i <= 4; i++)
                    _opt(context, '$i 位', s.decimals == i,
                        () => store.update((st) => st.decimals = i)),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: C.card(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: C.line(context)),
                ),
                child: Text(
                  '显示精度取两者中更细的为准：最小单位=分、小数位=3 → 显示 123.450（分以下不存在）；\n最小单位=厘、小数位=2 → 自动显示 3 位，避免抹掉真实增长。\n当每秒增幅小于最小单位时，数字会每隔几秒跳一次（仍然准确，绝不虚增）。',
                  style: TextStyle(
                      fontSize: 11, color: C.dim(context), height: 1.7),
                ),
              ),
              const SizedBox(height: 14),
              Text('实时预览',
                  style: TextStyle(fontSize: 12, color: C.dim(context))),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: C.card(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: C.line(context)),
                ),
                child: Text(
                  '¥ ${s.formatMoney(3456789)} 元',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: accent,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    shadows: [
                      Shadow(color: accent.withAlpha(80), blurRadius: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  Widget _opt(BuildContext c, String label, bool on, VoidCallback onTap) {
    final accent = Theme.of(c).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on ? C.accentDim(c) : C.card(c),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: on ? accent : C.line(c)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                color: on ? accent : C.dim(c))),
      ),
    );
  }
}

// ============================================================
// 主题设置（4 主题色 × 深浅）
// ============================================================
class ThemeSettingsPage extends StatelessWidget {
  final AppStore store;
  const ThemeSettingsPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final s = store.state;
        final accent = Theme.of(context).colorScheme.primary;
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: Icon(Icons.chevron_left, color: accent, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('主题',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              Text('主题色（小组件同步）',
                  style: TextStyle(fontSize: 12, color: C.dim(context))),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (var i = 0; i < AppTheme.accents.length; i++) ...[
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            store.update((st) => st.accentIdx = i),
                        child: Column(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.accents[i],
                                border: Border.all(
                                  color: s.accentIdx == i
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                      color: AppTheme.accents[i]
                                          .withAlpha(90),
                                      blurRadius: 14),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(AppTheme.accentNames[i],
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: s.accentIdx == i
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: s.accentIdx == i
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primary
                                        : C.dim(context))),
                          ],
                        ),
                      ),
                    ),
                    if (i != AppTheme.accents.length - 1)
                      const SizedBox(width: 6),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              Text('外观',
                  style: TextStyle(fontSize: 12, color: C.dim(context))),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: C.card(context),
                  border: Border.all(color: C.line(context)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    for (final e in const [
                      ('跟随系统', 0),
                      ('深色', 1),
                      ('浅色', 2)
                    ])
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              store.update((st) => st.themeMode = e.$2),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: s.themeMode == e.$2
                                  ? C.accentDim(context)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text(
                              e.$1,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: s.themeMode == e.$2
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: s.themeMode == e.$2
                                    ? accent
                                    : C.dim(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// 小组件设置（显示项开关 + 目标收入）
// ============================================================
class WidgetSettingsPage extends StatelessWidget {
  final AppStore store;
  const WidgetSettingsPage({super.key, required this.store});

  static const _items = <(String, String, String)>[
    ('rate', '每秒增速', '小 · 中 · 大'),
    ('today', '今日已赚', '中 · 大（小尺寸可作副项）'),
    ('month', '本月已赚', '中 · 大'),
    ('payday', '距发薪天数', '小 · 中 · 大'),
    ('status', '上班状态', '小 · 中 · 大'),
    ('badge', '今日倍率徽标', '中 · 大'),
    ('work', '已工作 / 距下班', '仅大'),
    ('list', '各收入今日明细', '仅大'),
    ('curve', '本月迷你曲线', '仅大 · 与明细二选一'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final s = store.state;
        final accent = Theme.of(context).colorScheme.primary;
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: Icon(Icons.chevron_left, color: accent, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('小组件设置',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: C.card(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: C.line(context)),
                ),
                child: Text(
                  '当前总数固定显示。长按桌面小组件 →「编辑小组件」也可配置，与这里双向同步；小组件跟随 App 主题色。',
                  style: TextStyle(
                      fontSize: 11, color: C.dim(context), height: 1.7),
                ),
              ),
              const SizedBox(height: 14),
              Text('显示内容（每项标注适用尺寸）',
                  style: TextStyle(fontSize: 12, color: C.dim(context))),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: C.card(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: C.line(context)),
                ),
                child: Column(
                  children: [
                    for (final it in _items)
                      SwitchListTile(
                        dense: true,
                        title: Text(it.$1,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text(it.$3,
                            style: TextStyle(
                                fontSize: 11, color: C.dim(context))),
                        value: s.widgetFlags[it.$1] ?? true,
                        activeColor: accent,
                        onChanged: (v) => store.update(
                            (st) => st.widgetFlags[it.$1] = v),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text('目标收入（小组件显示哪份）',
                  style: TextStyle(fontSize: 12, color: C.dim(context))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(context, '全部收入汇总', 'all'),
                  for (final inc in s.incomes) _chip(context, inc.name, inc.name),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(BuildContext c, String label, String value) {
    final on = store.state.widgetIncome == value;
    final accent = Theme.of(c).colorScheme.primary;
    return GestureDetector(
      onTap: () => store.update((st) => st.widgetIncome = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: on ? C.accentDim(c) : C.card(c),
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
