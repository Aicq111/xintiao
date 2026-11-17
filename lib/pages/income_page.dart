// ============================================================
// 薪跳 · 收入管理页（多收入列表 + 添加/编辑/停用）
// ============================================================
import 'package:flutter/material.dart';
import '../core/store.dart';
import '../core/theme.dart';

class IncomePage extends StatelessWidget {
  final AppStore store;
  const IncomePage({super.key, required this.store});

  Future<void> _edit(BuildContext c, int? idx) async {
    final inc = idx == null ? null : store.state.incomes[idx];
    final result = await showModalBottomSheet<Object>(
      context: c,
      isScrollControlled: true,
      backgroundColor: C.card(c),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _IncomeSheet(existing: inc),
    );
    if (result == null) return;
    if (result is String && result == 'delete' && idx != null) {
      store.update((st) => st.incomes.removeAt(idx));
    } else if (result is IncomeData) {
      store.update((st) {
        if (idx == null) {
          st.incomes.add(result);
        } else {
          st.incomes[idx] = result;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final s = store.state;
        final accent = Theme.of(context).colorScheme.primary;
        final total = s.incomes
            .where((e) => e.enabled)
            .fold<double>(0, (a, b) => a + b.amountYuan);
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
            title: const Text('收入管理',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            actions: [
              TextButton(
                onPressed: () => _edit(context, null),
                child: Text('＋添加',
                    style: TextStyle(
                        color: accent, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: C.card(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: C.line(context)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('全部收入 · 月总额',
                            style: TextStyle(
                                fontSize: 12, color: C.dim(context))),
                        const SizedBox(height: 4),
                        Text('¥${total.toStringAsFixed(0)} /月',
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    Text('${s.incomes.length} 份收入',
                        style: TextStyle(
                            fontSize: 12, color: C.dim(context))),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < s.incomes.length; i++) _row(context, i),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: C.line(context),
                      style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '💡 停用的收入会暂停增长但不删除数据；跟随排班的收入才可参与加班倍率；删除前请确认，避免误删历史累计。',
                  style: TextStyle(
                      fontSize: 11, color: C.dim(context), height: 1.6),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  Widget _row(BuildContext c, int i) {
    final inc = store.state.incomes[i];
    final accent = Theme.of(c).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.card(c),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.line(c)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: inc.followSchedule ? C.accentDim(c) : C.blueDim(c),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(inc.followSchedule ? '💼' : '💰',
                  style: const TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(inc.name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: inc.followSchedule
                            ? C.accentDim(c)
                            : C.blueDim(c),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        inc.followSchedule ? '跟随排班' : '全天候',
                        style: TextStyle(
                            fontSize: 10,
                            color: inc.followSchedule
                                ? accent
                                : C.blue(c)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '¥${inc.amountYuan.toStringAsFixed(0)}/${_periodLabel(inc.period)} · 累计起点 ${inc.startDay.month}月${inc.startDay.day}日',
                  style: TextStyle(fontSize: 11, color: C.dim(c)),
                ),
              ],
            ),
          ),
          Switch(
            value: inc.enabled,
            activeColor: accent,
            onChanged: (v) =>
                store.update((st) => st.incomes[i].enabled = v),
          ),
          IconButton(
            onPressed: () => _edit(c, i),
            icon: Icon(Icons.chevron_right, color: C.dim(c)),
          ),
        ],
      ),
    );
  }

  static String _periodLabel(String p) {
    switch (p) {
      case 'monthly':
        return '月';
      case 'weekly':
        return '周';
      case 'daily':
        return '天';
      default:
        return '一次性';
    }
  }
}

// ============================================================
// 收入编辑弹层
// ============================================================
class _IncomeSheet extends StatefulWidget {
  final IncomeData? existing;
  const _IncomeSheet({this.existing});

  @override
  State<_IncomeSheet> createState() => _IncomeSheetState();
}

class _IncomeSheetState extends State<_IncomeSheet> {
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late String _period;
  late bool _follow;
  late bool _participate;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _amount = TextEditingController(
        text: e == null ? '' : e.amountYuan.toStringAsFixed(0));
    _period = e?.period ?? 'monthly';
    _follow = e?.followSchedule ?? false;
    _participate = e?.participateMultiplier ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final amt = double.tryParse(_amount.text.trim());
    if (name.isEmpty || amt == null || amt <= 0) return;
    Navigator.pop(
      context,
      IncomeData(
        name: name,
        amountYuan: amt,
        period: _period,
        followSchedule: _period == 'monthly' && _follow,
        participateMultiplier: _participate,
        enabled: widget.existing?.enabled ?? true,
        startDay: widget.existing?.startDay ??
            DateTime(DateTime.now().year, DateTime.now().month, 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
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
          Row(
            children: [
              Text(widget.existing == null ? '添加收入' : '编辑收入',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              const Spacer(),
              if (widget.existing != null)
                TextButton(
                  onPressed: () => Navigator.pop(context, 'delete'),
                  child: Text('删除',
                      style: TextStyle(color: C.red(context))),
                ),
            ],
          ),
          _label('收入名称（自定义来源）'),
          _field(_name),
          _label('金额（元）'),
          _field(_amount, keyboard: TextInputType.number),
          _label('周期'),
          _seg(['每月', '每周', '每天', '一次性'],
              ['monthly', 'weekly', 'daily', 'once'], _period, (v) {
            setState(() {
              _period = v as String;
              if (_period != 'monthly') _follow = false;
            });
          }),
          _label('计薪方式'),
          _seg(['跟随排班', '全天候'], [true, false], _follow, (v) {
            setState(() => _follow = v as bool);
          }, enabled: _period == 'monthly'),
          if (_follow)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('参与加班倍率',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text('加班/节假日按当日倍率增长',
                  style: TextStyle(fontSize: 11, color: C.dim(context))),
              value: _participate,
              activeColor: accent,
              onChanged: (v) => setState(() => _participate = v),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: const Color(0xFF06231A)),
                  onPressed: _save,
                  child: const Text('保存',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Text(text,
          style: TextStyle(fontSize: 12, color: C.dim(context))),
    );
  }

  Widget _field(TextEditingController ctrl, {TextInputType? keyboard}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border.all(color: C.line(context)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        style: const TextStyle(fontSize: 15),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  Widget _seg(List<String> labels, List<Object> values, Object current,
      void Function(Object) onSel,
      {bool enabled = true}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border.all(color: C.line(context)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: enabled ? () => onSel(values[i]) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: current == values[i]
                        ? C.accentDim(context)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: current == values[i]
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: enabled
                          ? (current == values[i]
                              ? Theme.of(context).colorScheme.primary
                              : C.dim(context))
                          : C.dim(context).withAlpha(80),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
