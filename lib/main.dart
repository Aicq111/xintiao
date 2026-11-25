// ============================================================
// 薪跳 · 入口与导航壳（4 个 Tab + 主题切换 + 数据加载）
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/store.dart';
import 'core/theme.dart';
import 'pages/calendar_page.dart';
import 'pages/home_page.dart';
import 'pages/settings_page.dart';
import 'pages/stats_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  await store.load();
  runApp(XinTiaoApp(store: store));
}

class XinTiaoApp extends StatelessWidget {
  final AppStore store;
  const XinTiaoApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final s = store.state;
        final mode = s.themeMode == 0
            ? ThemeMode.system
            : (s.themeMode == 1 ? ThemeMode.dark : ThemeMode.light);
        return MaterialApp(
          title: '薪跳',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(s.accentIdx, Brightness.light),
          darkTheme: AppTheme.build(s.accentIdx, Brightness.dark),
          themeMode: mode,
          // 中文界面：时间/日期选择器等系统组件显示中文
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: RootShell(store: store),
        );
      },
    );
  }
}

class RootShell extends StatefulWidget {
  final AppStore store;
  const RootShell({super.key, required this.store});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          HomePage(
              store: widget.store,
              onNavigateTab: (i) => setState(() => _tab = i)),
          CalendarPage(store: widget.store),
          StatsPage(store: widget.store),
          SettingsPage(store: widget.store),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: '日历',
          ),
          NavigationDestination(
            icon: Icon(Icons.insert_chart_outlined),
            selectedIcon: Icon(Icons.insert_chart),
            label: '统计',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
