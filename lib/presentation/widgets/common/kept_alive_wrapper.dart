import 'package:flutter/material.dart';

/// 保持页面状态的 Wrapper 组件
///
/// 设计哲学：
/// - 使用 AutomaticKeepAliveClientMixin 保持子 Widget 的状态
/// - 当页面在 PageView/TabBarView 中被切换走时，不会被销毁
/// - 切换回来时，状态保持不变（滚动位置、输入框内容等）
///
/// 使用场景：
/// - 主页面切换（收集箱、今天、日历、笔记等）
/// - 任何需要保持状态的 PageView 子页面
///
/// 使用示例：
/// ```dart
/// PageView(
///   children: [
///     KeptAliveWrapper(child: InboxPage()),
///     KeptAliveWrapper(child: TodayPage()),
///     KeptAliveWrapper(child: CalendarPage()),
///   ],
/// )
/// ```
class KeptAliveWrapper extends StatefulWidget {
  /// 需要保持状态的子 Widget
  final Widget child;

  const KeptAliveWrapper({super.key, required this.child});

  @override
  State<KeptAliveWrapper> createState() => _KeptAliveWrapperState();
}

class _KeptAliveWrapperState extends State<KeptAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  /// 告诉 Flutter 保持此 Widget 的状态
  /// 即使被切换走也不要销毁
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    // 必须调用 super.build(context)
    // 这是 AutomaticKeepAliveClientMixin 的要求
    super.build(context);
    return widget.child;
  }
}
