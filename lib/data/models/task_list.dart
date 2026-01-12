import 'package:flutter/material.dart';

/// 清单（文件夹）模型
class TaskList {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? parentId;
  final bool isFolder;
  final List<String> tags;

  const TaskList({
    required this.id,
    required this.name,
    this.icon = Icons.list_rounded,
    required this.color,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.parentId,
    this.isFolder = false,
    this.tags = const [],
  });

  /// 复制并修改字段
  ///
  /// 注意：[parentId] 使用特殊处理支持设置为 null（根目录）
  /// - 不传参数：保持原值
  /// - 传 `clearParentId: true`：设为 null（移到根目录）
  /// - 传具体值：设为该值
  TaskList copyWith({
    String? id,
    String? name,
    IconData? icon,
    Color? color,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? parentId,
    bool clearParentId = false, // 特殊标记：是否清除 parentId（设为根目录）
    bool? isFolder,
    List<String>? tags,
  }) {
    return TaskList(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      // 如果 clearParentId=true，强制设为 null；否则用传入值或原值
      parentId: clearParentId ? null : (parentId ?? this.parentId),
      isFolder: isFolder ?? this.isFolder,
      tags: tags ?? this.tags,
    );
  }
}
