import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/constants.dart';
import '../../../../data/models/models.dart';

/// 日历筛选菜单
/// 支持按优先级和完成状态筛选任务
class CalendarFilterMenu {
  /// 显示筛选菜单
  static void show({
    required BuildContext buttonContext,
    required Set<TaskPriority> filterPriorities,
    required bool? filterIsCompleted,
    required void Function(Set<TaskPriority> priorities, bool? isCompleted)
        onFilterChanged,
  }) {
    final renderBox = buttonContext.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    const menuWidth = 180.0;
    final left = offset.dx + size.width - menuWidth;
    final top = offset.dy + size.height + 4;

    // 创建可变副本
    final priorities = Set<TaskPriority>.from(filterPriorities);
    bool? isCompleted = filterIsCompleted;

    Navigator.of(buttonContext).push(
      PageRouteBuilder(
        opaque: false,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        barrierColor: Colors.black12,
        barrierDismissible: true,
        pageBuilder: (context, _, __) {
          return Stack(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(color: Colors.transparent),
              ),
              Positioned(
                top: top,
                left: left,
                width: menuWidth,
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                  shadowColor: Colors.black26,
                  child: StatefulBuilder(
                    builder: (context, setStateMenu) {
                      void updateModel(VoidCallback fn) {
                        fn();
                        onFilterChanged(priorities, isCompleted);
                        setStateMenu(() {});
                      }

                      Widget buildItem(
                        String text,
                        bool checked,
                        VoidCallback onTap,
                      ) {
                        return InkWell(
                          onTap: onTap,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  child: checked
                                      ? const Icon(
                                          FluentIcons.checkmark_20_regular,
                                          size: 16,
                                          color: AmberColors.primary,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    text,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      Widget buildHeader(String text) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                          child: Text(
                            text,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AmberColors.textSecondary,
                            ),
                          ),
                        );
                      }

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          buildHeader('优先级'),
                          ...TaskPriority.values.map(
                            (p) => buildItem(
                              p.label,
                              priorities.contains(p),
                              () => updateModel(() {
                                if (priorities.contains(p)) {
                                  priorities.remove(p);
                                } else {
                                  priorities.add(p);
                                }
                              }),
                            ),
                          ),
                          const Divider(height: 1),
                          buildHeader('状态'),
                          buildItem(
                            '全部',
                            isCompleted == null,
                            () => updateModel(() => isCompleted = null),
                          ),
                          buildItem(
                            '未完成',
                            isCompleted == false,
                            () => updateModel(() => isCompleted = false),
                          ),
                          buildItem(
                            '已完成',
                            isCompleted == true,
                            () => updateModel(() => isCompleted = true),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
