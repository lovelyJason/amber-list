import '../../../data/models/models.dart';

/// 侧边栏树节点模型
/// 用于构建清单/文件夹的树形结构
class SidebarTreeNode {
  /// 节点数据（清单或文件夹）
  final TaskList data;

  /// 子节点列表
  final List<SidebarTreeNode> children;

  SidebarTreeNode({required this.data, this.children = const []});
}
