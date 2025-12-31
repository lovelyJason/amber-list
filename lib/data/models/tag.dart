import 'dart:ui';

class Tag {
  final String id;
  final String name;
  final Color color;
  final DateTime createdAt;

  const Tag({
    required this.id,
    required this.name,
    required this.color,
    required this.createdAt,
  });

  Tag copyWith({
    String? id,
    String? name,
    Color? color,
    DateTime? createdAt,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
