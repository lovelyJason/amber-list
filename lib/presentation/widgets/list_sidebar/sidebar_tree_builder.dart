import '../../../data/models/models.dart';
import 'sidebar_models.dart';

/// 侧边栏树形结构构建器
/// 负责将扁平的清单列表转换为树形结构
class SidebarTreeBuilder {
  /// 构建树形结构
  /// 将扁平的 TaskList 列表转换为嵌套的 SidebarTreeNode 树
  static List<SidebarTreeNode> buildTree(List<TaskList> allLists) {
    final Map<String, List<TaskList>> childrenMap = {};
    final List<TaskList> rootLists = [];

    // 分组：区分根节点和子节点
    for (var list in allLists) {
      if (list.parentId == null) {
        rootLists.add(list);
      } else {
        childrenMap.putIfAbsent(list.parentId!, () => []).add(list);
      }
    }

    // 递归构建节点
    List<SidebarTreeNode> buildNodes(List<TaskList> lists) {
      return lists.map((list) {
        final children = childrenMap[list.id] ?? [];
        // 按 sortOrder 排序子节点
        children.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        return SidebarTreeNode(data: list, children: buildNodes(children));
      }).toList();
    }

    // 根节点也按 sortOrder 排序
    rootLists.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return buildNodes(rootLists);
  }
}
