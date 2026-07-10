import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

/// 笔记行优先级（1-9），用 ①-⑨ 标记 + bg_color 彩色徽章，同一篇笔记每个数字唯一
class NotePriority {
  NotePriority._();

  static const _circled = '①②③④⑤⑥⑦⑧⑨';
  static String marker(int n) => _circled[n - 1];
  static final RegExp pattern = RegExp('^([①-⑨]) ?');

  /// 9 种鲜活的渐变主色（参考生成的徽章配色）
  static const _colors = <int, Color>{
    1: Color(0xFFFF5252), // 珊瑚红
    2: Color(0xFFFF9800), // 暖橙
    3: Color(0xFFFFC107), // 琥珀黄
    4: Color(0xFF66BB6A), // 清新绿
    5: Color(0xFF26C6DA), // 青碧
    6: Color(0xFF42A5F5), // 天蓝
    7: Color(0xFF5C6BC0), // 靛蓝
    8: Color(0xFFAB47BC), // 紫罗兰
    9: Color(0xFFEC407A), // 玫瑰粉
  };

  static const _labels = <int, String>{
    1: '珊瑚红 ①', 2: '暖橙 ②', 3: '琥珀黄 ③',
    4: '清新绿 ④', 5: '青碧 ⑤', 6: '天蓝 ⑥',
    7: '靛蓝 ⑦', 8: '紫罗兰 ⑧', 9: '玫瑰粉 ⑨',
  };

  static Color color(int n) => _colors[n] ?? const Color(0xFF9E9E9E);
  static String label(int n) => _labels[n] ?? '';

  // ---------- 读取 ----------

  static int _circledToInt(String c) => _circled.indexOf(c) + 1;

  static int getPriority(Node node) {
    final m = pattern.firstMatch(node.delta?.toPlainText() ?? '');
    if (m == null) return 0;
    return _circledToInt(m.group(1)!);
  }

  static int _markerLen(Node node) {
    final m = pattern.firstMatch(node.delta?.toPlainText() ?? '');
    return m == null ? 0 : m.group(0)!.length;
  }

  /// 收集整篇笔记中已使用的优先级数字
  static Set<int> usedPriorities(EditorState state) {
    final used = <int>{};
    for (final node in state.document.root.children) {
      final p = getPriority(node);
      if (p > 0) used.add(p);
    }
    return used;
  }

  // ---------- 写入 ----------

  static void setPriority(EditorState s, Node n, int level) {
    if (n.delta == null) return;
    final tx = s.transaction;
    final old = _markerLen(n);
    if (old > 0) tx.deleteText(n, 0, old);
    tx.insertText(n, 0, '${marker(level)} ');
    s.apply(tx);
  }

  static void removePriority(EditorState s, Node n) {
    final l = _markerLen(n);
    if (l <= 0) return;
    final tx = s.transaction;
    tx.deleteText(n, 0, l);
    s.apply(tx);
  }

  // ---------- 右键菜单 ----------

  static Future<void> showPriorityMenu(
    BuildContext context, Offset pos, EditorState editorState,
  ) async {
    final sel = editorState.selection;
    if (sel == null) return;
    final node = editorState.getNodeAtPath(sel.start.path);
    if (node == null || node.delta == null) return;

    final current = getPriority(node);
    final used = usedPriorities(editorState);

    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final rect = RelativeRect.fromRect(
      Rect.fromPoints(pos, pos), Offset.zero & overlay.size,
    );

    final result = await showMenu<int>(
      context: context,
      position: rect,
      items: [
        for (final n in List.generate(9, (i) => i + 1))
          PopupMenuItem<int>(
            value: n,
            enabled: n == current || !used.contains(n),
            child: _row(n, current, used),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<int>(
          value: 0,
          enabled: current > 0,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.remove_circle_outline, size: 16,
                color: current > 0 ? Colors.red.shade300 : Colors.grey.shade300),
            const SizedBox(width: 8),
            Text('取消优先级', style: TextStyle(fontSize: 13,
                color: current > 0 ? Colors.red.shade400 : Colors.grey)),
          ]),
        ),
      ],
    );
    if (result == null) return;
    if (result == 0 || result == current) {
      removePriority(editorState, node);
    } else {
      setPriority(editorState, node, result);
    }
  }

  static Widget _row(int n, int current, Set<int> used) {
    final active = n == current;
    final taken = used.contains(n) && !active;
    final textColor = taken ? Colors.grey : (active ? color(n) : const Color(0xFF333333));
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _badge(n, dimmed: taken),
      const SizedBox(width: 10),
      Text(label(n), style: TextStyle(fontSize: 13,
          fontWeight: active ? FontWeight.w600 : FontWeight.normal, color: textColor)),
      if (active) ...[const SizedBox(width: 6), Icon(Icons.check_circle, size: 15, color: color(n))],
      if (taken) ...[const SizedBox(width: 6),
        Text('已使用', style: TextStyle(fontSize: 11, color: Colors.grey.shade400))],
    ]);
  }

  static Widget _badge(int n, {bool dimmed = false}) {
    final c = color(n);
    return Opacity(
      opacity: dimmed ? 0.6 : 1.0,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: dimmed ? null : [
            BoxShadow(color: c.withValues(alpha: 0.35), blurRadius: 4, offset: const Offset(0, 2))
          ],
        ),
        foregroundDecoration: dimmed ? BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.8),
          backgroundBlendMode: BlendMode.saturation,
          borderRadius: BorderRadius.circular(8),
        ) : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/icons/priority_$n.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // 降级回退到纯文字方块，防止找不到资源
              return Container(
                decoration: BoxDecoration(color: c),
                alignment: Alignment.center,
                child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              );
            },
          ),
        ),
      ),
    );
  }
}
