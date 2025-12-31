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

  TaskList copyWith({
    String? id,
    String? name,
    IconData? icon,
    Color? color,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? parentId,
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
      parentId: parentId ?? this.parentId,
      isFolder: isFolder ?? this.isFolder,
      tags: tags ?? this.tags,
    );
  }
}
