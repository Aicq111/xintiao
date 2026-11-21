// ============================================================
// 薪跳 · 设置页（含：显示设置 / 主题 / 发薪日 / 帧率 / 小组件设置）
// ============================================================
import 'package:flutter/material.dart';
import '../core/backup_service.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'income_page.dart';

class SettingsPage extends StatelessWidget {
  final AppStore store;
  final void Function(int tab)? onNavigateTab;
  const SettingsPage({super.key, required this.store, this.onNavigateTab});

  static String _themeModeName(int m) =>
      m == 0 ? '跟随系统' : (m == 1 ? '深色' : '浅色');

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
                    () => onNavigateTab?.call(1)),
                _switchRow(context, '🏮', '中国法定节假日日历',
                    '自动标注节假日与调休上班日', s.holidayMark,
                    (v) => store.update((st) => st.holidayMark = v)),
              ]),
              _label(context, '显示与主题'),
              _card(context, [
                _row(context, '🔢', '单位与精度',
                    '${AppState.minUnitNames[s.minUnitIdx]}${s.autoPrecision ? ' · 自动精度' : ''}',
                    () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => DisplaySettingsPage(store: store)))),
                _row(context, '🎨', '主题',
                    '${AppTheme.accentNames[s.accentIdx]} · ${_themeModeName(s.themeMode)}',
                    () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => ThemeSettingsPage(store: store)))),
              ]),
              _label(context, '小组件'),
              _card(context, [
                _row(context, '🧩', '小组件设置',
                    '小 / 中 / 大三尺寸 · 显示项开关',
                    () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => WidgetSettingsPage(store: store)))),
              ]),
              _label(context, '数据备份与迁移'),
              _card(context, [
                _row(context, '📤', '导出备份',
                    '复制到剪贴板 · 微信/QQ 发给另一台手机',
                    () => _exportSheet(context)),
                _row(context, '📥', '导入备份',
                    '粘贴另一台手机的备份 · 覆盖本机数据',
                    () => _importSheet(context)),
              ]),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  '薪跳 · 版本 0.1.0\n数据仅保存在本机 · 双设备可用「导出/导入」同步',
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

  // ---------- 数据备份与迁移 ----------
  void _exportSheet(BuildContext c) {
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
            const Text('导出备份',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              '备份包含：全部收入、排班模式、特殊日、主题与所有设置。\n点击下方按钮后，内容会复制到剪贴板，粘贴发送给另一台设备（微信/QQ/AirDrop 均可）。',
              style: TextStyle(
                  fontSize: 11, color: C.dim(c), height: 1.7),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(c).colorScheme.primary,
                    foregroundColor: const Color(0xFF06231A)),
                onPressed: () async {
                  await BackupService.exportToClipboard(store.state);
                  if (ctx.mounted) Navigator.pop(ctx);
                  ScaffoldMessenger.of(c).showSnackBar(const SnackBar(
                      content: Text('已复制到剪贴板！去微信/QQ 粘贴发给另一台手机吧')));
                },
                icon: const Icon(Icons.copy_all, size: 18),
                label: const Text('复制备份内容',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _importSheet(BuildContext c) {
    final accent = Theme.of(c).colorScheme.primary;
    showModalBottomSheet(
      context: c,
      isScrollControlled: true,
      backgroundColor: C.card(c),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _ImportSheet(store: store, accent: accent),
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
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime(2000, 1, day.clamp(1, 28).toInt()),
                        firstDate: DateTime(2000, 1, 1),
                        lastDate: DateTime(2000, 1, 28),
                        helpText: '选择每月发薪日',
                      );
                      if (picked != null) {
                        setSt(() => day = picked.day);
                      }
                    },
                    icon: Icon(Icons.calendar_month, size: 18, color: accent),
                    label: Text(
                      '每月 $day 号（点此日历选日）',
                      style: TextStyle(fontSize: 14, color: accent),
                    ),
                  ),
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
              Text('显示单位（数值粒度与小数位）',
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
              Container(
                decoration: BoxDecoration(
                  color: C.card(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: C.line(context)),
                ),
                child: SwitchListTile(
                  title: const Text('自动提升精度',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '当所选单位下每秒增长不足 1 个单位时，自动用更细的单位显示，保证数字每秒跳动；数值始终真实，绝不虚增。',
                    style: TextStyle(
                        fontSize: 11, color: C.dim(context), height: 1.6),
                  ),
                  value: s.autoPrecision,
                  activeColor: accent,
                  onChanged: (v) =>
                      store.update((st) => st.autoPrecision = v),
                ),
              ),
              const SizedBox(height: 18),
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
                child: Column(
                  children: [
                    Text(
                      '¥ ${s.formatMoney(3456789)} 元',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: accent,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s.autoPrecision
                          ? '当前工资水平下，主页将自动显示到「厘」以保证每秒跳动'
                          : '自动精度已关闭，按所选单位显示',
                      style: TextStyle(fontSize: 11, color: C.dim(context)),
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
              Wrap(
                spacing: 14,
                runSpacing: 16,
                children: [
                  for (var i = 0; i < AppTheme.accents.length; i++)
                    SizedBox(
                      width: 66,
                      child: GestureDetector(
                        onTap: () =>
                            store.update((st) => st.accentIdx = i),
                        child: Column(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
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


// ============================================================
// 导入备份弹层
// ============================================================
class _ImportSheet extends StatefulWidget {
  final AppStore store;
  final Color accent;
  const _ImportSheet({required this.store, required this.accent});

  @override
  State<_ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends State<_ImportSheet> {
  final _ctrl = TextEditingController();
  BackupResult? _parsed;
  bool _parsing = false;

  @override
  void initState() {
    super.initState();
    BackupService.readClipboard().then((t) {
      if (t.isNotEmpty && mounted && _ctrl.text.isEmpty) {
        _ctrl.text = t;
      }
    });
  }

  void _check() {
    setState(() {
      _parsing = true;
      _parsed = BackupService.importJson(_ctrl.text);
      _parsing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _parsed?.state;
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
          const Text('导入备份',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('粘贴另一台设备导出的备份内容（已自动读取剪贴板）',
              style: TextStyle(fontSize: 11, color: C.dim(context))),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            maxLines: 6,
            style: const TextStyle(fontSize: 11),
            decoration: InputDecoration(
              hintText: '粘贴备份内容…',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          if (_parsed != null && !_parsed!.ok)
            Text('❌ ',
                style: TextStyle(fontSize: 12, color: C.red(context))),
          if (_parsed != null && _parsed!.ok && s != null) ...[
            Text(
              '✅ 备份有效：收入  笔 · 排班「」 · 特殊日  处',
              style: const TextStyle(fontSize: 12, color: Color(0xFF34D399)),
            ),
            const SizedBox(height: 6),
            Text('导入将覆盖本机现有数据，请确认',
                style: TextStyle(fontSize: 11, color: C.dim(context))),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _check,
                  child: const Text('检查内容'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: widget.accent,
                      foregroundColor: const Color(0xFF06231A)),
                  onPressed: (_parsed?.ok ?? false)
                      ? () {
                          widget.store
                              .replaceState(_parsed!.state!);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('导入成功！数据已同步')));
                        }
                      : null,
                  child: const Text('确认导入',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
