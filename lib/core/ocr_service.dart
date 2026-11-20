// ============================================================
// 薪跳 · 排班表截图识别（iOS Vision 本地 OCR，不联网）
// ============================================================
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class OcrLine {
  final String text;
  final double x, y, w, h;
  OcrLine(this.text, this.x, this.y, this.w, this.h);
  double get cx => x + w / 2;
  double get cy => y + h / 2;
}

class OcrService {
  static const _channel = MethodChannel('com.xintiao.ocr');
  static final _picker = ImagePicker();

  /// 从相册选图并识别文字（返回归一化坐标 0-1）
  static Future<List<OcrLine>> pickAndRecognize() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return [];
    final raw =
        await _channel.invokeListMethod<dynamic>('recognize', picked.path) ??
            [];
    return raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return OcrLine(
        m['text'] as String,
        (m['x'] as num).toDouble(),
        (m['y'] as num).toDouble(),
        (m['w'] as num).toDouble(),
        (m['h'] as num).toDouble(),
      );
    }).toList();
  }

  static final _shiftPat = RegExp(r'(白班|中班|晚班|夜班|早班|休|休息|班)');
  static final _dayPat = RegExp(r'(?<!\d)([1-9]|[12]\d|3[01])(?!\d)');

  static List<(OcrLine, int)> _dayTokens(List<OcrLine> row) {
    final out = <(OcrLine, int)>[];
    for (final it in row) {
      final m = _dayPat.firstMatch(it.text);
      if (m != null) out.add((it, int.parse(m.group(1)!)));
    }
    return out;
  }

  /// 启发式解析：文本行聚类（按 y）→ 行内/相邻行「日期 + 班次」配对
  static Map<int, String> parse(List<OcrLine> lines) {
    final items = <OcrLine>[
      for (final l in lines)
        OcrLine(l.text.replaceAll(RegExp(r'\s'), ''), l.x, l.y, l.w, l.h),
    ];

    // 按 y 中心聚类成行
    final rows = <List<OcrLine>>[];
    for (final it in items) {
      var added = false;
      for (final row in rows) {
        final avgY = row.fold<double>(0, (a, r) => a + r.cy) / row.length;
        final avgH = row.fold<double>(0, (a, r) => a + r.h) / row.length;
        if ((it.cy - avgY).abs() < avgH * 0.7) {
          row.add(it);
          added = true;
          break;
        }
      }
      if (!added) rows.add([it]);
    }
    for (final row in rows) {
      row.sort((a, b) => a.cx.compareTo(b.cx));
    }

    final result = <int, String>{};

    // 同行配对
    for (final row in rows) {
      for (final (tok, day) in _dayTokens(row)) {
        OcrLine? best;
        var bestDist = double.infinity;
        for (final it in row) {
          if (identical(it, tok)) continue;
          if (!_shiftPat.hasMatch(it.text)) continue;
          final d = (it.cx - tok.cx).abs();
          if (d < bestDist) {
            bestDist = d;
            best = it;
          }
        }
        if (best != null) {
          final n = _normalize(best.text);
          if (n.isNotEmpty) result[day] = n;
        }
      }
    }

    // 跨行配对（数字在上、班次在下的单元格布局，以及相反的上下布局）
    for (var ri = 0; ri < rows.length; ri++) {
      final targets = <List<OcrLine>>[];
      if (ri + 1 < rows.length) targets.add(rows[ri + 1]);
      if (ri - 1 >= 0) targets.add(rows[ri - 1]);
      for (final (tok, day) in _dayTokens(rows[ri])) {
        if (result.containsKey(day)) continue;
        OcrLine? best;
        var bestDist = tok.w * 1.8; // 同列判断：容差为数字宽度的 1.8 倍
        for (final next in targets) {
          for (final it in next) {
            if (!_shiftPat.hasMatch(it.text)) continue;
            final d = (it.cx - tok.cx).abs();
            if (d < bestDist) {
              bestDist = d;
              best = it;
            }
          }
        }
        if (best != null) {
          final n = _normalize(best.text);
          if (n.isNotEmpty) result[day] = n;
        }
      }
    }

    return result;
  }

  static String _normalize(String t) {
    if (t.contains('休') || t.contains('休息')) return '休';
    if (t.contains('白')) return '白班';
    if (t.contains('中')) return '中班';
    if (t.contains('晚')) return '晚班';
    if (t.contains('早')) return '早班';
    if (t.contains('夜')) return '夜班';
    return '';
  }

  static int labelToShiftIdx(String label) {
    switch (label) {
      case '白班':
        return 0;
      case '夜班':
        return 1;
      case '早班':
        return 2;
      case '中班':
        return 3;
      case '晚班':
        return 4;
      default:
        return 0;
    }
  }
}
