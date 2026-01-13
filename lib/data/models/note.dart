/// 笔记模型
class Note {
  final String id;
  final String title;
  final String content; // Markdown格式
  final String? folderId;
  final List<String> tags;
  final bool isPinned;
  final bool isDeleted; // 是否已删除（软删除）
  final DateTime? deletedAt; // 删除时间（30天自动清理用）
  final DateTime createdAt;
  final DateTime updatedAt;

  const Note({
    required this.id,
    required this.title,
    this.content = '',
    this.folderId,
    this.tags = const [],
    this.isPinned = false,
    this.isDeleted = false,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  Note copyWith({
    String? id,
    String? title,
    String? content,
    String? folderId,
    List<String>? tags,
    bool? isPinned,
    bool? isDeleted,
    DateTime? deletedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      folderId: folderId ?? this.folderId,
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 获取内容摘要
  String get summary {
    if (content.isEmpty) return '';
    final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return '';
    final text = lines.take(3).join(' ');
    return text.length > 100 ? '${text.substring(0, 100)}...' : text;
  }
}
