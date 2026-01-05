/// 原生窗口类型枚举
///
/// 定义所有支持的原生窗口类型，用于 Platform Channel 消息路由。
/// 新增原生窗口功能时，需要在此添加对应的类型。
enum NativeWindowType {
  /// 闪念胶囊 - 全局快速添加任务窗口
  quickAdd('quick_add'),

  /// 便签窗口 - 任务清单便签（已有）
  stickyNote('sticky_note'),
  ;

  const NativeWindowType(this.value);

  /// 类型标识字符串，用于 Platform Channel 通信
  final String value;

  /// 从字符串解析窗口类型
  static NativeWindowType? fromValue(String value) {
    for (final type in values) {
      if (type.value == value) {
        return type;
      }
    }
    return null;
  }
}
