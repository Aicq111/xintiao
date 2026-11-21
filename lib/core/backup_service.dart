// ============================================================
// 薪跳 · 数据备份与迁移（导出/导入 JSON，跨设备同步）
// ============================================================
import 'dart:convert';
import 'package:flutter/services.dart';
import 'store.dart';

class BackupResult {
  final bool ok;
  final String? error;
  final AppState? state;
  BackupResult(this.ok, {this.error, this.state});
}

class BackupService {
  /// 导出：AppState → JSON（带版本号），并复制到剪贴板
  static String exportJson(AppState state) {
    return jsonEncode({
      'app': 'xintiao',
      'v': 1,
      'time': DateTime.now().toIso8601String(),
      'state': state.toJson(),
    });
  }

  static Future<String> exportToClipboard(AppState state) async {
    final s = exportJson(state);
    await Clipboard.setData(ClipboardData(text: s));
    return s;
  }

  /// 读取当前剪贴板内容
  static Future<String> readClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text ?? '';
  }

  /// 导入：校验并解析（不会直接覆盖，返回解析结果供预览确认）
  static BackupResult importJson(String text) {
    try {
      final j = jsonDecode(text.trim());
      if (j is! Map || j['app'] != 'xintiao') {
        return BackupResult(false, error: '这不是薪跳的备份内容');
      }
      final st = j['state'];
      if (st is! Map) return BackupResult(false, error: '备份内容缺少数据');
      final state = AppState.fromJson(Map<String, dynamic>.from(st));
      return BackupResult(true, state: state);
    } catch (_) {
      return BackupResult(false, error: '解析失败，请确认粘贴了完整内容');
    }
  }
}
