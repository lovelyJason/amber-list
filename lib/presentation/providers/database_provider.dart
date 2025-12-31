import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/database.dart';

/// 数据库实例Provider
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
