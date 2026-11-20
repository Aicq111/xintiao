// ============================================================
// 薪跳 · 冒烟测试：把 store/theme/widget_bridge/home_page 全部纳入编译
// （发布 AOT 编译覆盖全工程，JIT 测试只编译被引用的文件——用这个测试扩大编译覆盖面）
// ============================================================
import 'package:flutter_test/flutter_test.dart';
import 'package:xintiao/core/engine.dart';
import 'package:xintiao/core/store.dart';
import 'package:xintiao/core/theme.dart';
import 'package:xintiao/core/widget_bridge.dart';
import 'package:xintiao/pages/home_page.dart';

void main() {
  test('冒烟：数据模型、主题、桥接全部可编译可实例化', () {
    final store = AppStore();
    expect(store.state.incomes, isNotEmpty);
    expect(store.state.formatMoney(3456789), contains('.'));

    final sched = const ScheduleData(mode: 2);
    expect(sched.engineMode, ScheduleMode.nightShift);

    expect(AppTheme.accents.length, 8);
    expect(AppTheme.accentNames.length, 8);
    expect(WidgetBridge.accentHex.length, 8);

    // 序列化往返
    final json = store.state.toJson();
    final back = AppState.fromJson(json);
    expect(back.incomes.length, store.state.incomes.length);
    expect(back.schedule.mode, store.state.schedule.mode);
  });
}
